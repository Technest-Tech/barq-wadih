import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdate {
  const AppUpdate(this.version, this.storeUrl);
  final String version;
  final Uri storeUrl;
}

/// Uses Apple's public listing or Google Play's device-specific availability.
class AppUpdateService {
  AppUpdateService({
    Dio? dio,
    Future<Map<String, dynamic>?> Function()? installedInfo,
    DateTime Function()? now,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 8),
             ),
           ),
       _installedInfo =
           installedInfo ??
           (() => const MethodChannel(
             'com.barqwadih.app/app_update',
           ).invokeMapMethod<String, dynamic>('installedInfo')),
       _now = now ?? DateTime.now;

  final Dio _dio;
  final Future<Map<String, dynamic>?> Function() _installedInfo;
  final DateTime Function() _now;
  DateTime? _lastAttempt;
  bool _checking = false;
  static const _reminderKey = 'app_update.remind_after';

  Future<AppUpdate?> check() async {
    final now = _now();
    if (_checking ||
        (_lastAttempt != null &&
            now.difference(_lastAttempt!) < const Duration(hours: 1))) {
      return null;
    }
    _checking = true;
    _lastAttempt = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getInt(_reminderKey) ?? 0) > now.millisecondsSinceEpoch) {
        return null;
      }
      final info = await _installedInfo().timeout(const Duration(seconds: 10));
      if (info == null) return null;
      if (info['platform'] == 'android') {
        final installed = info['buildNumber'];
        final available = info['availableBuildNumber'];
        if (info['bundleId'] != 'com.barqwadih.barq_wadih' ||
            info['updateAvailable'] != true ||
            installed is! num ||
            available is! num ||
            available <= installed) {
          return null;
        }
        // Google Play exposes a version code, not the release's display name.
        return AppUpdate(
          '',
          Uri.https('play.google.com', '/store/apps/details', {
            'id': 'com.barqwadih.barq_wadih',
          }),
        );
      }
      final bundleId = info['bundleId'] as String;
      final response = await _dio.get<dynamic>(
        'https://itunes.apple.com/lookup',
        queryParameters: {
          'bundleId': bundleId,
          // Saudi Arabia is the app's primary distribution market.
          'country': const String.fromEnvironment(
            'APP_STORE_COUNTRY',
            defaultValue: 'sa',
          ),
          'entity': 'software',
        },
        options: Options(responseType: ResponseType.plain),
      );
      final data = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (data is! Map || data['results'] is! List) return null;
      for (final entry in data['results'] as List) {
        if (entry is! Map || entry['bundleId'] != bundleId) continue;
        final version = entry['version'];
        final url = Uri.tryParse(entry['trackViewUrl']?.toString() ?? '');
        if (version is! String ||
            url == null ||
            url.scheme != 'https' ||
            url.host != 'apps.apple.com' ||
            !isNewerVersion(version, info['version'] as String)) {
          continue;
        }
        final minimumOS = entry['minimumOsVersion'];
        if (minimumOS is String &&
            isNewerVersion(minimumOS, info['osVersion'] as String)) {
          continue;
        }
        return AppUpdate(version, url);
      }
    } catch (_) {
      // An optional update check must never prevent using the app offline.
    } finally {
      _checking = false;
    }
    return null;
  }

  Future<void> remindTomorrow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _reminderKey,
        _now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
    } catch (_) {
      // In-memory throttling still applies if local storage is unavailable.
    }
  }

  static bool isNewerVersion(String candidate, String installed) {
    List<int>? parse(String value) {
      final release = value.split('+').first;
      if (!RegExp(r'^\d+(\.\d+)*$').hasMatch(release)) return null;
      return release.split('.').map(int.parse).toList();
    }

    final a = parse(candidate);
    final b = parse(installed);
    if (a == null || b == null) return false;
    for (var i = 0; i < a.length || i < b.length; i++) {
      final difference = (i < a.length ? a[i] : 0) - (i < b.length ? b[i] : 0);
      if (difference != 0) return difference > 0;
    }
    return false;
  }
}
