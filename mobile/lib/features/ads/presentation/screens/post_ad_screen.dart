// lib/features/ads/presentation/screens/post_ad_screen.dart

import 'dart:async';
import 'dart:io';

import '../../../../core/network/api_client.dart';
import '../../../../core/services/image_upload_preprocessor.dart';
import '../../../../core/services/marketing_tracking_service.dart';
import '../../../../core/widgets/app_cached_image.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'map_location_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../categories/data/category_api.dart';
import '../../../categories/domain/category_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../regions/presentation/region_city_picker.dart';
import '../../../regions/domain/region_model.dart';
import '../../../regions/data/region_api.dart';
import '../../data/ad_api.dart';
import '../../data/ad_draft_store.dart';
import '../../domain/ad_model.dart';
import '../../../../core/widgets/riyal_text.dart';

enum _PriceOption { fixed, negotiable, callForPrice }

/// A Saudi mobile number in canonical local form: 05 followed by 8 digits.
bool isValidSaudiPhone(String raw) => RegExp(r'^05\d{8}$').hasMatch(raw.trim());

// Ad title/description length bounds — must match the backend (StoreAdRequest).
const int kTitleMinLen = 3;
const int kTitleMaxLen = 100;
const int kDescMinLen = 10;
const int kDescMaxLen = 5000;

class PostAdScreen extends ConsumerStatefulWidget {
  final int? adId;
  const PostAdScreen({super.key, this.adId});

  @override
  ConsumerState<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<PostAdScreen>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  late int _step;
  bool _submitting = false;
  String? _submitStatus;
  int? _uploadPercent;
  bool _loadingExisting = false;
  Map<String, String> _fieldErrors = {};

  /// A new ad is parked on disk as it is written, so an OS kill — routine on
  /// Android while the system photo picker is up — does not cost the seller
  /// the whole thing. Editing has the server's copy to fall back on and needs
  /// no draft.
  static const _draftStore = AdDraftStore();
  Timer? _draftSaveTimer;
  bool _draftPromptShown = false;

  /// Flipped by any edit the seller makes. Drives the "discard changes?"
  /// prompt so backing out of an untouched form never nags, while backing out
  /// of a half-written ad always warns first.
  bool _dirty = false;

  // Step 0 — Pledge
  bool _pledgeAccepted = false;

  // Step 1 — Category
  CategoryModel? _selectedCategory;

  // The parent the seller has drilled into, if any. Held here rather than in
  // the step widget so it survives the step being rebuilt, and so the back
  // gesture can leave the sub-list before it leaves the step.
  CategoryModel? _browsingCategory;

  // Step 2 — Details
  // The account determines the commission tier; there is no user-selectable
  // switch that could claim the dealer rate.
  String get _sellerType {
    final auth = ref.read(authProvider);
    return auth is AuthAuthenticated && auth.user.isDealer
        ? 'dealer'
        : 'individual';
  }

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  _PriceOption _priceOption = _PriceOption.fixed;
  // Publishing must never require a phone number: an account can be created
  // with an email address alone, and buyers always reach the seller through
  // in-app chat. Showing the number publicly is strictly opt-in.
  bool _showPhonePublicly = false;

  // Dynamic category field values (e.g. the cars fields) keyed by field_key.
  final Map<String, TextEditingController> _dynControllers = {};
  final Map<String, String> _fieldValues = {};

  // Step 3 — Images. One ordered list holds photos already on the ad and ones
  // picked in this session, so a freshly added photo can be dragged ahead of
  // the old ones and become the cover.
  final List<_GalleryEntry> _gallery = [];
  final Set<int> _removedImageIds = {};
  bool _recoveringImages = false;

  // Step 4 — Location + District
  RegionModel? _selectedRegion;
  CityModel? _selectedCity;
  DistrictModel? _selectedDistrict;
  final _districtFreeTextCtrl = TextEditingController();
  List<DistrictModel>? _districtsForCity;
  int? _districtsLoadedForCityId;
  bool _loadingDistricts = false;
  double? _latitude;
  double? _longitude;

  bool get _isEditMode => widget.adId != null;

  /// Editing skips the pledge, so the wizard does not always start at 0.
  int get _firstStep => _isEditMode ? 1 : 0;
  static const int _lastStep = 4;

  static const int _maxImages = 10;

  /// Mirrors the API's `images.*|max:5120` rule.
  static const int _maxImageBytes = 5 * 1024 * 1024;

  bool get _step2Valid =>
      _titleCtrl.text.trim().length >= kTitleMinLen &&
      _descCtrl.text.trim().length >= kDescMinLen &&
      (!_showPhonePublicly || isValidSaudiPhone(_phoneCtrl.text)) &&
      (_priceOption == _PriceOption.callForPrice ||
          _priceCtrl.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Edit mode skips the pledge step (already agreed when first posting)
    _pageController = PageController(initialPage: _firstStep);
    _step = _firstStep;
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _priceCtrl,
      _phoneCtrl,
      _districtFreeTextCtrl,
    ]) {
      c.addListener(_touch);
    }
    if (_isEditMode) {
      _pledgeAccepted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingAd());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _offerDraftRestore();
        await _recoverLostImages();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Android may destroy the activity while the system photo picker is in
      // the foreground; the picked files are then parked until claimed.
      case AppLifecycleState.resumed:
        unawaited(_recoverLostImages());
      // The last moment before the OS is free to kill us. Write now rather
      // than waiting out the debounce.
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _draftSaveTimer?.cancel();
        if (!_isEditMode && _dirty) unawaited(_saveDraft());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Every edit funnels through here: it arms the discard prompt and queues a
  /// draft write. Debounced so typing a description is not 200 disk writes.
  void _touch() {
    _dirty = true;
    if (_isEditMode) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 700),
      () => unawaited(_saveDraft()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftSaveTimer?.cancel();
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _phoneCtrl.dispose();
    _districtFreeTextCtrl.dispose();
    for (final c in _dynControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Draft ──────────────────────────────────────────────────────────────────

  // Models are written back in the API's own JSON shape so they rehydrate
  // through the existing fromJson factories.
  Map<String, dynamic>? _categoryJson(CategoryModel? c) => c == null
      ? null
      : {
          'id': c.id,
          'name_ar': c.nameAr,
          'name_en': c.nameEn,
          'slug': c.slug,
          'icon': c.icon,
          'sort_order': c.sortOrder,
          'is_active': c.isActive,
          'is_free': c.isFree,
          'ads_count': c.adsCount,
          'fields_count': c.fieldsCount,
        };

  Map<String, dynamic>? _regionJson(RegionModel? r) => r == null
      ? null
      : {
          'id': r.id,
          'name_ar': r.nameAr,
          'name_en': r.nameEn,
          'slug': r.slug,
          'sort_order': r.sortOrder,
          'cities_count': r.citiesCount,
        };

  Map<String, dynamic>? _cityJson(CityModel? c) => c == null
      ? null
      : {
          'id': c.id,
          'name_ar': c.nameAr,
          'name_en': c.nameEn,
          'slug': c.slug,
          'latitude': c.latitude,
          'longitude': c.longitude,
          'ads_count': c.adsCount,
          'districts_count': c.districtsCount,
          'region': _regionJson(c.region),
        };

  Map<String, dynamic>? _districtJson(DistrictModel? d) =>
      d == null ? null : {'id': d.id, 'name_ar': d.nameAr, 'name_en': d.nameEn};

  AdDraft _currentDraft() => AdDraft(
    savedAt: DateTime.now(),
    step: _step,
    pledgeAccepted: _pledgeAccepted,
    category: _categoryJson(_selectedCategory),
    browsingCategoryId: _browsingCategory?.id,
    title: _titleCtrl.text,
    description: _descCtrl.text,
    price: _priceCtrl.text,
    phone: _phoneCtrl.text,
    priceOption: _priceOption.name,
    showPhonePublicly: _showPhonePublicly,
    fieldValues: Map<String, String>.from(_fieldValues),
    imagePaths: _pickedFiles.map((f) => f.path).toList(),
    region: _regionJson(_selectedRegion),
    city: _cityJson(_selectedCity),
    district: _districtJson(_selectedDistrict),
    districtFreeText: _districtFreeTextCtrl.text,
    latitude: _latitude,
    longitude: _longitude,
  );

  Future<void> _saveDraft() async {
    if (_isEditMode || _submitting) return;
    final draft = _currentDraft();
    // Emptying the form is itself a decision: leave the earlier draft parked
    // and the seller would be offered back an ad they had just cleared out.
    if (draft.isEmpty) {
      await _draftStore.clear();
      return;
    }
    await _draftStore.save(draft);
    // Photos the seller has since removed no longer need their retained copy.
    await _draftStore.pruneImages(draft.imagePaths);
  }

  Future<void> _discardDraft() async {
    _draftSaveTimer?.cancel();
    if (_isEditMode) return;
    await _draftStore.clear();
  }

  /// Offers the parked draft on entry. Declining throws it away, so the seller
  /// is never asked about the same abandoned ad twice.
  Future<void> _offerDraftRestore() async {
    if (_isEditMode || _draftPromptShown || !mounted) return;
    _draftPromptShown = true;

    final draft = await _draftStore.read();
    if (draft == null || !mounted) return;

    final missingPhotos = draft.step >= 3 && draft.imagePaths.isEmpty
        ? 'وقد تعذّر استرجاع الصور، '
        : '';
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'لديك إعلان لم يكتمل',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'بدأت بكتابة إعلان ولم تنشره. $missingPhotosهل تريد متابعته؟',
          textDirection: TextDirection.rtl,
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إعلان جديد'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('متابعة الإعلان'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      _applyDraft(draft);
    } else {
      await _draftStore.clear();
    }
  }

  void _applyDraft(AdDraft draft) {
    setState(() {
      _pledgeAccepted = draft.pledgeAccepted;
      if (draft.category != null) {
        _selectedCategory = CategoryModel.fromJson(draft.category!);
      }
      if (draft.browsingCategoryId != null) {
        // Only the id is read — step 1 looks the real category up in the list
        // it fetches, so a stub is enough and cannot go stale.
        _browsingCategory = CategoryModel(
          id: draft.browsingCategoryId!,
          nameAr: '',
          nameEn: '',
          slug: '',
          sortOrder: 0,
          isActive: true,
          isFree: false,
          adsCount: 0,
          fieldsCount: 0,
        );
      }
      _titleCtrl.text = draft.title;
      _descCtrl.text = draft.description;
      _priceCtrl.text = draft.price;
      _phoneCtrl.text = draft.phone;
      _priceOption = _PriceOption.values.firstWhere(
        (o) => o.name == draft.priceOption,
        orElse: () => _PriceOption.fixed,
      );
      _showPhonePublicly = draft.showPhonePublicly;
      _fieldValues
        ..clear()
        ..addAll(draft.fieldValues);
      for (final entry in draft.fieldValues.entries) {
        // Seed any controller step 2 already built for this key.
        final controller = _dynControllers[entry.key];
        if (controller != null) controller.text = entry.value;
      }
      _gallery
        ..clear()
        ..addAll(draft.imagePaths.map((p) => _GalleryEntry.picked(XFile(p))));
      if (draft.region != null) {
        _selectedRegion = RegionModel.fromJson(draft.region!);
      }
      if (draft.city != null) _selectedCity = CityModel.fromJson(draft.city!);
      if (draft.district != null) {
        _selectedDistrict = DistrictModel.fromJson(draft.district!);
      }
      _districtFreeTextCtrl.text = draft.districtFreeText;
      _latitude = draft.latitude;
      _longitude = draft.longitude;
      // A restored draft still holds unpublished work, so leaving must prompt.
      _dirty = true;
      // Photos that did not survive would strand the seller on a step they
      // cannot leave, so back up to the images step in that case.
      _step = (draft.imagePaths.isEmpty && draft.step > 3 ? 3 : draft.step)
          .clamp(_firstStep, _lastStep);
    });
    if (_pageController.hasClients) _pageController.jumpToPage(_step);
    final city = _selectedCity;
    if (city != null) _loadDistricts(city.id, preserveSelection: true);
  }

  // ── Load existing ad ───────────────────────────────────────────────────────

  Future<void> _loadExistingAd() async {
    setState(() => _loadingExisting = true);
    try {
      final ad = await ref.read(adRepositoryProvider).getAd(widget.adId!);
      if (!mounted) return;
      setState(() {
        if (ad.category != null) {
          final cat = CategoryModel(
            id: ad.category!.id,
            nameAr: ad.category!.nameAr,
            nameEn: '',
            slug: '',
            icon: ad.category!.icon,
            sortOrder: 0,
            isActive: true,
            isFree: false,
            adsCount: 0,
            fieldsCount: 0,
          );
          _selectedCategory = cat;
        }
        _titleCtrl.text = ad.title;
        _descCtrl.text = ad.description;
        _priceCtrl.text = ad.price?.toStringAsFixed(0) ?? '';
        _phoneCtrl.text = ad.contactPhone;
        _priceOption = ad.priceHidden
            ? _PriceOption.callForPrice
            : ad.isNegotiable
            ? _PriceOption.negotiable
            : _PriceOption.fixed;
        _showPhonePublicly = ad.showPhonePublicly;
        _gallery
          ..clear()
          ..addAll(ad.images.map(_GalleryEntry.existing));
        _removedImageIds.clear();

        for (final fv in ad.fieldValues) {
          _fieldValues[fv.fieldKey] = fv.value?.toString() ?? '';
        }

        if (ad.region != null) {
          _selectedRegion = RegionModel(
            id: ad.region!.id,
            nameAr: ad.region!.nameAr,
            nameEn: '',
            slug: '',
            sortOrder: 0,
            citiesCount: 0,
          );
        }
        if (ad.city != null) {
          _selectedCity = CityModel(
            id: ad.city!.id,
            nameAr: ad.city!.nameAr,
            nameEn: '',
            slug: '',
            adsCount: 0,
          );
        }
        if (ad.district != null) {
          _selectedDistrict = DistrictModel(
            id: ad.district!.id,
            nameAr: ad.district!.nameAr,
            nameEn: '',
          );
        }
      });

      if (_selectedCity != null) {
        // The ad's own district is already selected above; loading the city's
        // district list must not wipe it.
        _loadDistricts(_selectedCity!.id, preserveSelection: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر تحميل الإعلان: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        context.pop();
      }
    } finally {
      // Prefilling the controllers tripped the dirty listeners; nothing the
      // seller did, so exiting straight away must not prompt.
      if (mounted) {
        setState(() {
          _loadingExisting = false;
          _dirty = false;
        });
      }
    }
  }

  // ── Districts ──────────────────────────────────────────────────────────────

  Future<void> _loadDistricts(
    int cityId, {
    bool preserveSelection = false,
  }) async {
    if (_districtsLoadedForCityId == cityId) return;
    setState(() {
      _loadingDistricts = true;
      if (!preserveSelection) {
        _selectedDistrict = null;
        _districtFreeTextCtrl.clear();
      }
    });
    try {
      final districts = await ref
          .read(regionRepositoryProvider)
          .getDistricts(cityId);
      if (mounted) {
        setState(() {
          _districtsForCity = districts;
          _districtsLoadedForCityId = cityId;
          _loadingDistricts = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _districtsForCity = [];
          _districtsLoadedForCityId = cityId;
          _loadingDistricts = false;
        });
      }
    }
  }

  Future<void> _showDistrictPicker() async {
    if (_districtsForCity == null || _districtsForCity!.isEmpty) return;
    final result = await showModalBottomSheet<DistrictModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DistrictPickerSheet(districts: _districtsForCity!),
    );
    if (result != null) {
      setState(() {
        _selectedDistrict = result;
        _districtFreeTextCtrl.clear();
        _touch();
      });
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// The single way the wizard changes page.
  ///
  /// Always animates to an absolute target derived from [_step]. `nextPage` /
  /// `previousPage` read the *live* (fractional) page instead, so two taps
  /// inside the 350ms animation used to move the indicator twice and the page
  /// once — leaving the header, the visible step and the back button pointing
  /// at three different places.
  void _goToStep(int step) {
    final target = step.clamp(_firstStep, _lastStep);
    if (target == _step) return;
    // A keyboard left open over the next step hides its buttons.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = target);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _jumpToStep(int step) => _goToStep(step);

  void _next() => _goToStep(_step + 1);

  void _prev() => _goToStep(_step - 1);

  // ── Leaving the wizard ─────────────────────────────────────────────────────

  /// System back (Android button, iOS edge swipe) walks the wizard backwards
  /// rather than throwing the whole draft away. Only the first step closes it.
  Future<void> _handleBackIntent() async {
    if (_submitting) {
      _toast('جارٍ نشر الإعلان… الرجاء الانتظار حتى ينتهي الرفع.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();

    // Inside a sub-category list, back returns to the parent list first.
    if (_step == 1 && _browsingCategory != null) {
      setState(() => _browsingCategory = null);
      return;
    }
    if (_step > _firstStep) {
      _goToStep(_step - 1);
      return;
    }
    await _closeWizard();
  }

  /// The X in the app bar: leaves the wizard entirely, confirming first if the
  /// seller has anything unsaved.
  Future<void> _closeWizard() async {
    if (_submitting) {
      _toast('جارٍ نشر الإعلان… الرجاء الانتظار حتى ينتهي الرفع.');
      return;
    }
    if (_dirty && !await _confirmDiscard()) return;
    // Fire-and-forget: clearing the parked draft is cleanup, and the seller
    // should not watch a spinner over a disk write to leave the screen.
    unawaited(_discardDraft());
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      // Reached by deep link, so there is nothing underneath to pop back to.
      context.go(AppRoutes.home);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'إلغاء الإعلان؟',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          _isEditMode
              ? 'ستفقد التعديلات التي أجريتها على الإعلان.'
              : 'ستفقد البيانات والصور التي أدخلتها في هذا الإعلان.',
          textDirection: TextDirection.rtl,
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('متابعة التعبئة'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('تجاهل', style: TextStyle(color: Colors.red.shade600)),
          ),
        ],
      ),
    );
    return discard == true;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textDirection: TextDirection.rtl),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  /// Dynamic field values are defined by the chosen category, so moving an ad
  /// to a different one drops them — the API wipes them server-side for the
  /// same reason and demands the new category's required fields with the same
  /// request. Controllers are cleared rather than disposed: step 2 may still be
  /// alive in the PageView and holding on to them.
  void _selectCategory(CategoryModel category) {
    setState(() {
      if (_selectedCategory?.id != category.id) {
        for (final controller in _dynControllers.values) {
          controller.clear();
        }
        _fieldValues.clear();
        _fieldErrors = {};
      }
      _selectedCategory = category;
      _touch();
    });
  }

  /// Lazily-created controller for a dynamic category field, seeded from any
  /// existing value and writing back into [_fieldValues] on edit.
  TextEditingController _dynCtrl(String key) {
    return _dynControllers.putIfAbsent(key, () {
      final c = TextEditingController(text: _fieldValues[key] ?? '');
      c.addListener(() => _fieldValues[key] = c.text);
      return c;
    });
  }

  // ── Image picking ──────────────────────────────────────────────────────────

  int get _totalImages => _gallery.length;

  bool get _hasExistingImages => _gallery.any((e) => e.isExisting);

  /// Files picked this session, in gallery order — this is exactly the order
  /// they are uploaded in, which is what the `new:<i>` order tokens index into.
  List<XFile> get _pickedFiles => [
    for (final entry in _gallery)
      if (entry.file != null) entry.file!,
  ];

  Future<void> _recoverLostImages() async {
    if (!Platform.isAndroid ||
        _recoveringImages ||
        _loadingExisting ||
        _submitting) {
      return;
    }
    _recoveringImages = true;
    try {
      final response = await ImagePicker().retrieveLostData();
      if (!mounted || response.isEmpty) return;
      final recovered =
          response.files ??
          (response.file != null ? <XFile>[response.file!] : <XFile>[]);
      if (recovered.isNotEmpty) {
        await _addPickedImages(recovered);
      } else if (response.exception != null) {
        _toast('تعذّر استعادة الصور. يرجى اختيارها مرة أخرى.');
      }
    } on PlatformException {
      if (mounted) _toast('تعذّر استعادة الصور. يرجى اختيارها مرة أخرى.');
    } finally {
      _recoveringImages = false;
    }
  }

  Future<void> _pickImages({bool replaceExisting = false}) async {
    if (!replaceExisting && _totalImages >= _maxImages) {
      _toast('وصلت للحد الأقصى ($_maxImages صور). احذف صورة لإضافة غيرها.');
      return;
    }
    final List<XFile> picked;
    try {
      picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    } on PlatformException catch (e) {
      _toast(e.message ?? 'تعذّر فتح معرض الصور. تأكد من منح الإذن للتطبيق.');
      return;
    }
    if (picked.isEmpty || !mounted) return;
    await _addPickedImages(picked, replaceExisting: replaceExisting);
  }

  Future<void> _pickFromCamera() async {
    if (_totalImages >= _maxImages) {
      _toast('وصلت للحد الأقصى ($_maxImages صور). احذف صورة لإضافة غيرها.');
      return;
    }
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
    } on PlatformException catch (e) {
      _toast(e.message ?? 'تعذّر فتح الكاميرا. تأكد من منح الإذن للتطبيق.');
      return;
    }
    // The seller can leave the wizard while the camera is open, which used to
    // land a setState on a disposed State.
    if (picked == null || !mounted) return;
    await _addPickedImages([picked]);
  }

  /// The single door photos come in through — gallery, camera, or recovered
  /// after Android killed the app behind the system picker.
  Future<void> _addPickedImages(
    List<XFile> picked, {
    bool replaceExisting = false,
  }) async {
    final known = _pickedFiles.map((f) => f.path).toSet();
    final accepted = <XFile>[];
    var oversized = 0;
    for (final file in picked) {
      if (!replaceExisting && !known.add(file.path)) continue;
      // iOS photos are re-encoded by ImageUploadPreprocessor before upload, so
      // only Android originals need checking against the API's 5MB rule — far
      // kinder than a 422 after a long upload.
      if (!Platform.isIOS) {
        final int length;
        try {
          length = await file.length();
        } on FileSystemException {
          continue; // Picker handed back a path that no longer exists.
        }
        if (length > _maxImageBytes) {
          oversized++;
          continue;
        }
      }
      accepted.add(file);
    }
    if (!mounted) return;

    // image_picker hands back files in a cache directory both platforms may
    // purge. Copy them somewhere durable so a restored draft still has its
    // photos; retain() returns the original if the copy is not possible.
    if (!_isEditMode && accepted.isNotEmpty) {
      final retained = <XFile>[];
      for (final file in accepted) {
        retained.add(await _draftStore.retain(file));
      }
      if (!mounted) return;
      accepted
        ..clear()
        ..addAll(retained);
    }

    var dropped = 0;
    setState(() {
      if (replaceExisting) {
        _markRemoved(_gallery);
        _gallery.clear();
      }
      // Never negative: an ad already carrying more than the cap made take()
      // throw and killed the picker sheet.
      final remaining = (_maxImages - _gallery.length).clamp(0, _maxImages);
      dropped = accepted.length - remaining;
      _gallery.addAll(accepted.take(remaining).map(_GalleryEntry.picked));
      _touch();
    });

    if (oversized > 0) {
      _toast('تم تجاهل $oversized صورة لأن حجمها يتجاوز 5 ميغابايت.');
    } else if (dropped > 0) {
      _toast(
        'أُضيفت ${accepted.length - dropped} صور فقط — الحد الأقصى '
        '$_maxImages صور.',
      );
    }
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _gallery.length) return;
    setState(() {
      final removed = _gallery.removeAt(index);
      _markRemoved([removed]);
      _touch();
    });
  }

  /// Photos already stored on the ad have to be named to the API to be deleted;
  /// ones picked in this session just vanish from the list.
  void _markRemoved(Iterable<_GalleryEntry> entries) {
    for (final entry in entries) {
      final existing = entry.existing;
      if (existing != null) _removedImageIds.add(existing.id);
    }
  }

  void _reorderImage(int from, int to) {
    if (from == to || from < 0 || from >= _gallery.length) return;
    setState(() {
      final entry = _gallery.removeAt(from);
      _gallery.insert(to.clamp(0, _gallery.length), entry);
      _touch();
    });
  }

  /// Everything the API would reject, checked before a long upload starts, so
  /// the seller lands on the step that needs fixing instead of reading a 422
  /// after watching a progress bar fill.
  ({int step, String message})? _firstBlockingGap() {
    if (!_pledgeAccepted) {
      return (step: 0, message: 'يجب الموافقة على تعهّد المعلن أولاً.');
    }
    if (_selectedCategory == null) {
      return (step: 1, message: 'اختر تصنيف الإعلان.');
    }
    if (_titleCtrl.text.trim().length < kTitleMinLen) {
      return (
        step: 2,
        message: 'العنوان يجب أن يكون $kTitleMinLen أحرف على الأقل.',
      );
    }
    if (_descCtrl.text.trim().length < kDescMinLen) {
      return (
        step: 2,
        message: 'الوصف يجب أن يكون $kDescMinLen أحرف على الأقل.',
      );
    }
    if (_priceOption != _PriceOption.callForPrice &&
        _priceCtrl.text.trim().isEmpty) {
      return (step: 2, message: 'أدخل السعر أو اختر "عند الاتصال".');
    }
    if (_showPhonePublicly && !isValidSaudiPhone(_phoneCtrl.text)) {
      return (step: 2, message: 'أدخل رقم جوال سعودي صحيح (05xxxxxxxx).');
    }
    if (_totalImages == 0) {
      return (step: 3, message: 'أضف صورة واحدة على الأقل.');
    }
    if (_selectedCity == null) {
      return (step: 4, message: 'اختر المدينة.');
    }
    return null;
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    final gap = _firstBlockingGap();
    if (gap != null) {
      _goToStep(gap.step);
      _toast(gap.message);
      return;
    }
    await _submit();
  }

  void _onUploadProgress(int sent, int total) {
    if (!mounted || total <= 0) return;

    final percent = ((sent / total) * 100).clamp(0, 100).round();
    if (_uploadPercent == percent) return;

    setState(() {
      _uploadPercent = percent;
      _submitStatus = percent >= 100
          ? (_isEditMode
                ? 'جارٍ حفظ التعديلات...'
                : 'جارٍ إكمال نشر الإعلان...')
          : 'جارٍ رفع الصور... $percent%';
    });
  }

  Future<void> _showSubmitError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ErrorDialog(message: message, errors: const {}),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting || !_pledgeAccepted || _selectedCity == null) return;
    final preparedTempPaths = <String>[];
    setState(() {
      _submitting = true;
      _submitStatus = 'جارٍ تجهيز الصور...';
      _uploadPercent = null;
      _fieldErrors = {};
    });
    try {
      final imagesData = <MultipartFile>[];
      final pickedFiles = _pickedFiles;
      // Process one photo at a time. Decoding several high-resolution iPhone
      // photos concurrently can cause a large memory spike and make the wizard
      // appear frozen before the network request even starts.
      for (var index = 0; index < pickedFiles.length; index++) {
        if (mounted) {
          setState(() {
            _submitStatus =
                'جارٍ تجهيز الصورة ${index + 1} من ${pickedFiles.length}...';
          });
        }

        final source = pickedFiles[index];
        final prepared = await ImageUploadPreprocessor.prepare(
          source,
        ).timeout(const Duration(seconds: 30));
        if (prepared.path != source.path) {
          preparedTempPaths.add(prepared.path);
        }
        imagesData.add(
          await MultipartFile.fromFile(
            prepared.path,
            filename: File(prepared.path).uri.pathSegments.last,
          ),
        );
      }

      final regionId = _selectedCity?.region?.id ?? _selectedRegion?.id;
      final districtId = _selectedDistrict?.id.toString() ?? '';
      final districtFree = _selectedDistrict == null
          ? _districtFreeTextCtrl.text.trim()
          : '';

      final formFields = <String, dynamic>{
        'seller_type': _sellerType,
        'city_id': _selectedCity!.id.toString(),
        if (regionId != null) 'region_id': regionId.toString(),
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        // Both "أدخل السعر" and "على السوم" send a price; "عند الاتصال" hides it.
        if (_priceOption != _PriceOption.callForPrice &&
            _priceCtrl.text.trim().isNotEmpty)
          'price': _priceCtrl.text.trim(),
        'is_free': '0',
        'is_negotiable': (_priceOption == _PriceOption.negotiable) ? '1' : '0',
        'price_hidden': (_priceOption == _PriceOption.callForPrice) ? '1' : '0',
        'show_phone_publicly': _showPhonePublicly ? '1' : '0',
        'contact_phone': _phoneCtrl.text.trim(),
        // Editing has to send both keys even when empty. Omitting them left
        // the previously saved district on the record, so clearing it — or
        // moving the ad to another city — silently kept the old one, and the
        // ad ended up with a district belonging to a different city.
        if (_isEditMode || districtId.isNotEmpty) 'district_id': districtId,
        if (_isEditMode || districtFree.isNotEmpty)
          'district_name_free': districtFree,
        'pledge_accepted': '1',
        if (_latitude != null) 'latitude': _latitude.toString(),
        if (_longitude != null) 'longitude': _longitude.toString(),
        ..._fieldValues.map((k, v) => MapEntry('fields[$k]', v)),
      };

      formFields['category_id'] = _selectedCategory!.id.toString();

      if (_isEditMode) {
        // The gallery as the seller arranged it. Existing photos go by id and
        // ones added in this edit by their position in images[], so either can
        // be the cover. Only meaningful on edit — a new ad's images are already
        // stored in upload order.
        var uploadIndex = 0;
        formFields['image_order[]'] = [
          for (final entry in _gallery)
            entry.existing?.id.toString() ?? 'new:${uploadIndex++}',
        ];
      }

      final formData = FormData.fromMap({
        ...formFields,
        if (imagesData.isNotEmpty) 'images[]': imagesData,
        if (_removedImageIds.isNotEmpty)
          'remove_image_ids[]': _removedImageIds
              .map((id) => id.toString())
              .toList(),
      });

      if (mounted) {
        setState(() => _submitStatus = 'جارٍ رفع الصور... 0%');
      }

      final AdDetailModel ad;
      if (_isEditMode) {
        ad = await ref
            .read(adRepositoryProvider)
            .updateAd(
              widget.adId!,
              formData,
              onSendProgress: _onUploadProgress,
            );
      } else {
        ad = await ref
            .read(adRepositoryProvider)
            .createAd(formData, onSendProgress: _onUploadProgress);
        unawaited(
          ref
              .read(marketingTrackingProvider)
              .track(
                MarketingEvent.publishAd,
                properties: {
                  'content_id': ad.id.toString(),
                  'content_name': ad.title,
                  if (ad.category != null)
                    'content_category': ad.category!.nameAr,
                  'content_type': 'product',
                  'event_tag': 'publish_ad',
                  if (ad.price != null) 'value': ad.price,
                  if (ad.price != null) 'currency': 'SAR',
                },
              ),
        );
      }

      if (mounted) {
        ref.invalidate(adsFeedProvider);
        ref.invalidate(myAdsProvider);
        // adDetailProvider is a plain (non-autoDispose) family, so the ad page
        // we are about to open would otherwise rebuild from the copy cached
        // before the edit and show the seller their old values back.
        ref.invalidate(adDetailProvider(ad.id));

        // Resolved before navigating: this screen's context is defunct the
        // moment go() replaces the route.
        final messenger = ScaffoldMessenger.of(context);
        // The draft is committed — leaving now must not prompt to discard it,
        // and the parked copy must not resurface on the next new ad.
        _dirty = false;
        unawaited(_discardDraft());
        context.go('/ads/${ad.id}');
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  _isEditMode ? 'تم حفظ التعديلات!' : 'تم نشر الإعلان بنجاح!',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: AppTheme.primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on TimeoutException {
      await _showSubmitError(
        'تعذّر تجهيز إحدى الصور في الوقت المتوقع. أزل الصورة وحاول إضافتها مرة أخرى.',
      );
    } on PlatformException catch (e) {
      await _showSubmitError(
        e.message ?? 'تعذّر تجهيز إحدى الصور للرفع. حاول اختيارها مرة أخرى.',
      );
    } on ApiException catch (e) {
      final errors = (e.errors ?? {}).map(
        (k, v) => MapEntry(k, (v as List).first as String),
      );
      setState(() => _fieldErrors = errors);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _ErrorDialog(message: e.message, errors: errors),
      );
      if (!mounted) return;
      if (errors.containsKey('category_id')) {
        _jumpToStep(1); // التصنيف step
      } else if (errors.isNotEmpty) {
        _jumpToStep(2); // التفاصيل step
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ غير متوقع: ${e.toString()}',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      for (final path in preparedTempPaths) {
        try {
          await File(path).delete();
        } on FileSystemException {
          // Temporary upload files are best-effort cleanup only.
        }
      }
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitStatus = null;
          _uploadPercent = null;
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The wizard owns the back gesture. Android's back button and the iOS
      // edge swipe used to pop the whole route from step 4, throwing away a
      // fully written ad without so much as a prompt.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleBackIntent());
      },
      child: _buildWizard(),
    );
  }

  Widget _buildWizard() {
    if (_loadingExisting) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _appBar(),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppTheme.primaryBlue,
                strokeWidth: 2.5,
              ),
              SizedBox(height: 16),
              Text(
                'جارٍ تحميل الإعلان...',
                style: TextStyle(color: AppTheme.neutralGray500),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _appBar(),
      body: Column(
        children: [
          _StepIndicator(current: _step),
          const Divider(height: 1, color: AppTheme.neutralGray200),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children:
                  [
                        // ── Step 0: Pledge (القسم) ─────────────────────────────────
                        _Step0Pledge(
                          pledgeAccepted: _pledgeAccepted,
                          onPledgeChanged: (v) => setState(() {
                            _pledgeAccepted = v;
                            _touch();
                          }),
                          onNext: _pledgeAccepted ? _next : () {},
                        ),
                        // ── Step 1: Category ───────────────────────────────────────
                        _Step1Category(
                          selected: _selectedCategory,
                          isLocked: false,
                          browsing: _browsingCategory,
                          onBrowse: (cat) =>
                              setState(() => _browsingCategory = cat),
                          onSelect: (cat) {
                            _selectCategory(cat);
                            _next();
                          },
                          onNextLocked: null,
                        ),
                        // ── Step 2: Details ────────────────────────────────────────
                        _Step2Details(
                          titleCtrl: _titleCtrl,
                          descCtrl: _descCtrl,
                          priceCtrl: _priceCtrl,
                          phoneCtrl: _phoneCtrl,
                          priceOption: _priceOption,
                          showPhonePublicly: _showPhonePublicly,
                          categoryId: _selectedCategory?.id,
                          fieldValues: _fieldValues,
                          errors: _fieldErrors,
                          onPriceOptionChanged: (v) => setState(() {
                            _priceOption = v;
                            _touch();
                          }),
                          onShowPhoneChanged: (v) => setState(() {
                            _showPhonePublicly = v;
                            _touch();
                          }),
                          onFieldChanged: (k, v) => setState(() {
                            _fieldValues[k] = v;
                            _touch();
                          }),
                          dynCtrl: _dynCtrl,
                          onBack: _prev,
                          onNext: () {
                            if (_step2Valid) _next();
                          },
                        ),
                        // ── Step 3: Images ─────────────────────────────────────────
                        _Step3Images(
                          isEditMode: _isEditMode,
                          gallery: _gallery,
                          onPickGallery: () => _pickImages(),
                          onReplaceGallery: _isEditMode && _hasExistingImages
                              ? () => _pickImages(replaceExisting: true)
                              : null,
                          onPickCamera: _pickFromCamera,
                          onRemove: _removeImageAt,
                          onReorder: _reorderImage,
                          onBack: _prev,
                          onNext: _next,
                        ),
                        // ── Step 4: Location + Submit ──────────────────────────────
                        _Step4LocationSubmit(
                          selectedRegion: _selectedRegion,
                          selectedCity: _selectedCity,
                          selectedDistrict: _selectedDistrict,
                          districtsForCity: _districtsForCity,
                          loadingDistricts: _loadingDistricts,
                          districtFreeTextCtrl: _districtFreeTextCtrl,
                          latitude: _latitude,
                          longitude: _longitude,
                          submitting: _submitting,
                          submitStatus: _submitStatus,
                          isEditMode: _isEditMode,
                          priceText: _priceCtrl.text.trim(),
                          categoryId: _selectedCategory?.id,
                          sellerType: _sellerType,
                          onSelectLocation: (r, c) {
                            final cityChanged = _selectedCity?.id != c?.id;
                            setState(() {
                              _selectedRegion =
                                  r ?? c?.region ?? _selectedRegion;
                              _selectedCity = c;
                              _touch();
                              // Only an actual change resets the rest: re-picking the
                              // same city used to silently drop the district and map
                              // pin the seller had already chosen.
                              if (cityChanged) {
                                _selectedDistrict = null;
                                _districtFreeTextCtrl.clear();
                                // A pin chosen for another city must never override the
                                // newly selected city's map centre.
                                _latitude = null;
                                _longitude = null;
                              }
                            });
                            if (c != null && cityChanged) _loadDistricts(c.id);
                          },
                          onPickDistrict: _showDistrictPicker,
                          onClearDistrict: () => setState(() {
                            _selectedDistrict = null;
                            _touch();
                          }),
                          onPickMapLocation: () async {
                            final city = _selectedCity;
                            if (city == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'اختر المدينة أولاً لعرض خريطتها',
                                  ),
                                ),
                              );
                              return;
                            }

                            final picked = await Navigator.push<LatLng>(
                              context,
                              MaterialPageRoute(
                                fullscreenDialog: true,
                                builder: (_) => MapLocationPicker(
                                  initialLocation:
                                      (_latitude != null && _longitude != null)
                                      ? LatLng(_latitude!, _longitude!)
                                      : null,
                                  initialCenter:
                                      (city.latitude != null &&
                                          city.longitude != null)
                                      ? LatLng(city.latitude!, city.longitude!)
                                      : null,
                                  cityName: city.nameAr,
                                ),
                              ),
                            );
                            if (picked != null && mounted) {
                              setState(() {
                                _latitude = picked.latitude;
                                _longitude = picked.longitude;
                                _touch();
                              });
                            }
                          },
                          onBack: _prev,
                          onSubmit: _handleSubmit,
                        ),
                      ]
                      // PageView keeps no cache extent, so every step off-screen was
                      // torn down and rebuilt from scratch — losing scroll position,
                      // the sub-category the seller had drilled into, and the state of
                      // the spec dropdowns. Going back now returns to what they left.
                      .map<Widget>((page) => _KeepAlivePage(child: page))
                      .toList(),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _appBar() => AppBar(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    foregroundColor: AppTheme.neutralGray900,
    title: Text(
      _isEditMode ? 'تعديل الإعلان' : 'نشر إعلان',
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
    ),
    leading: IconButton(
      icon: const Icon(Icons.close_rounded),
      onPressed: () => unawaited(_closeWizard()),
    ),
  );
}

/// Holds a wizard step in the tree while the seller is looking at another one.
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});
  static const _labels = ['القسم', 'التصنيف', 'التفاصيل', 'الصور', 'الموقع'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isDone = i < current;
          final isActive = i == current;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppTheme.primaryBlue
                              : isActive
                              ? AppTheme.primaryBlue.withValues(alpha: .12)
                              : AppTheme.neutralGray100,
                          border: Border.all(
                            color: isActive || isDone
                                ? AppTheme.primaryBlue
                                : AppTheme.neutralGray200,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isActive
                                        ? AppTheme.primaryBlue
                                        : AppTheme.neutralGray500,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive || isDone
                              ? AppTheme.primaryBlue
                              : AppTheme.neutralGray500,
                          fontWeight: isActive || isDone
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < _labels.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      height: 2,
                      width: 20,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppTheme.primaryBlue
                            : AppTheme.neutralGray200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Shared color palette for category lists ───────────────────────────────────

const _kCategoryColors = [
  Color(0xFF6C63FF),
  Color(0xFF00B4D8),
  Color(0xFFFF6B6B),
  Color(0xFF2EC4B6),
  Color(0xFFFF9F1C),
  Color(0xFF8338EC),
  Color(0xFF06D6A0),
  Color(0xFFEF476F),
  Color(0xFF118AB2),
  Color(0xFFFFD166),
  Color(0xFF073B4C),
  Color(0xFFE63946),
];

// ── Step 0: Pledge (القسم) ────────────────────────────────────────────────────

class _Step0Pledge extends StatelessWidget {
  final bool pledgeAccepted;
  final void Function(bool) onPledgeChanged;
  final VoidCallback onNext;

  const _Step0Pledge({
    required this.pledgeAccepted,
    required this.onPledgeChanged,
    required this.onNext,
  });

  static const _quranVerse =
      '﴿وَأَوْفُوا بِالْعَهْدِ ۖ إِنَّ الْعَهْدَ كَانَ مَسْئُولًا﴾';

  static const _pledgeBody =
      'بسم الله الرحمن الرحيم.\n\n'
      'أتعهد وأقسم بالله العظيم أنا المعلن المسجّل في موقع برق واضح ما يلي:\n\n'
      '١. أن جميع المعلومات والصور المنشورة في إعلاني صحيحة ودقيقة، وتعبّر عن السلعة أو الخدمة كما هي بدون غش أو تدليس.\n\n'
      '٢. أن أدفع للموقع عمولة البيع الثابتة المحددة حسب القسم المختار (شاملة ضريبة القيمة المضافة) بعد إتمام عملية البيع، خلال مدة لا تتجاوز 10 أيام من استلامي لكامل مبلغ المبايعة من المشتري.\n\n'
      '٣. أن نشر الإعلان مجاني، وأن العمولة لا تُستحق إلا بعد إتمام البيع فعلياً.\n\n'
      '٤. أن أتحمل كامل المسؤولية القانونية والشرعية عن صحة الإعلان ومحتواه، وأن للموقع الحق في حذفه أو إيقاف حسابي عند مخالفة الشروط.\n\n'
      '٥. ألتزم بعدم نشر إعلانات تحتوي على ما يخالف الأنظمة المعمول بها في المملكة العربية السعودية.\n\n'
      'والله على ما أقول شهيد.';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: .05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: .2),
              ),
            ),
            child: const Column(
              children: [
                Text('🤝', style: TextStyle(fontSize: 40)),
                SizedBox(height: 10),
                Text(
                  'تعهّد المعلن',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.neutralGray900,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                SizedBox(height: 4),
                Text(
                  'اقرأ الميثاق ثم وافق للمتابعة',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.neutralGray500,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quranic verse
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Text(
              _quranVerse,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.teal.shade800,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Pledge body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.neutralGray50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.neutralGray200),
            ),
            child: const Text(
              _pledgeBody,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 13,
                height: 1.9,
                color: AppTheme.neutralGray800,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Agreement checkbox
          GestureDetector(
            onTap: () => onPledgeChanged(!pledgeAccepted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pledgeAccepted
                    ? AppTheme.primaryBlue.withValues(alpha: .06)
                    : AppTheme.neutralGray50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: pledgeAccepted
                      ? AppTheme.primaryBlue
                      : AppTheme.neutralGray200,
                  width: pledgeAccepted ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'أوافق على هذا التعهّد وأقسم بالله أن المعلومات المنشورة صحيحة، وأن أدفع الرسوم المستحقة وفق الشروط أعلاه.',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: pledgeAccepted
                            ? AppTheme.primaryBlue
                            : AppTheme.neutralGray700,
                        fontWeight: pledgeAccepted
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: pledgeAccepted
                          ? AppTheme.primaryBlue
                          : Colors.white,
                      border: Border.all(
                        color: pledgeAccepted
                            ? AppTheme.primaryBlue
                            : AppTheme.neutralGray300,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: pledgeAccepted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: _PrimaryButton(
              label: 'أوافق وأتابع',
              icon: Icons.arrow_forward_ios_rounded,
              onPressed: pledgeAccepted ? onNext : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Category ──────────────────────────────────────────────────────────

class _Step1Category extends ConsumerStatefulWidget {
  final CategoryModel? selected;
  final bool isLocked;

  /// The parent being drilled into. Owned by the wizard so that leaving the
  /// step and coming back returns to the same sub-list, and so the system back
  /// gesture can step out of the sub-list before it steps out of the wizard.
  final CategoryModel? browsing;
  final void Function(CategoryModel?) onBrowse;
  final void Function(CategoryModel) onSelect;
  final VoidCallback? onNextLocked;

  const _Step1Category({
    required this.selected,
    required this.isLocked,
    required this.browsing,
    required this.onBrowse,
    required this.onSelect,
    this.onNextLocked,
  });

  @override
  ConsumerState<_Step1Category> createState() => _Step1CategoryState();
}

class _Step1CategoryState extends ConsumerState<_Step1Category> {
  @override
  Widget build(BuildContext context) {
    if (widget.isLocked) return _buildLocked();

    final catsAsync = ref.watch(categoriesProvider);
    return catsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryBlue,
          strokeWidth: 2.5,
        ),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text('فشل تحميل الأقسام', textDirection: TextDirection.rtl),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.refresh(categoriesProvider),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
      data: (cats) {
        final browsing = widget.browsing;
        // The seller may have drilled into a category before a refresh
        // reshuffled the list; fall back to the top level rather than showing
        // a stale branch.
        if (browsing != null && cats.any((c) => c.id == browsing.id)) {
          return _buildSubList(cats.firstWhere((c) => c.id == browsing.id));
        }
        return _buildParentList(cats);
      },
    );
  }

  Widget _buildLocked() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              size: 36,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'تصنيف الإعلان',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.neutralGray900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'لا يمكن تغيير التصنيف عند تعديل الإعلان',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.neutralGray500, fontSize: 13),
          ),
          const SizedBox(height: 32),
          if (widget.selected != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 10),
                  Text(
                    widget.selected!.nameAr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primaryBlue,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'التصنيف مقفل أثناء التعديل',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          SizedBox(
            width: double.infinity,
            child: _PrimaryButton(
              label: 'المتابعة للتفاصيل',
              icon: Icons.arrow_forward_ios_rounded,
              onPressed: widget.onNextLocked,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentList(List<CategoryModel> cats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'اختر القسم',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.neutralGray600,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(width: 8),
              // Real-estate listings are suspended. Say so where the seller
              // picks a category, not after they have filled in the form.
              const Expanded(
                child: Text(
                  'لا نقبل أي عروض عقارية حالياً',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.colorError,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.neutralGray100),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppTheme.neutralGray100,
            ),
            itemBuilder: (_, i) {
              final cat = cats[i];
              final color = _kCategoryColors[i % _kCategoryColors.length];
              final isSelected = widget.selected?.id == cat.id;
              return InkWell(
                onTap: () {
                  if (cat.children.isNotEmpty) {
                    widget.onBrowse(cat);
                  } else {
                    widget.onSelect(cat);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  color: isSelected
                      ? AppTheme.primaryBlue.withValues(alpha: .05)
                      : null,
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          cat.nameAr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.neutralGray900,
                          ),
                        ),
                      ),
                      if (cat.children.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${cat.children.length}',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_back_ios,
                          size: 12,
                          color: AppTheme.neutralGray400,
                        ),
                      ] else
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.neutralGray300,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubList(CategoryModel parent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back header
        InkWell(
          onTap: () => widget.onBrowse(null),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.neutralGray100),
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.neutralGray100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppTheme.neutralGray600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'اختر القسم الفرعي',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.neutralGray500,
                        ),
                      ),
                      Text(
                        parent.nameAr,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.neutralGray900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: parent.children.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: AppTheme.neutralGray100,
            ),
            itemBuilder: (_, i) {
              final sub = parent.children[i];
              final color = _kCategoryColors[i % _kCategoryColors.length];
              final isSelected = widget.selected?.id == sub.id;
              return InkWell(
                onTap: () => widget.onSelect(sub),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  color: isSelected
                      ? AppTheme.primaryBlue.withValues(alpha: .05)
                      : null,
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          sub.nameAr,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.neutralGray900,
                          ),
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 18,
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : AppTheme.neutralGray300,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Step 2: Details ───────────────────────────────────────────────────────────

class _Step2Details extends ConsumerStatefulWidget {
  final TextEditingController titleCtrl, descCtrl, priceCtrl, phoneCtrl;
  final _PriceOption priceOption;
  final bool showPhonePublicly;
  final int? categoryId;
  final Map<String, String> fieldValues;
  final Map<String, String> errors;
  final void Function(_PriceOption) onPriceOptionChanged;
  final void Function(bool) onShowPhoneChanged;
  final void Function(String, String) onFieldChanged;
  final TextEditingController Function(String) dynCtrl;
  final VoidCallback onBack, onNext;

  const _Step2Details({
    required this.titleCtrl,
    required this.descCtrl,
    required this.priceCtrl,
    required this.phoneCtrl,
    required this.priceOption,
    required this.showPhonePublicly,
    required this.categoryId,
    required this.fieldValues,
    required this.errors,
    required this.onPriceOptionChanged,
    required this.onShowPhoneChanged,
    required this.onFieldChanged,
    required this.dynCtrl,
    required this.onBack,
    required this.onNext,
  });

  @override
  ConsumerState<_Step2Details> createState() => _Step2DetailsState();
}

class _Step2DetailsState extends ConsumerState<_Step2Details> {
  @override
  Widget build(BuildContext context) {
    // Compute validity here (not via a parent prop) so the Next button updates
    // live as the user types — text changes only rebuild this child widget.
    final titleText = widget.titleCtrl.text.trim();
    final descText = widget.descCtrl.text.trim();
    final phoneText = widget.phoneCtrl.text.trim();
    final phoneValid =
        !widget.showPhonePublicly || isValidSaudiPhone(phoneText);

    // Dynamic category fields (e.g. the cars fields). Required ones must be
    // filled before leaving the step.
    final categoryFieldsState = widget.categoryId != null
        ? ref.watch(categoryFieldsProvider(widget.categoryId!))
        : null;
    final categoryFields = categoryFieldsState?.asData?.value ?? const [];
    // Until the specs actually arrive there is nothing to check, and an empty
    // list read as "no required fields" — so a seller on a slow connection
    // could walk straight past the required car fields and only find out when
    // the API rejected the finished ad.
    final categoryFieldsReady =
        categoryFieldsState == null || categoryFieldsState.hasValue;
    final categoryFieldsFailed =
        categoryFieldsState != null && categoryFieldsState.hasError;
    final requiredFieldsFilled = categoryFields
        .where((f) => f.isRequired)
        .every((f) => (widget.fieldValues[f.fieldKey] ?? '').trim().isNotEmpty);

    // Inline per-field errors shown before the user can leave this step.
    final titleError = titleText.isNotEmpty && titleText.length < kTitleMinLen
        ? 'العنوان يجب أن يكون $kTitleMinLen أحرف على الأقل'
        : widget.errors['title'];
    final descError = descText.isNotEmpty && descText.length < kDescMinLen
        ? 'الوصف يجب أن يكون $kDescMinLen أحرف على الأقل'
        : widget.errors['description'];

    final isValid =
        titleText.length >= kTitleMinLen &&
        descText.length >= kDescMinLen &&
        phoneValid &&
        categoryFieldsReady &&
        requiredFieldsFilled &&
        (widget.priceOption == _PriceOption.callForPrice ||
            widget.priceCtrl.text.trim().isNotEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Basic info ───────────────────────────────────────────────────
          _SectionHeader(
            title: 'معلومات الإعلان',
            icon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: 12),

          _FormField(
            label: 'عنوان الإعلان',
            required: true,
            child: TextField(
              controller: widget.titleCtrl,
              textDirection: TextDirection.rtl,
              maxLength: kTitleMaxLen,
              inputFormatters: [LengthLimitingTextInputFormatter(kTitleMaxLen)],
              style: const TextStyle(color: AppTheme.neutralGray900),
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                hint: 'مثال: عنوان واضح ومختصر يصف الإعلان',
                error: titleError,
              ),
            ),
          ),

          _FormField(
            label: 'الوصف',
            required: true,
            child: TextField(
              controller: widget.descCtrl,
              textDirection: TextDirection.rtl,
              maxLines: 5,
              maxLength: kDescMaxLen,
              inputFormatters: [LengthLimitingTextInputFormatter(kDescMaxLen)],
              style: const TextStyle(color: AppTheme.neutralGray900),
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                hint:
                    'صف السلعة بتفاصيل كافية — الحالة، المواصفات، سبب البيع... (10 أحرف على الأقل)',
                error: descError,
              ),
            ),
          ),

          // ── Dynamic category fields (e.g. cars: النوع/الموديل/الممشى/اللون) ──
          if (categoryFieldsState != null && categoryFieldsState.isLoading) ...[
            _SectionHeader(title: 'المواصفات', icon: Icons.tune_rounded),
            const SizedBox(height: 12),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
          ] else if (categoryFieldsFailed) ...[
            _SectionHeader(title: 'المواصفات', icon: Icons.tune_rounded),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'تعذّر تحميل مواصفات هذا القسم.',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      categoryFieldsProvider(widget.categoryId!),
                    ),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ],
          if (categoryFields.isNotEmpty) ...[
            _SectionHeader(title: 'المواصفات', icon: Icons.tune_rounded),
            const SizedBox(height: 12),
            ...categoryFields.map((f) {
              final value = (widget.fieldValues[f.fieldKey] ?? '').trim();
              final missing = f.isRequired && value.isEmpty;
              if (f.options.isNotEmpty) {
                // A saved value that is no longer one of the options (the admin
                // renamed it, or it came from a category the seller has since
                // switched away from) used to trip DropdownButton's
                // "exactly one item" assertion. Keep it selectable instead of
                // dropping the seller's spec on the floor.
                final saved = widget.fieldValues[f.fieldKey];
                final isStale =
                    saved != null &&
                    saved.isNotEmpty &&
                    !f.options.contains(saved);
                return _FormField(
                  label: f.labelAr,
                  required: f.isRequired,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('${f.fieldKey}:${f.options.length}'),
                    initialValue: (saved != null && saved.isEmpty)
                        ? null
                        : saved,
                    hint: Text(
                      f.placeholderAr ?? 'اختر...',
                      style: const TextStyle(color: AppTheme.neutralGray500),
                    ),
                    decoration: _inputDecoration(
                      error: missing ? 'هذا الحقل مطلوب' : null,
                    ),
                    items: [
                      if (isStale)
                        DropdownMenuItem(
                          value: saved,
                          child: Text(saved, textDirection: TextDirection.rtl),
                        ),
                      ...f.options.map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(o, textDirection: TextDirection.rtl),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) widget.onFieldChanged(f.fieldKey, v);
                    },
                  ),
                );
              }
              return _FormField(
                label: f.labelAr,
                required: f.isRequired,
                child: TextField(
                  controller: widget.dynCtrl(f.fieldKey),
                  textDirection: TextDirection.rtl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppTheme.neutralGray900),
                  decoration: _inputDecoration(
                    hint: f.placeholderAr ?? '',
                    error: missing ? 'هذا الحقل مطلوب' : null,
                  ),
                ),
              );
            }),
          ],

          // ── Price ────────────────────────────────────────────────────────
          _SectionHeader(title: 'السعر', icon: Icons.payments_outlined),
          const SizedBox(height: 12),

          Row(
            children: [
              _PriceOptionChip(
                label: 'أدخل السعر',
                icon: Icons.payments_outlined,
                selected: widget.priceOption == _PriceOption.fixed,
                onTap: () {
                  widget.onPriceOptionChanged(_PriceOption.fixed);
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              _PriceOptionChip(
                label: 'على السوم',
                icon: Icons.handshake_outlined,
                selected: widget.priceOption == _PriceOption.negotiable,
                onTap: () {
                  widget.onPriceOptionChanged(_PriceOption.negotiable);
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              _PriceOptionChip(
                label: 'عند الاتصال',
                icon: Icons.phone_outlined,
                selected: widget.priceOption == _PriceOption.callForPrice,
                onTap: () {
                  widget.onPriceOptionChanged(_PriceOption.callForPrice);
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Both "أدخل السعر" and "على السوم" require a price; only "عند الاتصال" hides it.
          if (widget.priceOption != _PriceOption.callForPrice) ...[
            _FormField(
              label: widget.priceOption == _PriceOption.negotiable
                  ? 'السعر المطلوب (على السوم)'
                  : 'السعر',
              required: true,
              child: TextField(
                controller: widget.priceCtrl,
                textDirection: TextDirection.rtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  color: AppTheme.neutralGray900,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                decoration: _inputDecoration(
                  hint: '0',
                  error: widget.errors['price'],
                  prefix: const Padding(
                    padding: EdgeInsetsDirectional.only(end: 8),
                    child: RiyalIcon(size: 16, color: AppTheme.primaryBlue),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // ── Contact ──────────────────────────────────────────────────────
          _SectionHeader(title: 'معلومات التواصل', icon: Icons.phone_outlined),
          const SizedBox(height: 12),

          _ToggleRow(
            label: 'إظهار رقم الجوال للعموم',
            value: widget.showPhonePublicly,
            onChanged: (v) {
              widget.onShowPhoneChanged(v);
              setState(() {});
            },
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'رقم الجوال اختياري. اتركه فارغاً وسيتواصل معك المشترون عبر المحادثة داخل التطبيق.',
              style: TextStyle(fontSize: 12, color: AppTheme.neutralGray700),
            ),
          ),
          const SizedBox(height: 8),

          _FormField(
            label: widget.showPhonePublicly
                ? 'رقم التواصل'
                : 'رقم التواصل (اختياري)',
            required: widget.showPhonePublicly,
            child: TextField(
              controller: widget.phoneCtrl,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppTheme.neutralGray900),
              decoration: _inputDecoration(
                hint: '05xxxxxxxx',
                error: phoneText.isNotEmpty && !isValidSaudiPhone(phoneText)
                    ? 'أدخل رقم جوال سعودي صحيح (05xxxxxxxx)'
                    : widget.errors['contact_phone'],
                prefix: const Text('🇸🇦  ', style: TextStyle(fontSize: 13)),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _NavRow(
            onBack: widget.onBack,
            onNext: isValid ? widget.onNext : null,
            nextLabel: 'التالي: الصور',
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Images ────────────────────────────────────────────────────────────

/// One tile in the ad's photo gallery: either an image already stored on the
/// ad (addressed by its server id) or a file picked during this session (sent
/// as an upload and addressed by its position among the uploads).
class _GalleryEntry {
  final AdImageModel? existing;
  final XFile? file;

  const _GalleryEntry.existing(AdImageModel this.existing) : file = null;
  const _GalleryEntry.picked(XFile this.file) : existing = null;

  bool get isExisting => existing != null;
}

class _Step3Images extends StatelessWidget {
  final bool isEditMode;
  final List<_GalleryEntry> gallery;
  final VoidCallback onPickGallery, onPickCamera;
  final VoidCallback? onReplaceGallery;
  final void Function(int) onRemove;
  final void Function(int from, int to) onReorder;
  final VoidCallback onBack, onNext;

  const _Step3Images({
    required this.isEditMode,
    required this.gallery,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onReplaceGallery,
    required this.onRemove,
    required this.onReorder,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final totalImages = gallery.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: AppTheme.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'صور الإعلان',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isEditMode
                          ? 'أضف أو احذف الصور، ورتّبها بالسحب — الأولى هي الرئيسية'
                          : 'أضف حتى 10 صور • رتّبها بالسحب، والأولى هي الرئيسية',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutralGray500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalImages/10 صور',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray600,
                ),
              ),
              if (totalImages > 0)
                Text(
                  'اضغط مطولاً للترتيب • ★ للرئيسية',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutralGray500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: totalImages + (totalImages < 10 ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == totalImages) {
                  return _AddImageTile(
                    onPickGallery: onPickGallery,
                    onPickCamera: onPickCamera,
                    onReplaceGallery: onReplaceGallery,
                    isEditMode: isEditMode,
                  );
                }

                return _DraggableImageSlot(
                  index: i,
                  onReorder: onReorder,
                  child: _tileAt(i),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _NavRow(
            onBack: onBack,
            onNext: totalImages > 0 ? onNext : null,
            nextLabel: 'التالي: الموقع',
          ),
        ],
      ),
    );
  }

  Widget _tileAt(int index) {
    final entry = gallery[index];
    final isPrimary = index == 0;
    // Position 0 is the cover, so "make cover" is just a move to the front.
    final onMakeCover = isPrimary ? null : () => onReorder(index, 0);
    final existing = entry.existing;

    if (existing != null) {
      return _ExistingImageTile(
        image: existing,
        isPrimary: isPrimary,
        onRemove: () => onRemove(index),
        onMakeCover: onMakeCover,
      );
    }

    return _ImageTile(
      file: entry.file!,
      isPrimary: isPrimary,
      onRemove: () => onRemove(index),
      onMakeCover: onMakeCover,
    );
  }
}

/// Long-press a photo to drag it onto another slot. The grid's first photo is
/// the ad's cover, so dragging one to the front is how the cover is changed.
class _DraggableImageSlot extends StatelessWidget {
  final int index;
  final void Function(int from, int to) onReorder;
  final Widget child;

  const _DraggableImageSlot({
    required this.index,
    required this.onReorder,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => onReorder(details.data, index),
      builder: (context, candidate, _) {
        return LongPressDraggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: .9,
              child: SizedBox(width: 104, height: 104, child: child),
            ),
          ),
          childWhenDragging: Opacity(opacity: .25, child: child),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: candidate.isEmpty
                  ? null
                  : Border.all(color: AppTheme.primaryBlue, width: 2.5),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// One line of the fees card: what the sale costs, and for whom. A null amount
/// renders as مجاني rather than "0 ر.س".
class _CommissionRow extends StatelessWidget {
  final String label;
  final double? amount;

  const _CommissionRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.neutralGray700,
            ),
          ),
        ),
        RiyalText(
          amount != null ? '${amount!.toStringAsFixed(0)} ر.س' : 'مجاني',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }
}

/// One-tap alternative to dragging a photo all the way to the front.
class _MakeCoverButton extends StatelessWidget {
  final VoidCallback onTap;

  const _MakeCoverButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.star_rounded, size: 16, color: Colors.white),
      ),
    );
  }
}

class _ExistingImageTile extends StatelessWidget {
  final AdImageModel image;
  final bool isPrimary;
  final VoidCallback onRemove;
  final VoidCallback? onMakeCover;

  const _ExistingImageTile({
    required this.image,
    required this.isPrimary,
    required this.onRemove,
    this.onMakeCover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AppCachedImage(
            imageUrl: image.imageUrl,
            lowResolutionUrl: image.thumbnailUrl,
            fit: BoxFit.cover,
            memCacheWidth: 420,
          ),
        ),
        if (isPrimary) const _PrimaryImageBadge(),
        Positioned(
          top: 4,
          left: 4,
          child: _RemoveImageButton(onRemove: onRemove),
        ),
        if (onMakeCover != null)
          Positioned(
            top: 4,
            right: 4,
            child: _MakeCoverButton(onTap: onMakeCover!),
          ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  final XFile file;
  final bool isPrimary;
  final VoidCallback onRemove;
  final VoidCallback? onMakeCover;
  const _ImageTile({
    required this.file,
    required this.isPrimary,
    required this.onRemove,
    this.onMakeCover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(file.path),
            key: ValueKey(file.path),
            fit: BoxFit.cover,
            // Undecorated, ten 12MP photos decode to ~500MB of bitmaps for a
            // grid of 120px thumbnails — far past the image cache's 100MB
            // budget, which thrashes and, on Android, gets the activity killed
            // behind the photo picker. That is what made picked photos vanish.
            cacheWidth: 420,
            gaplessPlayback: true,
            errorBuilder: (context, _, __) => Container(
              color: AppTheme.neutralGray100,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppTheme.neutralGray400,
                size: 22,
              ),
            ),
          ),
        ),
        if (isPrimary) const _PrimaryImageBadge(),
        Positioned(
          top: 4,
          left: 4,
          child: _RemoveImageButton(onRemove: onRemove),
        ),
        if (onMakeCover != null)
          Positioned(
            top: 4,
            right: 4,
            child: _MakeCoverButton(onTap: onMakeCover!),
          ),
      ],
    );
  }
}

class _PrimaryImageBadge extends StatelessWidget {
  const _PrimaryImageBadge();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: .85),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: const Text(
          'رئيسية',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RemoveImageButton extends StatelessWidget {
  final VoidCallback onRemove;

  const _RemoveImageButton({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onPickGallery, onPickCamera;
  final VoidCallback? onReplaceGallery;
  final bool isEditMode;

  const _AddImageTile({
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onReplaceGallery,
    required this.isEditMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.neutralGray200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: Text(
                    isEditMode ? 'إضافة صور من المعرض' : 'اختر من المعرض',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onPickGallery();
                  },
                ),
                if (onReplaceGallery != null)
                  ListTile(
                    leading: const Icon(
                      Icons.find_replace_rounded,
                      color: AppTheme.primaryBlue,
                    ),
                    title: const Text('استبدال كل الصور الحالية'),
                    subtitle: const Text(
                      'يحذف الصور القديمة ويضع المختارة مكانها',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onReplaceGallery!();
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppTheme.primaryBlue,
                  ),
                  title: const Text('التقط صورة'),
                  onTap: () {
                    Navigator.pop(context);
                    onPickCamera();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.neutralGray50,
          border: Border.all(color: AppTheme.neutralGray200, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_photo_alternate_rounded,
              size: 30,
              color: AppTheme.primaryBlue,
            ),
            const SizedBox(height: 6),
            Text(
              isEditMode ? 'إدارة الصور' : 'إضافة صورة',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.neutralGray500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: Location + District + Pledge + Submit ─────────────────────────────

class _Step4LocationSubmit extends ConsumerWidget {
  final RegionModel? selectedRegion;
  final CityModel? selectedCity;
  final DistrictModel? selectedDistrict;
  final List<DistrictModel>? districtsForCity;
  final bool loadingDistricts;
  final TextEditingController districtFreeTextCtrl;
  final double? latitude;
  final double? longitude;
  final bool submitting, isEditMode;
  final String? submitStatus;
  final String? priceText;
  final int? categoryId;
  final String sellerType;
  final void Function(RegionModel?, CityModel?) onSelectLocation;
  final VoidCallback onPickDistrict;
  final VoidCallback onClearDistrict;
  final VoidCallback onPickMapLocation;
  final VoidCallback onBack, onSubmit;

  const _Step4LocationSubmit({
    required this.selectedRegion,
    required this.selectedCity,
    required this.selectedDistrict,
    required this.districtsForCity,
    required this.loadingDistricts,
    required this.districtFreeTextCtrl,
    required this.latitude,
    required this.longitude,
    required this.submitting,
    required this.submitStatus,
    required this.isEditMode,
    required this.priceText,
    required this.categoryId,
    required this.sellerType,
    required this.onSelectLocation,
    required this.onPickDistrict,
    required this.onClearDistrict,
    required this.onPickMapLocation,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSubmit = selectedCity != null && !submitting;
    final price = double.tryParse(priceText ?? '');
    // Commission is a flat per-category amount (price-independent), so preview it
    // whenever a category is chosen — not only after a price is entered.
    final commissionState = categoryId != null
        ? ref.watch(
            commissionPreviewProvider((
              price: price ?? 0,
              categoryId: categoryId!,
              sellerType: sellerType,
            )),
          )
        : null;

    final hasDistrictsLoaded =
        districtsForCity != null && districtsForCity!.isNotEmpty;
    final noDistricts = districtsForCity != null && districtsForCity!.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'موقع الإعلان',
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 12),

          // City / Region picker
          GestureDetector(
            onTap: () async {
              final result = await showRegionCityPicker(
                context,
                ref,
                isMultiSelect: false,
                initialSelection: selectedCity != null ? [selectedCity!] : null,
              );
              if (result != null && result.isNotEmpty) {
                // A city's region can come back null from the picker; the ad
                // only needs the city, so this must not throw.
                onSelectLocation(result.first.region, result.first);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selectedCity != null
                    ? AppTheme.primaryBlue.withValues(alpha: .05)
                    : AppTheme.neutralGray50,
                border: Border.all(
                  color: selectedCity != null
                      ? AppTheme.primaryBlue
                      : AppTheme.neutralGray200,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: selectedCity != null
                        ? AppTheme.primaryBlue
                        : AppTheme.neutralGray500,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedCity != null
                          ? '${selectedCity!.nameAr}، ${selectedRegion?.nameAr ?? selectedCity!.region?.nameAr ?? ''}'
                          : 'اختر المنطقة والمدينة',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selectedCity != null
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: selectedCity != null
                            ? AppTheme.neutralGray900
                            : AppTheme.neutralGray500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: AppTheme.neutralGray500,
                  ),
                ],
              ),
            ),
          ),

          // ── Map location pin ─────────────────────────────────────────────
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onPickMapLocation,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selectedCity == null
                    ? AppTheme.neutralGray100
                    : (latitude != null)
                    ? AppTheme.primaryBlue.withValues(alpha: .05)
                    : AppTheme.neutralGray50,
                border: Border.all(
                  color: (latitude != null)
                      ? AppTheme.primaryBlue
                      : AppTheme.neutralGray200,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_rounded,
                    color: (latitude != null)
                        ? AppTheme.primaryBlue
                        : AppTheme.neutralGray500,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedCity == null
                              ? 'اختر المدينة أولاً لعرض خريطتها'
                              : (latitude != null)
                              ? 'تم تحديد الموقع على الخريطة'
                              : 'تحديد الموقع على الخريطة (اختياري)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: (latitude != null)
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: selectedCity == null
                                ? AppTheme.neutralGray400
                                : (latitude != null)
                                ? AppTheme.neutralGray900
                                : AppTheme.neutralGray500,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        if (latitude != null)
                          Text(
                            '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.neutralGray500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    (latitude != null)
                        ? Icons.edit_location_alt_rounded
                        : Icons.add_location_alt_rounded,
                    color: AppTheme.neutralGray400,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── District ─────────────────────────────────────────────────────
          if (selectedCity != null) ...[
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'الحي (اختياري)',
              icon: Icons.holiday_village_outlined,
            ),
            const SizedBox(height: 8),

            if (loadingDistricts)
              Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neutralGray200),
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              )
            else if (hasDistrictsLoaded) ...[
              GestureDetector(
                onTap: onPickDistrict,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selectedDistrict != null
                        ? AppTheme.primaryBlue.withValues(alpha: .05)
                        : AppTheme.neutralGray50,
                    border: Border.all(
                      color: selectedDistrict != null
                          ? AppTheme.primaryBlue
                          : AppTheme.neutralGray200,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.maps_home_work_outlined,
                        size: 18,
                        color: selectedDistrict != null
                            ? AppTheme.primaryBlue
                            : AppTheme.neutralGray400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          selectedDistrict?.nameAr ?? 'اختر الحي',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selectedDistrict != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selectedDistrict != null
                                ? AppTheme.neutralGray900
                                : AppTheme.neutralGray500,
                          ),
                        ),
                      ),
                      if (selectedDistrict != null)
                        GestureDetector(
                          onTap: onClearDistrict,
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppTheme.neutralGray400,
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_left_rounded,
                          color: AppTheme.neutralGray400,
                        ),
                    ],
                  ),
                ),
              ),
              if (selectedDistrict == null) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: districtFreeTextCtrl,
                  textDirection: TextDirection.rtl,
                  maxLength: 120,
                  style: const TextStyle(color: AppTheme.neutralGray900),
                  decoration: _inputDecoration(
                    hint: 'الحي غير موجود؟ اكتب اسمه هنا (اختياري)',
                  ),
                ),
              ],
            ] else if (noDistricts)
              TextField(
                controller: districtFreeTextCtrl,
                textDirection: TextDirection.rtl,
                maxLength: 120,
                style: const TextStyle(color: AppTheme.neutralGray900),
                decoration: _inputDecoration(hint: 'اكتب اسم الحي (اختياري)'),
              ),
          ],

          // ── Fees & commission ─────────────────────────────────────────────
          if (commissionState != null) ...[
            const SizedBox(height: 20),
            _SectionHeader(
              title: 'الرسوم والعمولة',
              icon: Icons.receipt_long_rounded,
            ),
            const SizedBox(height: 8),
            commissionState.when(
              loading: () => Container(
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: .15),
                  ),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (preview) {
                final hasCommission = preview.commissionAmount > 0;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: .18),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Publishing is always free.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'رسوم النشر',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.neutralGray700,
                            ),
                          ),
                          Text(
                            'مجاني',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(
                          height: 1,
                          color: AppTheme.neutralGray200,
                        ),
                      ),
                      // Vehicle categories charge showrooms less than
                      // individuals, so both rates are listed rather than only
                      // whichever one applies to the seller filling this in.
                      if (preview.hasSeparateSellerRates) ...[
                        _CommissionRow(
                          label: 'عمولة البيع للمعارض (تُدفع بعد إتمام البيع)',
                          amount: preview.commissionDealer!,
                        ),
                        const SizedBox(height: 8),
                        _CommissionRow(
                          label: 'عمولة البيع للأفراد (تُدفع بعد إتمام البيع)',
                          amount: preview.commissionIndividual!,
                        ),
                      ] else
                        _CommissionRow(
                          label: 'عمولة البيع (تُدفع بعد إتمام البيع)',
                          amount: hasCommission
                              ? preview.commissionAmount
                              : null,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        preview.note,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.neutralGray600,
                          height: 1.5,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 24),

          // ── Submit row ────────────────────────────────────────────────────
          Row(
            children: [
              GestureDetector(
                onTap: submitting ? null : onBack,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.neutralGray200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '→ السابق',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: submitting
                            ? AppTheme.neutralGray400
                            : AppTheme.neutralGray600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: canSubmit ? onSubmit : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: canSubmit
                          ? const LinearGradient(
                              colors: [
                                AppTheme.primaryBlue,
                                AppTheme.primaryBlueLight,
                              ],
                            )
                          : null,
                      color: canSubmit ? null : AppTheme.neutralGray200,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: canSubmit
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: .3,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: submitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    submitStatus ?? 'جارٍ نشر الإعلان...',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isEditMode
                                      ? Icons.save_rounded
                                      : Icons.rocket_launch_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isEditMode ? 'حفظ التعديلات' : 'نشر الإعلان',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: canSubmit
                                        ? Colors.white
                                        : AppTheme.neutralGray500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── District picker sheet ─────────────────────────────────────────────────────

class _DistrictPickerSheet extends StatefulWidget {
  final List<DistrictModel> districts;
  const _DistrictPickerSheet({required this.districts});

  @override
  State<_DistrictPickerSheet> createState() => _DistrictPickerSheetState();
}

class _DistrictPickerSheetState extends State<_DistrictPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.trim().isEmpty
        ? widget.districts
        : widget.districts
              .where((d) => d.nameAr.contains(_query.trim()))
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.neutralGray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'اختر الحي',
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.neutralGray100,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(6),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                textDirection: TextDirection.rtl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'بحث في الأحياء...',
                  hintTextDirection: TextDirection.rtl,
                  hintStyle: const TextStyle(
                    color: AppTheme.neutralGray500,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppTheme.neutralGray400,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppTheme.neutralGray50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.neutralGray200,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.neutralGray100),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppTheme.neutralGray100,
                ),
                itemBuilder: (_, i) {
                  final d = filtered[i];
                  return ListTile(
                    title: Text(
                      d.nameAr,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_back_ios,
                      size: 14,
                      color: AppTheme.neutralGray400,
                    ),
                    onTap: () => Navigator.pop(context, d),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.neutralGray900,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;
  const _FormField({
    required this.label,
    required this.required,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutralGray800,
              ),
              children: required
                  ? [
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: Colors.red),
                      ),
                    ]
                  : [],
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? AppTheme.primaryBlue : Colors.white,
                border: Border.all(
                  color: value ? AppTheme.primaryBlue : AppTheme.neutralGray200,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: value
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceOptionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PriceOptionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryBlue.withValues(alpha: .10)
                : AppTheme.neutralGray50,
            border: Border.all(
              color: selected ? AppTheme.primaryBlue : AppTheme.neutralGray200,
              width: selected ? 1.8 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppTheme.primaryBlue
                    : AppTheme.neutralGray500,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppTheme.primaryBlue
                      : AppTheme.neutralGray600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  const _NavRow({
    required this.onBack,
    required this.onNext,
    required this.nextLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.neutralGray200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                '→ السابق',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutralGray600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryButton(label: nextLabel, onPressed: onNext),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 50,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
                )
              : null,
          color: enabled ? null : AppTheme.neutralGray200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withValues(alpha: .25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: enabled ? Colors.white : AppTheme.neutralGray500,
                size: 18,
              ),
              const SizedBox(width: 8),
            ],
            // "التالي: الصور" plus its chevron overflows a 390pt-wide phone
            // (iPhone 12 through 16) — and any label gets longer again under
            // large Dynamic Type.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : AppTheme.neutralGray500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error dialog ──────────────────────────────────────────────────────────────

class _ErrorDialog extends StatelessWidget {
  final String message;
  final Map<String, String> errors;
  const _ErrorDialog({required this.message, required this.errors});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: Colors.red.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'تعذّر نشر الإعلان',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            message,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...errors.values.map(
              (err) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        err,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.red.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'حسناً',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration({
  String? hint,
  String? error,
  Widget? prefix,
}) {
  return InputDecoration(
    hintText: hint,
    hintTextDirection: TextDirection.rtl,
    hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
    errorText: error,
    prefix: prefix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.neutralGray200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.neutralGray200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}
