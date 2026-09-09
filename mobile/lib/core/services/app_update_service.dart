import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class AppUpdate {
  const AppUpdate(this.version, this.storeUrl, {this.releaseId});
  final String version;
  final Uri storeUrl;
  final String? releaseId;
  String get reminderKey =>
      'app_update.remind_after.${storeUrl.host}.${releaseId ?? version}';
}

/// Published server policies plus platform-store detection on launch/resume.
/// Missing services and offline checks never prevent opening the application.
class AppUpdateService {
  AppUpdateService({
    Dio? dio,
    Future<Map<String, dynamic>?> Function()? installedInfo,
    Future<Map<String, dynamic>?> Function()? releasePolicy,
    DateTime Function()? now,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 5),
             ),
           ),
       _installedInfo =
           installedInfo ??
           (() => const MethodChannel(
             'com.barqwadih.app/app_update',
           ).invokeMapMethod<String, dynamic>('installedInfo')),
       _releasePolicy = releasePolicy,
       _now = now ?? DateTime.now;

  final Dio _dio;
  final Future<Map<String, dynamic>?> Function() _installedInfo;
  final Future<Map<String, dynamic>?> Function()? _releasePolicy;
  final DateTime Function() _now;
  DateTime? _lastAttempt;
  bool _checking = false;

  Future<Map<String, dynamic>?> _policy() async {
    try {
      if (_releasePolicy != null) {
        return await _releasePolicy().timeout(const Duration(seconds: 5));
      }
      final response = await _dio
          .get<dynamic>(
            '${AppConstants.apiBaseUrl}/${AppConstants.apiVersion}/app-updates',
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 5));
      final data = response.data;
      return data is Map && data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<AppUpdate?> check() async {
    final now = _now();
    if (_checking ||
        (_lastAttempt != null &&
            now.difference(_lastAttempt!) < const Duration(minutes: 5))) {
      return null;
    }
    _checking = true;
    _lastAttempt = now;
    try {
      final info = await _installedInfo().timeout(const Duration(seconds: 10));
      if (info == null) return null;
      final policies = await _policy();
      final android = info['platform'] == 'android';
      final candidate = android
          ? _androidUpdate(info, policies?['android'])
          : await _iosUpdate(info, policies?['ios']);
      if (candidate == null) return null;
      final prefs = await SharedPreferences.getInstance();
      // A reminder for version A must not suppress a newly published version B.
      if ((prefs.getInt(candidate.reminderKey) ?? 0) >
          now.millisecondsSinceEpoch) {
        return null;
      }
      return candidate;
    } catch (_) {
      return null;
    } finally {
      _checking = false;
    }
  }

  AppUpdate? _androidUpdate(Map<String, dynamic> info, dynamic policy) {
    if (info['bundleId'] != 'com.barqwadih.barq_wadih') return null;
    final installed = info['buildNumber'];
    if (installed is! int) return null;
    final available = info['availableBuildNumber'];
    final store = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.barqwadih.barq_wadih',
    );
    final version = policy is Map ? policy['version'] : null;
    final build = policy is Map ? policy['build'] : null;
    final validPolicy =
        policy is Map &&
        policy['bundle_id'] == info['bundleId'] &&
        version is String &&
        _validVersion(version) &&
        build is int &&
        policy['minimum_sdk'] is int &&
        info['sdkVersion'] is int &&
        (info['sdkVersion'] as int) >= (policy['minimum_sdk'] as int);
    if (info['updateAvailable'] == true &&
        available is int &&
        available > installed) {
      return AppUpdate(
        validPolicy && build == available ? version : '',
        store,
        releaseId: available.toString(),
      );
    }
    // A successful Play response is authoritative for rollout/device eligibility.
    // Only use a globally published policy when Play was unavailable, and never
    // send a debug/sideloaded installation to an incompatible store update.
    if (info['playAvailabilityKnown'] != false ||
        info['storeInstalled'] != true ||
        !validPolicy ||
        build <= installed) {
      return null;
    }
    return AppUpdate(version, store, releaseId: build.toString());
  }

  AppUpdate? _iosPolicy(Map<String, dynamic> info, dynamic policy) {
    if (info['bundleId'] != 'com.barqwadih.app' ||
        policy is! Map ||
        policy['bundle_id'] != info['bundleId']) {
      return null;
    }
    final version = policy['version'];
    final minimumOS = policy['minimum_os'];
    if (version is! String ||
        minimumOS is! String ||
        !_validVersion(minimumOS) ||
        info['version'] is! String ||
        info['osVersion'] is! String ||
        !isNewerVersion(version, info['version'] as String) ||
        isNewerVersion(minimumOS, info['osVersion'] as String)) {
      return null;
    }
    return AppUpdate(
      version,
      Uri.parse('https://apps.apple.com/app/id6800784915'),
    );
  }

  Future<AppUpdate?> _iosUpdate(
    Map<String, dynamic> info,
    dynamic policy,
  ) async {
    final published = _iosPolicy(info, policy);
    try {
      final store = await _appleUpdate(info);
      // A server setting left on an older release must not hide the next one.
      if (store != null &&
          (published == null ||
              isNewerVersion(store.version, published.version))) {
        return store;
      }
    } catch (_) {
      // The published policy still works when Apple's lookup is unavailable.
    }
    return published;
  }

  Future<AppUpdate?> _appleUpdate(Map<String, dynamic> info) async {
    if (info['bundleId'] != 'com.barqwadih.app') return null;
    final response = await _dio
        .get<dynamic>(
          'https://itunes.apple.com/lookup',
          queryParameters: {
            'bundleId': info['bundleId'],
            'country': const String.fromEnvironment(
              'APP_STORE_COUNTRY',
              defaultValue: 'sa',
            ),
            'entity': 'software',
          },
          options: Options(responseType: ResponseType.plain),
        )
        .timeout(const Duration(seconds: 5));
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is! Map || data['results'] is! List) return null;
    for (final entry in data['results'] as List) {
      if (entry is! Map ||
          entry['bundleId'] != info['bundleId'] ||
          entry['trackId']?.toString() != '6800784915') {
        continue;
      }
      final version = entry['version'];
      final minimumOS = entry['minimumOsVersion'];
      final url = Uri.tryParse(entry['trackViewUrl']?.toString() ?? '');
      if (version is! String ||
          url == null ||
          url.scheme != 'https' ||
          url.host != 'apps.apple.com' ||
          !url.path.contains('/id6800784915') ||
          minimumOS is! String ||
          !_validVersion(minimumOS) ||
          !isNewerVersion(version, info['version'] as String) ||
          isNewerVersion(minimumOS, info['osVersion'] as String)) {
        continue;
      }
      return AppUpdate(version, url);
    }
    return null;
  }

  Future<void> remindTomorrow(AppUpdate update) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        update.reminderKey,
        _now().add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
    } catch (_) {
      /* Optional preference: keep the app usable. */
    }
  }

  static bool _validVersion(String value) =>
      RegExp(r'^\d+(\.\d+)*$').hasMatch(value);

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
