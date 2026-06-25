import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/data/notification_repository.dart';

// Must be top-level — called by FCM when app is in background/terminated.
// Firebase is already initialised before this runs.
@pragma('vm:entry-point')
Future<void> _onFcmBackgroundMessage(RemoteMessage message) async {}

const _channelId = 'barqwadih_main';
const _channelName = 'إشعارات برق وديه';

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

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSub;
  bool _isRegistered = false;

  /// Listen to this notifier to drive notification-tap navigation.
  /// Set back to null after consuming the value.
  static final pendingRoute = ValueNotifier<String?>(null);

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> init() async {
    // Register the top-level background handler first.
    FirebaseMessaging.onBackgroundMessage(_onFcmBackgroundMessage);

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
    _isRegistered = false;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    final token = await _messaging.getToken();
    if (token != null) await _register(token, repo);

    // Keep the backend in sync when FCM rotates the token.
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
      if (_isRegistered) _register(newToken, repo);
    });
  }

  /// Deactivate the device token on the backend then clear state.
  /// Call just before logout.
  Future<void> deregisterToken(NotificationRepository repo) async {
    _isRegistered = false;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    try {
      final token = await _messaging.getToken();
      if (token != null) await repo.deactivateDevice(token);
    } catch (_) {}
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _register(String token, NotificationRepository repo) async {
    try {
      await repo.registerDevice(
        fcmToken: token,
        deviceType: Platform.isIOS ? 'ios' : 'android',
      );
      _isRegistered = true;
    } catch (_) {
      _isRegistered = false;
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

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
        if (d['conversation_id'] != null)
          return '/messages/${d['conversation_id']}';
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
