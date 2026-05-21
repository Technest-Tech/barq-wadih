// lib/features/ads/presentation/screens/post_ad_screen.dart

import 'dart:io';

import '../../../../core/network/api_client.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'map_location_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../categories/data/category_api.dart';
import '../../../categories/domain/category_model.dart';
import '../../../regions/presentation/region_city_picker.dart';
import '../../../regions/domain/region_model.dart';
import '../../../regions/data/region_api.dart';
import '../../data/ad_api.dart';
import '../../domain/ad_model.dart';

enum _PriceOption { fixed, negotiable, callForPrice }

class PostAdScreen extends ConsumerStatefulWidget {
  final int? adId;
  const PostAdScreen({super.key, this.adId});

  @override
  ConsumerState<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<PostAdScreen> {
  late final PageController _pageController;
  late int _step;
  bool _submitting = false;
  bool _loadingExisting = false;
  Map<String, String> _fieldErrors = {};

  // Step 0 — Pledge
  bool _pledgeAccepted = false;

  // Step 1 — Category
  CategoryModel? _selectedCategory;

  // Step 2 — Details
  String _sellerType = 'individual'; // 'individual' | 'dealer'
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  _PriceOption _priceOption = _PriceOption.fixed;
  bool _showPhonePublicly = true;

  // Dynamic category field controllers
  final Map<String, TextEditingController> _dynControllers = {};
  final Map<String, String> _fieldValues = {};

  // Step 3 — Images
  final List<XFile> _images = [];

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

  bool get _step2Valid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      (!_showPhonePublicly || _phoneCtrl.text.trim().isNotEmpty) &&
      (_priceOption != _PriceOption.fixed || _priceCtrl.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    // Edit mode skips the pledge step (already agreed when first posting)
    final initialPage = _isEditMode ? 1 : 0;
    _pageController = PageController(initialPage: initialPage);
    _step = initialPage;
    if (_isEditMode) {
      _pledgeAccepted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingAd());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _districtFreeTextCtrl.dispose();
    for (final c in _dynControllers.values) {
      c.dispose();
    }
    super.dispose();
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
        _whatsappCtrl.text = ad.contactWhatsapp ?? '';
        _priceOption = ad.priceHidden
            ? _PriceOption.callForPrice
            : ad.isNegotiable
            ? _PriceOption.negotiable
            : _PriceOption.fixed;
        _showPhonePublicly = ad.showPhonePublicly;

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
        _loadDistricts(_selectedCity!.id);
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
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  // ── Districts ──────────────────────────────────────────────────────────────

  Future<void> _loadDistricts(int cityId) async {
    if (_districtsLoadedForCityId == cityId) return;
    setState(() {
      _loadingDistricts = true;
      _selectedDistrict = null;
      _districtFreeTextCtrl.clear();
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
    if (result != null) setState(() => _selectedDistrict = result);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _jumpToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _step = step);
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _step++);
  }

  void _prev() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _step--);
  }

  TextEditingController _dynCtrl(String key) {
    return _dynControllers.putIfAbsent(key, () {
      final c = TextEditingController(text: _fieldValues[key] ?? '');
      c.addListener(() => _fieldValues[key] = c.text);
      return c;
    });
  }

  // ── Image picking ──────────────────────────────────────────────────────────

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    final remaining = 10 - _images.length;
    setState(() => _images.addAll(picked.take(remaining)));
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (picked != null && _images.length < 10) {
      setState(() => _images.add(picked));
    }
  }

  // ── Payment confirmation before submit ────────────────────────────────────

  Future<void> _handleSubmit() async {
    final publishFee = _selectedCategory?.publishFee(_sellerType) ?? 0.0;
    final categoryIsFree = _selectedCategory?.isFree ?? false;

    if (categoryIsFree || publishFee <= 0) {
      // Free category or no publish fee — submit directly
      await _submit();
      return;
    }

    // Show payment confirmation sheet first
    if (!mounted) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PublishPaymentSheet(
        fee: publishFee,
        categoryName: _selectedCategory?.nameAr ?? '',
        sellerType: _sellerType,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed == true && mounted) {
      await _submit();
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_pledgeAccepted || _selectedCity == null) return;
    setState(() {
      _submitting = true;
      _fieldErrors = {};
    });
    try {
      final imagesData = await Future.wait(
        _images.map(
          (f) async => MultipartFile.fromFile(
            f.path,
            filename: File(f.path).uri.pathSegments.last,
          ),
        ),
      );

      final regionId = _selectedCity?.region?.id ?? _selectedRegion?.id;

      final formFields = <String, dynamic>{
        'seller_type': _sellerType,
        'city_id': _selectedCity!.id.toString(),
        if (regionId != null) 'region_id': regionId.toString(),
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        if (_priceOption == _PriceOption.fixed &&
            _priceCtrl.text.trim().isNotEmpty)
          'price': _priceCtrl.text.trim(),
        'is_free': '0',
        'is_negotiable': (_priceOption == _PriceOption.negotiable) ? '1' : '0',
        'price_hidden': (_priceOption == _PriceOption.callForPrice) ? '1' : '0',
        'show_phone_publicly': _showPhonePublicly ? '1' : '0',
        'contact_phone': _phoneCtrl.text.trim(),
        if (_whatsappCtrl.text.isNotEmpty)
          'contact_whatsapp': _whatsappCtrl.text.trim(),
        if (_selectedDistrict != null)
          'district_id': _selectedDistrict!.id.toString()
        else if (_districtFreeTextCtrl.text.trim().isNotEmpty)
          'district_name_free': _districtFreeTextCtrl.text.trim(),
        'pledge_accepted': '1',
        if (_latitude != null) 'latitude': _latitude.toString(),
        if (_longitude != null) 'longitude': _longitude.toString(),
        ..._fieldValues.map((k, v) => MapEntry('fields[$k]', v)),
      };

      if (!_isEditMode) {
        formFields['category_id'] = _selectedCategory!.id.toString();
      }

      final formData = FormData.fromMap({
        ...formFields,
        if (imagesData.isNotEmpty) 'images[]': imagesData,
      });

      final AdDetailModel ad;
      if (_isEditMode) {
        ad = await ref
            .read(adRepositoryProvider)
            .updateAd(widget.adId!, formData);
      } else {
        ad = await ref.read(adRepositoryProvider).createAd(formData);
      }

      if (mounted) {
        ref.invalidate(adsFeedProvider);
        ref.invalidate(myAdsProvider);
        context.go('/ads/${ad.id}');
        ScaffoldMessenger.of(context).showSnackBar(
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
              children: [
                // ── Step 0: Pledge (القسم) ─────────────────────────────────
                _Step0Pledge(
                  pledgeAccepted: _pledgeAccepted,
                  onPledgeChanged: (v) => setState(() => _pledgeAccepted = v),
                  onNext: _pledgeAccepted ? _next : () {},
                ),
                // ── Step 1: Category ───────────────────────────────────────
                _Step1Category(
                  selected: _selectedCategory,
                  isLocked: _isEditMode,
                  onSelect: (cat) {
                    setState(() => _selectedCategory = cat);
                    _next();
                  },
                  onNextLocked: _isEditMode ? () => _jumpToStep(2) : null,
                ),
                // ── Step 2: Details ────────────────────────────────────────
                _Step2Details(
                  titleCtrl: _titleCtrl,
                  descCtrl: _descCtrl,
                  priceCtrl: _priceCtrl,
                  phoneCtrl: _phoneCtrl,
                  whatsappCtrl: _whatsappCtrl,
                  priceOption: _priceOption,
                  showPhonePublicly: _showPhonePublicly,
                  categoryId: _selectedCategory?.id,
                  fieldValues: _fieldValues,
                  errors: _fieldErrors,
                  onPriceOptionChanged: (v) => setState(() => _priceOption = v),
                  onShowPhoneChanged: (v) =>
                      setState(() => _showPhonePublicly = v),
                  onFieldChanged: (k, v) => setState(() => _fieldValues[k] = v),
                  dynCtrl: _dynCtrl,
                  isValid: _step2Valid,
                  onBack: _prev,
                  onNext: () {
                    if (_step2Valid) _next();
                  },
                ),
                // ── Step 3: Images ─────────────────────────────────────────
                _Step3Images(
                  images: _images,
                  onPickGallery: _pickImages,
                  onPickCamera: _pickFromCamera,
                  onRemove: (i) => setState(() => _images.removeAt(i)),
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
                  isEditMode: _isEditMode,
                  priceText: _priceCtrl.text.trim(),
                  categoryId: _selectedCategory?.id,
                  sellerType: _sellerType,
                  onSellerTypeChanged: (v) => setState(() => _sellerType = v),
                  onSelectLocation: (r, c) {
                    setState(() {
                      _selectedRegion = r;
                      _selectedCity = c;
                      _selectedDistrict = null;
                      _districtFreeTextCtrl.clear();
                    });
                    if (c != null) _loadDistricts(c.id);
                  },
                  onPickDistrict: _showDistrictPicker,
                  onClearDistrict: () =>
                      setState(() => _selectedDistrict = null),
                  onPickMapLocation: () async {
                    final picked = await Navigator.push<LatLng>(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => MapLocationPicker(
                          initialLocation:
                              (_latitude != null && _longitude != null)
                              ? LatLng(_latitude!, _longitude!)
                              : null,
                        ),
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _latitude = picked.latitude;
                        _longitude = picked.longitude;
                      });
                    }
                  },
                  onBack: _prev,
                  onSubmit: _handleSubmit,
                ),
              ],
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
      onPressed: () => context.pop(),
    ),
  );
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
      '٢. أن أدفع للموقع رسوم العمولة المستحقة المحددة حسب القسم المختار، خلال مدة لا تتجاوز 10 أيام من استلامي لكامل مبلغ المبايعة من المشتري.\n\n'
      '٣. أن رسوم النشر المدفوعة عند إنشاء الإعلان غير مستردة، وذلك مقابل خدمة عرض الإعلان والوصول إلى المهتمين.\n\n'
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
  final void Function(CategoryModel) onSelect;
  final VoidCallback? onNextLocked;

  const _Step1Category({
    required this.selected,
    required this.isLocked,
    required this.onSelect,
    this.onNextLocked,
  });

  @override
  ConsumerState<_Step1Category> createState() => _Step1CategoryState();
}

class _Step1CategoryState extends ConsumerState<_Step1Category> {
  CategoryModel? _browsing; // parent being drilled into

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
      data: (cats) => _browsing != null
          ? _buildSubList(_browsing!)
          : _buildParentList(cats),
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
          child: Text(
            'اختر القسم',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.neutralGray600,
            ),
            textDirection: TextDirection.rtl,
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
                    setState(() => _browsing = cat);
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
          onTap: () => setState(() => _browsing = null),
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
  final TextEditingController titleCtrl,
      descCtrl,
      priceCtrl,
      phoneCtrl,
      whatsappCtrl;
  final _PriceOption priceOption;
  final bool showPhonePublicly, isValid;
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
    required this.whatsappCtrl,
    required this.priceOption,
    required this.showPhonePublicly,
    required this.isValid,
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
    final categoryFieldsState = widget.categoryId != null
        ? ref.watch(categoryFieldsProvider(widget.categoryId!))
        : null;

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
              style: const TextStyle(color: AppTheme.neutralGray900),
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                hint: 'مثال: تويوتا كامري 2022 نظيف',
                error: widget.errors['title'],
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
              style: const TextStyle(color: AppTheme.neutralGray900),
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(
                hint:
                    'صف السلعة بتفاصيل كافية — الحالة، المواصفات، سبب البيع...',
                error: widget.errors['description'],
              ),
            ),
          ),

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

          if (widget.priceOption == _PriceOption.fixed) ...[
            _FormField(
              label: 'السعر',
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
                  prefix: const Text(
                    'ر.س  ',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // ── Dynamic category fields ───────────────────────────────────────
          if (categoryFieldsState != null) ...[
            categoryFieldsState.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryBlue,
                    strokeWidth: 2,
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (fields) {
                if (fields.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'المواصفات',
                      icon: Icons.tune_rounded,
                    ),
                    const SizedBox(height: 12),
                    ...fields.map((f) {
                      if (f.options.isNotEmpty) {
                        return _FormField(
                          label: f.labelAr,
                          required: f.isRequired,
                          child: DropdownButtonFormField<String>(
                            initialValue: widget.fieldValues[f.fieldKey],
                            hint: Text(
                              f.placeholderAr ?? 'اختر...',
                              style: const TextStyle(
                                color: AppTheme.neutralGray500,
                              ),
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.neutralGray200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppTheme.neutralGray200,
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
                            items: f.options
                                .map(
                                  (o) => DropdownMenuItem(
                                    value: o,
                                    child: Text(
                                      o,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null)
                                widget.onFieldChanged(f.fieldKey, v);
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
                          keyboardType:
                              f.fieldType == 'number' || f.fieldType == 'year'
                              ? TextInputType.number
                              : TextInputType.text,
                          style: const TextStyle(
                            color: AppTheme.neutralGray900,
                          ),
                          decoration: _inputDecoration(
                            hint: f.placeholderAr ?? '',
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
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
          const SizedBox(height: 8),

          _FormField(
            label: 'رقم التواصل',
            required: widget.showPhonePublicly,
            child: TextField(
              controller: widget.phoneCtrl,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppTheme.neutralGray900),
              decoration: _inputDecoration(
                hint: '05xxxxxxxx',
                error: widget.errors['contact_phone'],
                prefix: const Text(
                  '🇸🇦 +966  ',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),

          _FormField(
            label: 'رقم واتساب',
            required: false,
            child: TextField(
              controller: widget.whatsappCtrl,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppTheme.neutralGray900),
              decoration: _inputDecoration(
                hint: '05xxxxxxxx (اختياري)',
                prefix: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text('💬  ', style: TextStyle(fontSize: 15))],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _NavRow(
            onBack: widget.onBack,
            onNext: widget.isValid ? widget.onNext : null,
            nextLabel: 'التالي: الصور',
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Images ────────────────────────────────────────────────────────────

class _Step3Images extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onPickGallery, onPickCamera;
  final void Function(int) onRemove;
  final VoidCallback onBack, onNext;

  const _Step3Images({
    required this.images,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemove,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'صور الإعلان',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'أضف حتى 10 صور • الصورة الأولى ستكون الرئيسية',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.neutralGray500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${images.length}/10 صور',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutralGray600,
                ),
              ),
              if (images.isNotEmpty)
                Text(
                  'اضغط × لحذف صورة',
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
              itemCount: images.length + (images.length < 10 ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == images.length) {
                  return _AddImageTile(
                    onPickGallery: onPickGallery,
                    onPickCamera: onPickCamera,
                  );
                }
                return _ImageTile(
                  file: images[i],
                  isPrimary: i == 0,
                  onRemove: () => onRemove(i),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _NavRow(
            onBack: onBack,
            onNext: images.isNotEmpty ? onNext : null,
            nextLabel: 'التالي: الموقع',
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final XFile file;
  final bool isPrimary;
  final VoidCallback onRemove;
  const _ImageTile({
    required this.file,
    required this.isPrimary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(file.path), fit: BoxFit.cover),
        ),
        if (isPrimary)
          Positioned(
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
          ),
        Positioned(
          top: 4,
          left: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onPickGallery, onPickCamera;
  const _AddImageTile({
    required this.onPickGallery,
    required this.onPickCamera,
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
                  title: const Text('اختر من المعرض'),
                  onTap: () {
                    Navigator.pop(context);
                    onPickGallery();
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
              'إضافة صورة',
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
  final String? priceText;
  final int? categoryId;
  final String sellerType;
  final void Function(String) onSellerTypeChanged;
  final void Function(RegionModel, CityModel?) onSelectLocation;
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
    required this.isEditMode,
    required this.priceText,
    required this.categoryId,
    required this.sellerType,
    required this.onSellerTypeChanged,
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
    final commissionState = (price != null && price > 0 && categoryId != null)
        ? ref.watch(
            commissionPreviewProvider((
              price: price,
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
          // ── Seller type ────────────────────────────────────────────────────
          _SectionHeader(
            title: 'أنت تبيع بصفتك',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onSellerTypeChanged('individual'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: sellerType == 'individual'
                          ? const Color(0xFFDCFCE7)
                          : Colors.white,
                      border: Border.all(
                        color: sellerType == 'individual'
                            ? const Color(0xFF16A34A)
                            : AppTheme.neutralGray200,
                        width: sellerType == 'individual' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: sellerType == 'individual'
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF16A34A,
                                ).withValues(alpha: .15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        const Text('👤', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text(
                          'فرد',
                          style: TextStyle(
                            fontSize: 14,
                            color: sellerType == 'individual'
                                ? const Color(0xFF15803D)
                                : AppTheme.neutralGray600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => onSellerTypeChanged('dealer'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: sellerType == 'dealer'
                          ? const Color(0xFFFFF7ED)
                          : Colors.white,
                      border: Border.all(
                        color: sellerType == 'dealer'
                            ? const Color(0xFFEA580C)
                            : AppTheme.neutralGray200,
                        width: sellerType == 'dealer' ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: sellerType == 'dealer'
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFEA580C,
                                ).withValues(alpha: .15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        const Text('🏢', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 6),
                        Text(
                          'معرض / تاجر',
                          style: TextStyle(
                            fontSize: 14,
                            color: sellerType == 'dealer'
                                ? const Color(0xFFC2410C)
                                : AppTheme.neutralGray600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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
                onSelectLocation(result.first.region!, result.first);
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
                color: (latitude != null)
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
                          (latitude != null)
                              ? 'تم تحديد الموقع على الخريطة'
                              : 'تحديد الموقع على الخريطة (اختياري)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: (latitude != null)
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: (latitude != null)
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
            else if (hasDistrictsLoaded)
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
              )
            else if (noDistricts)
              TextField(
                controller: districtFreeTextCtrl,
                textDirection: TextDirection.rtl,
                maxLength: 120,
                style: const TextStyle(color: AppTheme.neutralGray900),
                decoration: _inputDecoration(hint: 'اكتب اسم الحي (اختياري)'),
              ),
          ],

          // ── Commission ────────────────────────────────────────────────────
          if (commissionState != null) ...[
            const SizedBox(height: 20),
            _SectionHeader(title: 'عمولة الخدمة', icon: Icons.percent_rounded),
            const SizedBox(height: 8),
            commissionState.when(
              loading: () => Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (preview) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('💰', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (!preview.isFlatFee)
                                Text(
                                  '~',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              Text(
                                '${preview.commissionAmount.toStringAsFixed(0)} ر.س'
                                '${preview.isFlatFee ? '' : ' عمولة متوقعة'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preview.note,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade800,
                              height: 1.4,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: enabled ? Colors.white : AppTheme.neutralGray500,
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

// ── Publish Payment Confirmation Sheet ────────────────────────────────────────

class _PublishPaymentSheet extends StatelessWidget {
  final double fee;
  final String categoryName;
  final String sellerType;
  final VoidCallback onConfirm;

  const _PublishPaymentSheet({
    required this.fee,
    required this.categoryName,
    required this.sellerType,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.neutralGray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Text('💳', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          const Text(
            'رسوم نشر الإعلان',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.neutralGray900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'قسم: $categoryName',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.neutralGray500,
            ),
          ),
          const SizedBox(height: 20),

          // Fee display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: .2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'رسوم النشر',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.neutralGray700,
                  ),
                ),
                Text(
                  '${fee.toStringAsFixed(0)} ر.س',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payment methods
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pmBadge(
                Icons.credit_card_rounded,
                'مدى',
                const Color(0xFF006B3F),
              ),
              const SizedBox(width: 12),
              _pmBadge(Icons.apple, 'Apple Pay', Colors.black87),
              const SizedBox(width: 12),
              _pmBadge(
                Icons.phone_android_rounded,
                'STC Pay',
                const Color(0xFF7B1FA2),
              ),
              const SizedBox(width: 12),
              _pmBadge(
                Icons.account_balance_rounded,
                'بنكي',
                const Color(0xFF1565C0),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Non-refundable notice
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange.shade700,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الرسوم غير مستردة وتُخصم من العمولة عند إتمام البيع.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                      height: 1.4,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Confirm button
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(
              'تأكيد الدفع ونشر الإعلان (${fee.toStringAsFixed(0)} ر.س)',
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppTheme.neutralGray500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pmBadge(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.neutralGray600,
          ),
        ),
      ],
    );
  }
}
