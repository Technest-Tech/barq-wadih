// lib/features/ads/data/ad_draft_store.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An unfinished ad, parked on disk so the seller does not lose it when the OS
/// kills the app — which Android does routinely while the system photo picker
/// is in the foreground.
///
/// Models are stored in the same JSON shape the API returns them in, so they
/// rehydrate through the existing `fromJson` factories rather than a second,
/// drifting set of constructors.
@immutable
class AdDraft {
  /// Bumped whenever the stored shape changes; older drafts are dropped rather
  /// than half-read.
  static const int currentVersion = 1;

  /// A draft older than this is stale enough that restoring it would confuse
  /// more than it helps.
  static const Duration maxAge = Duration(days: 7);

  final DateTime savedAt;
  final int step;
  final bool pledgeAccepted;
  final Map<String, dynamic>? category;
  final int? browsingCategoryId;
  final String title;
  final String description;
  final String price;
  final String phone;
  final String priceOption;
  final bool showPhonePublicly;
  final Map<String, String> fieldValues;
  final List<String> imagePaths;
  final Map<String, dynamic>? region;
  final Map<String, dynamic>? city;
  final Map<String, dynamic>? district;
  final String districtFreeText;
  final double? latitude;
  final double? longitude;

  const AdDraft({
    required this.savedAt,
    required this.step,
    required this.pledgeAccepted,
    required this.category,
    required this.browsingCategoryId,
    required this.title,
    required this.description,
    required this.price,
    required this.phone,
    required this.priceOption,
    required this.showPhonePublicly,
    required this.fieldValues,
    required this.imagePaths,
    required this.region,
    required this.city,
    required this.district,
    required this.districtFreeText,
    required this.latitude,
    required this.longitude,
  });

  /// True when there is nothing worth offering to restore.
  bool get isEmpty =>
      title.trim().isEmpty &&
      description.trim().isEmpty &&
      price.trim().isEmpty &&
      imagePaths.isEmpty &&
      category == null &&
      fieldValues.values.every((v) => v.trim().isEmpty);

  bool get isStale => DateTime.now().difference(savedAt) > maxAge;

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    'saved_at': savedAt.toIso8601String(),
    'step': step,
    'pledge_accepted': pledgeAccepted,
    'category': category,
    'browsing_category_id': browsingCategoryId,
    'title': title,
    'description': description,
    'price': price,
    'phone': phone,
    'price_option': priceOption,
    'show_phone_publicly': showPhonePublicly,
    'field_values': fieldValues,
    'image_paths': imagePaths,
    'region': region,
    'city': city,
    'district': district,
    'district_free_text': districtFreeText,
    'latitude': latitude,
    'longitude': longitude,
  };

  static AdDraft? fromJson(Map<String, dynamic> json) {
    if (json['version'] != currentVersion) return null;
    final savedAt = DateTime.tryParse(json['saved_at'] as String? ?? '');
    if (savedAt == null) return null;
    return AdDraft(
      savedAt: savedAt,
      step: (json['step'] as num?)?.toInt() ?? 0,
      pledgeAccepted: json['pledge_accepted'] as bool? ?? false,
      category: json['category'] as Map<String, dynamic>?,
      browsingCategoryId: (json['browsing_category_id'] as num?)?.toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: json['price'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      priceOption: json['price_option'] as String? ?? 'fixed',
      showPhonePublicly: json['show_phone_publicly'] as bool? ?? false,
      fieldValues: switch (json['field_values']) {
        final Map<dynamic, dynamic> m => {
          for (final e in m.entries) '${e.key}': '${e.value}',
        },
        _ => <String, String>{},
      },
      imagePaths: switch (json['image_paths']) {
        final List<dynamic> l => [for (final p in l) '$p'],
        _ => <String>[],
      },
      region: json['region'] as Map<String, dynamic>?,
      city: json['city'] as Map<String, dynamic>?,
      district: json['district'] as Map<String, dynamic>?,
      districtFreeText: json['district_free_text'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// Reads and writes the single in-progress ad draft.
class AdDraftStore {
  static const _key = 'post_ad_draft_v1';
  static const _imagesDirName = 'ad_draft_images';

  const AdDraftStore();

  Future<void> save(AdDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(draft.toJson()));
  }

  /// The stored draft, or null when there is none, it is unreadable, written by
  /// an older version, or too old to be useful. Photos whose files no longer
  /// exist are dropped, so the caller never restores a broken gallery.
  Future<AdDraft?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    AdDraft? draft;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) draft = AdDraft.fromJson(decoded);
    } on FormatException {
      draft = null;
    }
    if (draft == null || draft.isStale) {
      await clear();
      return null;
    }

    final surviving = <String>[];
    for (final path in draft.imagePaths) {
      if (await File(path).exists()) surviving.add(path);
    }
    if (surviving.length != draft.imagePaths.length) {
      draft = AdDraft(
        savedAt: draft.savedAt,
        step: draft.step,
        pledgeAccepted: draft.pledgeAccepted,
        category: draft.category,
        browsingCategoryId: draft.browsingCategoryId,
        title: draft.title,
        description: draft.description,
        price: draft.price,
        phone: draft.phone,
        priceOption: draft.priceOption,
        showPhonePublicly: draft.showPhonePublicly,
        fieldValues: draft.fieldValues,
        imagePaths: surviving,
        region: draft.region,
        city: draft.city,
        district: draft.district,
        districtFreeText: draft.districtFreeText,
        latitude: draft.latitude,
        longitude: draft.longitude,
      );
    }
    return draft.isEmpty ? null : draft;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    final dir = await _imagesDir();
    if (dir != null && await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Best-effort: a leftover copy costs disk, never correctness.
      }
    }
  }

  /// Copies a freshly picked photo somewhere it will outlive the app process.
  ///
  /// image_picker hands back files in a cache/temp directory that both iOS and
  /// Android are free to purge, which would leave a restored draft pointing at
  /// nothing. Returns the original file unchanged if the copy is not possible —
  /// a draft with a photo that might vanish still beats refusing the photo.
  Future<XFile> retain(XFile source) async {
    final dir = await _imagesDir();
    if (dir == null) return source;
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
      final name = source.path.split(Platform.pathSeparator).last;
      final target =
          '${dir.path}${Platform.pathSeparator}'
          '${DateTime.now().microsecondsSinceEpoch}_$name';
      await File(source.path).copy(target);
      return XFile(target, mimeType: source.mimeType);
    } on FileSystemException {
      return source;
    }
  }

  /// Deletes retained photos the draft no longer references.
  Future<void> pruneImages(Iterable<String> keep) async {
    final dir = await _imagesDir();
    if (dir == null || !await dir.exists()) return;
    final kept = keep.toSet();
    try {
      await for (final entity in dir.list()) {
        if (entity is File && !kept.contains(entity.path)) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      // Best-effort cleanup.
    }
  }

  /// Application support rather than documents: these are working files, not
  /// something the seller should see in Files or have restored from a backup.
  Future<Directory?> _imagesDir() async {
    try {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}${Platform.pathSeparator}$_imagesDirName');
    } on MissingPluginException {
      return null; // No platform implementation (widget tests).
    } on Exception {
      return null;
    }
  }
}
