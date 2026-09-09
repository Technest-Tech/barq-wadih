import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/auth_user.dart';
import '../network/api_client.dart';

enum MarketingEvent {
  registration(tikTokName: 'Registration', snapName: 'SIGN_UP'),
  login(tikTokName: 'Login', snapName: 'LOGIN'),
  viewContent(tikTokName: 'ViewContent', snapName: 'VIEW_CONTENT'),
  search(tikTokName: 'Search', snapName: 'SEARCH'),
  addToWishlist(tikTokName: 'AddToWishlist', snapName: 'ADD_TO_WISHLIST'),
  generateLead(tikTokName: 'GenerateLead', snapName: 'CUSTOM_EVENT_2'),
  publishAd(tikTokName: 'PublishAd', snapName: 'CUSTOM_EVENT_1');

  const MarketingEvent({required this.tikTokName, required this.snapName});

  final String tikTokName;
  final String snapName;
}

final marketingTrackingProvider = Provider<MarketingTrackingService>((ref) {
  return MarketingTrackingService(ref.watch(dioProvider));
});

/// Sends the same audited business event to TikTok's native SDK and to the
/// backend, which enriches and forwards it to Snapchat Conversions API.
/// Tracking is always best-effort and must never block the user's action.
class MarketingTrackingService {
  MarketingTrackingService(this._dio);

  static const _channel = MethodChannel('com.barqwadih.app/marketing_tracking');
  static const _snapInstallReportedKey = 'snap_install_reported';
  final Dio _dio;
  Map<String, dynamic>? _snapAppData;
  AuthUser? _currentUser;
  bool _initialized = false;
  bool _trackingAuthorized = !Platform.isIOS;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _trackingAuthorized =
          await _channel.invokeMethod<bool>('requestTrackingAuthorization') ??
          false;
    } on MissingPluginException {
      return;
    } on PlatformException catch (error) {
      debugPrint('Tracking authorization unavailable: ${error.message}');
    }

    final currentUser = _currentUser;
    if (_trackingAuthorized && currentUser != null) {
      await _identifyTikTokUser(currentUser);
    }

    // TikTok logs InstallApp/LaunchAPP automatically. Snapchat CAPI does not.
    final preferences = await SharedPreferences.getInstance();
    if (!(preferences.getBool(_snapInstallReportedKey) ?? false)) {
      final accepted = await _sendSnapEvent(
        snapName: 'APP_INSTALL',
        eventId: _newEventId('app_install'),
        properties: const {'event_tag': 'first_install'},
      );
      if (accepted) {
        await preferences.setBool(_snapInstallReportedKey, true);
      }
    }

    await _sendSnapEvent(
      snapName: 'APP_OPEN',
      eventId: _newEventId('app_open'),
      properties: const {'event_tag': 'app_open'},
    );
  }

  Future<void> identify(AuthUser user) async {
    _currentUser = user;
    // iOS advanced matching is withheld when ATT is denied. Anonymous events
    // may still be sent with advertiser_tracking_enabled=false.
    if (Platform.isIOS && !_trackingAuthorized) return;
    await _identifyTikTokUser(user);
  }

  Future<void> _identifyTikTokUser(AuthUser user) async {
    try {
      await _channel.invokeMethod<void>('identifyTikTokUser', {
        'externalId': user.id.toString(),
        'username': user.username ?? user.name,
        'phone': user.phone,
        'email': user.email,
      });
    } on MissingPluginException {
      // Unit tests and non-mobile platforms intentionally have no native SDK.
    } on PlatformException catch (error) {
      debugPrint('TikTok identify failed: ${error.message}');
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    try {
      await _channel.invokeMethod<void>('logoutTikTokUser');
    } on MissingPluginException {
      // No native SDK in tests.
    } on PlatformException catch (error) {
      debugPrint('TikTok logout failed: ${error.message}');
    }
  }

  Future<void> track(
    MarketingEvent event, {
    Map<String, dynamic> properties = const {},
  }) async {
    final eventId = _newEventId(event.snapName.toLowerCase());
    await Future.wait([
      _sendTikTokEvent(
        name: event.tikTokName,
        eventId: eventId,
        properties: properties,
      ),
      _sendSnapEvent(
        snapName: event.snapName,
        eventId: eventId,
        properties: properties,
      ),
    ]);
  }

  Future<void> _sendTikTokEvent({
    required String name,
    required String eventId,
    required Map<String, dynamic> properties,
  }) async {
    try {
      await _channel.invokeMethod<void>('trackTikTokEvent', {
        'name': name,
        'eventId': eventId,
        'properties': _jsonSafe(properties),
      });
    } on MissingPluginException {
      // No native SDK in tests.
    } on PlatformException catch (error) {
      debugPrint('TikTok event $name failed: ${error.message}');
    }
  }

  Future<bool> _sendSnapEvent({
    required String snapName,
    required String eventId,
    required Map<String, dynamic> properties,
  }) async {
    try {
      final appData = await _loadSnapAppData();
      if (appData == null) return false;
      await _dio.post<void>(
        '/tracking/events',
        data: {
          'event_name': snapName,
          'event_id': eventId,
          'event_time': DateTime.now().millisecondsSinceEpoch,
          'app_data': appData,
          'custom_data': _snapCustomData(properties),
        },
        options: Options(
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      return true;
    } on MissingPluginException {
      // No native platform data in tests.
    } on DioException catch (error) {
      debugPrint('Snapchat event $snapName failed: ${error.message}');
    } on PlatformException catch (error) {
      debugPrint('Snapchat platform data failed: ${error.message}');
    }
    return false;
  }

  Future<Map<String, dynamic>?> _loadSnapAppData() async {
    if (_snapAppData != null) return _snapAppData;
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getSnapAppData',
    );
    if (result == null || result['app_id'] == null) return null;
    _snapAppData = Map<String, dynamic>.from(result);
    return _snapAppData;
  }

  String _newEventId(String prefix) {
    final random = Random.secure();
    final entropy = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return 'barq_${prefix}_${DateTime.now().microsecondsSinceEpoch}_$entropy';
  }

  Map<String, dynamic> _snapCustomData(Map<String, dynamic> properties) {
    const supported = {
      'content_id',
      'content_ids',
      'content_name',
      'content_category',
      'content_type',
      'currency',
      'value',
      'search_string',
      'order_id',
      'event_tag',
      'status',
    };
    final customData = <String, dynamic>{};
    final customFields = <String, dynamic>{};
    for (final entry in properties.entries) {
      if (supported.contains(entry.key)) {
        customData[entry.key] = entry.value;
      } else {
        customFields[entry.key] = entry.value;
      }
    }
    if (customFields.isNotEmpty) customData['custom_fields'] = customFields;
    if (customData['content_id'] != null && customData['content_ids'] == null) {
      customData['content_ids'] = [customData.remove('content_id')];
    }
    return _jsonSafe(customData);
  }

  Map<String, dynamic> _jsonSafe(Map<String, dynamic> input) {
    return input.map((key, value) {
      if (value == null || value is String || value is num || value is bool) {
        return MapEntry(key, value);
      }
      if (value is List) {
        return MapEntry(
          key,
          value
              .where((item) => item is String || item is num || item is bool)
              .toList(),
        );
      }
      return MapEntry(key, value.toString());
    });
  }
}
