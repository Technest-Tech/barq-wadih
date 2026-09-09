import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/data/notification_repository.dart';

// Must be top-level — called by FCM when app is in background/terminated.
// Firebase is already initialised before this runs.
@pragma('vm:entry-point')
Future<void> _onFcmBackgroundMessage(RemoteMessage message) async {}

const _channelId = 'barqwadih_main';
const _channelName = 'إشعارات برق وديه';

/// Native side of the app-icon badge (see ios/Runner/AppDelegate.swift).
const _badgeChannel = MethodChannel('com.barqwadih.app/push_registration');

/// Singleton that wires together FCM push delivery and local notification
/// display, token lifecycle management, and tap-to-navigate routing.
///
/// Call order:
///   1. [FCMService.instance.init] — once in bootstrap, before runApp
///   2. [FCMService.instance.checkInitialMessage] — once after the router is ready
///   3. [FCMService.instance.registerToken] — after each successful login
///   4. [FCMService.instance.deregisterToken] — before each logout
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  // Resolved on demand, not in the constructor: FirebaseMessaging.instance
  // throws until Firebase.initializeApp() has run, and the badge helpers below
  // touch neither Firebase nor the network. Building the singleton must not
  // depend on a Firebase that may not be up yet.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;

  /// Listen to this notifier to drive notification-tap navigation.
  /// Set back to null after consuming the value.
  static final pendingRoute = ValueNotifier<String?>(null);

  /// Bumped once per inbound push. Listen to it to refresh anything derived
  /// from the notification table — the unread bell badge above all, which
  /// would otherwise stay stale until the next screen rebuild.
  static final inboundPush = ValueNotifier<int>(0);

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    // Register the top-level background handler first.
    FirebaseMessaging.onBackgroundMessage(_onFcmBackgroundMessage);

    // iOS suppresses notification banners while the app is in the foreground
    // unless presentation is enabled explicitly. Let APNs present the remote
    // notification natively; Android continues to use the local channel below.
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Create Android high-importance notification channel.
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              importance: Importance.high,
              showBadge: true,
              playSound: true,
            ),
          );
    }

    // Initialise local-notifications plugin (foreground display + tap routing).
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // Permission is requested via FirebaseMessaging.requestPermission.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) pendingRoute.value = details.payload;
      },
    );

    // Foreground: show local notification so the user sees it.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Background tap: app was backgrounded, user tapped the system notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
  }

  /// Call once after the router is ready (post-frame callback).
  Future<void> checkInitialMessage() async {
    // Terminated-state FCM tap.
    final fcm = await _messaging.getInitialMessage();
    if (fcm != null) {
      pendingRoute.value = _routeFrom(fcm);
      return;
    }
    // Terminated-state local-notification tap.
    final ld = await _localNotifications.getNotificationAppLaunchDetails();
    if (ld?.didNotificationLaunchApp == true) {
      final payload = ld?.notificationResponse?.payload;
      if (payload != null) pendingRoute.value = payload;
    }
  }

  // ── Token lifecycle ───────────────────────────────────────────────────────

  /// Request permission and register the FCM token with the backend.
  /// Call after every successful login / register.
  Future<void> registerToken(NotificationRepository repo) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    // Every call site fires this un-awaited, so a throw here would surface as
    // an unhandled async error and be swallowed in release.
    final NotificationSettings settings;
    try {
      settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('FCMService: permission request failed — $e');
      return;
    }
    debugPrint(
      'FCMService: notification authorization — '
      '${settings.authorizationStatus.name}',
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Subscribe *before* fetching. On iOS the first getToken() can come up
    // empty while APNs registration is still in flight, and the token then
    // only ever arrives through this stream — so it has to be listening
    // already, and it must register unconditionally rather than only when an
    // earlier attempt succeeded.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _register(newToken, repo);
    });

    final token = await _fetchToken();
    if (token != null) await _register(token, repo);
  }

  /// Resolve the FCM token, tolerating the iOS APNs handshake.
  ///
  /// iOS cannot mint an FCM token until Apple has handed back an APNs token —
  /// a network round-trip that is usually still running when we are called
  /// right after login. Calling getToken() before it lands throws
  /// `firebase_messaging/apns-token-not-set`, so wait for APNs first and
  /// swallow the failure if it never comes; onTokenRefresh picks it up later.
  Future<String?> _fetchToken() async {
    if (Platform.isIOS) {
      for (var attempt = 0; attempt < 10; attempt++) {
        try {
          if (await _messaging.getAPNSToken() != null) break;
        } catch (_) {
          // Keep waiting — a throw here means APNs is not ready yet.
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('FCMService: getToken failed, awaiting onTokenRefresh — $e');
      return null;
    }
  }

  /// Deactivate the device token on the backend then clear state.
  /// Call just before logout.
  Future<void> deregisterToken(NotificationRepository repo) async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      final token = await _messaging.getToken();
      if (token != null) await repo.deactivateDevice(token);
    } catch (_) {}
  }

  // ── App-icon badge ────────────────────────────────────────────────────────

  /// Set the app-icon badge to [count].
  ///
  /// The push payload carries a badge number, but only a *new* push can move
  /// it — reading notifications inside the app has to reset it from here, or
  /// the icon keeps advertising notifications the user has already seen.
  Future<void> setAppBadge(int count) async {
    if (Platform.isIOS) {
      try {
        await _badgeChannel.invokeMethod<void>('setBadgeCount', {
          'count': count,
        });
      } catch (e) {
        debugPrint('FCMService: setBadgeCount failed — $e');
      }
      return;
    }

    // Android launchers derive their badge from the delivered notifications,
    // so clearing the tray is what clears the dot.
    if (count == 0) {
      try {
        await _localNotifications.cancelAll();
      } catch (e) {
        debugPrint('FCMService: cancelAll failed — $e');
      }
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _register(String token, NotificationRepository repo) async {
    try {
      await repo.registerDevice(
        fcmToken: token,
        deviceType: Platform.isIOS ? 'ios' : 'android',
      );
    } catch (e) {
      debugPrint('FCMService: device registration failed — $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    debugPrint(
      'FCMService: foreground message received — '
      'id=${message.messageId}, type=${message.data['type']}',
    );
    // Announce it before any early return below, so the bell badge refreshes
    // even on iOS where the banner is presented natively.
    inboundPush.value++;
    final n = message.notification;
    if (n == null) {
      debugPrint('FCMService: message has no notification payload');
      return;
    }

    // Native foreground presentation is enabled in init() on iOS. Posting a
    // second local notification here would create duplicate banners.
    if (Platform.isIOS) return;

    _localNotifications.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _routeFrom(message),
    );
  }

  void _onTap(RemoteMessage message) {
    pendingRoute.value = _routeFrom(message);
  }

  String _routeFrom(RemoteMessage message) {
    final d = message.data;
    switch (d['type']) {
      case 'new_ad':
        if (d['ad_id'] != null) return '/ads/${d['ad_id']}';
        return '/notifications';
      case 'chat':
        if (d['conversation_id'] != null) {
          return '/messages/${d['conversation_id']}';
        }
        return '/messages';
      case 'rating':
        if (d['ad_id'] != null) return '/ads/${d['ad_id']}';
        return '/notifications';
      case 'sale_fee':
        // Backend sends price as string in FCM data payload.
        // Route to the fee calculator with the ad price pre-filled.
        if (d['price'] != null) return '/payments?price=${d['price']}';
        return '/payments';
      case 'commission_approved':
        if (d['ad_id'] != null) return '/ads/${d['ad_id']}';
        return '/payments';
      case 'commission_rejected':
        // Send the seller to the bank-transfer screen to re-upload a receipt.
        if (d['ad_id'] != null) {
          final amount = d['amount'];
          return amount != null
              ? '/ads/${d['ad_id']}/pay?amount=$amount'
              : '/ads/${d['ad_id']}/pay';
        }
        return '/payments';
      default:
        return '/notifications';
    }
  }
}
