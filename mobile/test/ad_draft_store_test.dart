import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:barq_wadih/features/ads/data/ad_draft_store.dart';

/// The draft is the only copy of an unpublished ad, so reading one back has to
/// be total: never throw, and never hand the wizard something half-formed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = AdDraftStore();

  AdDraft draft({
    DateTime? savedAt,
    String title = 'ثلاجة ال جي',
    List<String> imagePaths = const [],
  }) => AdDraft(
    savedAt: savedAt ?? DateTime.now(),
    step: 2,
    pledgeAccepted: true,
    category: {
      'id': 7,
      'name_ar': 'أجهزة',
      'name_en': 'appliances',
      'slug': 'appliances',
    },
    browsingCategoryId: 3,
    title: title,
    description: 'ثلاجة بحالة ممتازة',
    price: '1500',
    phone: '0512345678',
    priceOption: 'negotiable',
    showPhonePublicly: true,
    fieldValues: const {'color': 'أبيض'},
    imagePaths: imagePaths,
    region: null,
    city: {
      'id': 3,
      'name_ar': 'الرياض',
      'name_en': 'Riyadh',
      'slug': 'riyadh',
    },
    district: null,
    districtFreeText: 'النرجس',
    latitude: 24.7,
    longitude: 46.6,
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a saved draft reads back field for field', () async {
    await store.save(draft());
    final restored = await store.read();

    expect(restored, isNotNull);
    expect(restored!.title, 'ثلاجة ال جي');
    expect(restored.price, '1500');
    expect(restored.priceOption, 'negotiable');
    expect(restored.showPhonePublicly, isTrue);
    expect(restored.fieldValues, {'color': 'أبيض'});
    expect(restored.category?['id'], 7);
    expect(restored.city?['name_ar'], 'الرياض');
    expect(restored.districtFreeText, 'النرجس');
    expect(restored.latitude, 24.7);
    expect(restored.browsingCategoryId, 3);
    expect(restored.step, 2);
  });

  test('no draft stored reads as null', () async {
    expect(await store.read(), isNull);
  });

  test('clear removes the draft', () async {
    await store.save(draft());
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('an empty draft is not offered back', () async {
    await store.save(
      AdDraft(
        savedAt: DateTime.now(),
        step: 0,
        pledgeAccepted: true,
        category: null,
        browsingCategoryId: null,
        title: '   ',
        description: '',
        price: '',
        phone: '',
        priceOption: 'fixed',
        showPhonePublicly: false,
        fieldValues: const {},
        imagePaths: const [],
        region: null,
        city: null,
        district: null,
        districtFreeText: '',
        latitude: null,
        longitude: null,
      ),
    );
    expect(
      await store.read(),
      isNull,
      reason: 'accepting the pledge alone is not an ad worth restoring',
    );
  });

  test('a draft past its shelf life is dropped, not resurrected', () async {
    await store.save(
      draft(savedAt: DateTime.now().subtract(const Duration(days: 8))),
    );
    expect(await store.read(), isNull);

    SharedPreferences.setMockInitialValues({});
    await store.save(
      draft(savedAt: DateTime.now().subtract(const Duration(days: 6))),
    );
    expect(await store.read(), isNotNull);
  });

  test('photos whose files are gone are dropped from the draft', () async {
    await store.save(
      draft(imagePaths: const ['/definitely/not/here.jpg']),
    );
    final restored = await store.read();

    // The rest of the ad is still worth restoring; only the photo is lost.
    expect(restored, isNotNull);
    expect(restored!.imagePaths, isEmpty);
    expect(restored.title, 'ثلاجة ال جي');
  });

  test('a draft written by an older build is ignored', () async {
    final old = draft().toJson()..['version'] = AdDraft.currentVersion - 1;
    SharedPreferences.setMockInitialValues({
      'post_ad_draft_v1': jsonEncode(old),
    });
    expect(await store.read(), isNull);
  });

  test('corrupt JSON does not throw', () async {
    SharedPreferences.setMockInitialValues({
      'post_ad_draft_v1': 'not json at all',
    });
    expect(await store.read(), isNull);
  });

  test('a draft missing saved_at is ignored', () async {
    final broken = draft().toJson()..remove('saved_at');
    SharedPreferences.setMockInitialValues({
      'post_ad_draft_v1': jsonEncode(broken),
    });
    expect(await store.read(), isNull);
  });
}
