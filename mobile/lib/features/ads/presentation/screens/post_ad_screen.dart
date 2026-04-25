// lib/features/ads/presentation/screens/post_ad_screen.dart

import 'dart:io';

import '../../../../core/network/api_client.dart';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../categories/presentation/category_browser_sheet.dart';
import '../../../categories/domain/category_model.dart';
import '../../../regions/presentation/region_city_picker.dart';
import '../../../regions/domain/region_model.dart';
import '../../data/ad_api.dart';
import '../../domain/ad_model.dart';

class PostAdScreen extends ConsumerStatefulWidget {
  /// `null` = create mode, non-null = edit mode with that ad ID
  final int? adId;
  const PostAdScreen({super.key, this.adId});

  @override
  ConsumerState<PostAdScreen> createState() => _PostAdScreenState();
}

class _PostAdScreenState extends ConsumerState<PostAdScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _submitting = false;
  bool _loadingExisting = false;
  Map<String, String> _fieldErrors = {};

  // Step 1 — Category
  CategoryModel? _selectedCategory;

  // Step 2 — Details
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _priceCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  bool _isFree        = false;
  bool _isNegotiable  = false;

  // Dynamic category field controllers — keyed by fieldKey to avoid recreation
  final Map<String, TextEditingController> _dynControllers = {};
  final Map<String, String> _fieldValues = {};

  // Step 3 — Images
  final List<XFile> _images = [];

  // Step 4 — Location + Pledge
  RegionModel? _selectedRegion;
  CityModel?   _selectedCity;
  bool _pledgeAccepted = false;

  bool get _isEditMode => widget.adId != null;

  // ── Step 2 validation gate ─────────────────────────────────────────────────

  bool get _step2Valid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      (_isFree || _priceCtrl.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
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
    for (final c in _dynControllers.values) { c.dispose(); }
    super.dispose();
  }

  // ── Load existing ad (edit mode) ───────────────────────────────────────────

  Future<void> _loadExistingAd() async {
    setState(() => _loadingExisting = true);
    try {
      final ad = await ref.read(adRepositoryProvider).getAd(widget.adId!);
      if (!mounted) return;
      setState(() {
        // Step 1 — set category stub (will be locked)
        if (ad.category != null) {
          _selectedCategory = CategoryModel(
            id:          ad.category!.id,
            nameAr:      ad.category!.nameAr,
            nameEn:      '',
            slug:        '',
            icon:        ad.category!.icon,
            sortOrder:   0,
            isActive:    true,
            isFree:      false,
            adsCount:    0,
            fieldsCount: 0,
          );
        }
        // Step 2 — details
        _titleCtrl.text    = ad.title;
        _descCtrl.text     = ad.description;
        _priceCtrl.text    = ad.price?.toStringAsFixed(0) ?? '';
        _phoneCtrl.text    = ad.contactPhone;
        _whatsappCtrl.text = ad.contactWhatsapp ?? '';
        _isFree            = ad.isFree;
        _isNegotiable      = ad.isNegotiable;

        // Dynamic fields
        for (final fv in ad.fieldValues) {
          _fieldValues[fv.fieldKey] = fv.value?.toString() ?? '';
        }

        // Step 4 — location (pre-fill from saved data if available)
        if (ad.region != null) {
          _selectedRegion = RegionModel(
            id:          ad.region!.id,
            nameAr:      ad.region!.nameAr,
            nameEn:      '',
            slug:        '',
            sortOrder:   0,
            citiesCount: 0,
          );
        }
        if (ad.city != null) {
          _selectedCity = CityModel(
            id:       ad.city!.id,
            nameAr:   ad.city!.nameAr,
            nameEn:   '',
            slug:     '',
            adsCount: 0,
          );
        }

        // Pledge pre-accepted for edits
        _pledgeAccepted = true;
      });
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

  // ── Navigation ─────────────────────────────────────────────────────────────

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

  // ── Dynamic field controller ───────────────────────────────────────────────

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
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null && _images.length < 10) {
      setState(() => _images.add(picked));
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_pledgeAccepted || _selectedCity == null) return;
    setState(() { _submitting = true; _fieldErrors = {}; });
    try {
      final imagesData = await Future.wait(
        _images.map((f) async => MultipartFile.fromFile(
          f.path,
          filename: File(f.path).uri.pathSegments.last,
        )),
      );

      final formFields = <String, dynamic>{
        'city_id':         _selectedCity!.id.toString(),
        'title':           _titleCtrl.text.trim(),
        'description':     _descCtrl.text.trim(),
        'price':           _isFree ? '0' : _priceCtrl.text.trim(),
        'is_free':         _isFree ? '1' : '0',
        'is_negotiable':   _isNegotiable ? '1' : '0',
        'contact_phone':   _phoneCtrl.text.trim(),
        if (_whatsappCtrl.text.isNotEmpty) 'contact_whatsapp': _whatsappCtrl.text.trim(),
        'pledge_accepted': '1',
        ..._fieldValues.map((k, v) => MapEntry('fields[$k]', v)),
      };

      // Only set category_id in create mode
      if (!_isEditMode) {
        formFields['category_id'] = _selectedCategory!.id.toString();
      }

      final formData = FormData.fromMap({
        ...formFields,
        if (imagesData.isNotEmpty) 'images[]': imagesData,
      });

      final AdDetailModel ad;
      if (_isEditMode) {
        ad = await ref.read(adRepositoryProvider).updateAd(widget.adId!, formData);
      } else {
        ad = await ref.read(adRepositoryProvider).createAd(formData);
      }

      if (mounted) {
        ref.invalidate(adsFeedProvider);
        ref.invalidate(myAdsProvider);
        context.go('/ads/${ad.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                _isEditMode ? 'تم حفظ التعديلات!' : 'تم نشر الإعلان بنجاح!',
                style: const TextStyle(color: Colors.white),
              ),
            ]),
            backgroundColor: AppTheme.primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() {
        _fieldErrors = (e.errors ?? {}).map((k, v) => MapEntry(k, (v as List).first as String));
      });
      if (_fieldErrors.isNotEmpty && mounted) {
        _pageController.animateToPage(1,
            duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
        setState(() => _step = 1);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Loading spinner while fetching existing ad in edit mode
    if (_loadingExisting) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
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
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2.5),
              SizedBox(height: 16),
              Text('جارٍ تحميل الإعلان...', style: TextStyle(color: AppTheme.neutralGray500)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
      ),
      body: Column(
        children: [
          // Step indicator
          _StepIndicator(current: _step),
          const Divider(height: 1, color: AppTheme.neutralGray200),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1Category(
                  selected: _selectedCategory,
                  isLocked: _isEditMode,
                  onSelect: (cat) {
                    setState(() => _selectedCategory = cat);
                    _next();
                  },
                  onNext: _isEditMode ? _next : null,
                ),
                _Step2Details(
                  titleCtrl: _titleCtrl,
                  descCtrl: _descCtrl,
                  priceCtrl: _priceCtrl,
                  phoneCtrl: _phoneCtrl,
                  whatsappCtrl: _whatsappCtrl,
                  isFree: _isFree,
                  isNegotiable: _isNegotiable,
                  categoryId: _selectedCategory?.id,
                  fieldValues: _fieldValues,
                  errors: _fieldErrors,
                  onFreeChanged: (v) => setState(() => _isFree = v),
                  onNegotiableChanged: (v) => setState(() => _isNegotiable = v),
                  onFieldChanged: (k, v) => setState(() => _fieldValues[k] = v),
                  dynCtrl: _dynCtrl,
                  isValid: _step2Valid,
                  onBack: _prev,
                  onNext: () {
                    if (_step2Valid) _next();
                  },
                ),
                _Step3Images(
                  images: _images,
                  onPickGallery: _pickImages,
                  onPickCamera: _pickFromCamera,
                  onRemove: (i) => setState(() => _images.removeAt(i)),
                  onBack: _prev,
                  onNext: _next,
                ),
                _Step4LocationSubmit(
                  selectedRegion: _selectedRegion,
                  selectedCity: _selectedCity,
                  pledgeAccepted: _pledgeAccepted,
                  submitting: _submitting,
                  isEditMode: _isEditMode,
                  priceText: _isFree ? null : _priceCtrl.text.trim(),
                  categoryId: _selectedCategory?.id,
                  onSelectLocation: (r, c) => setState(() { _selectedRegion = r; _selectedCity = c; }),
                  onPledgeChanged: (v) => setState(() => _pledgeAccepted = v),
                  onBack: _prev,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step Indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});
  static const _labels = ['التصنيف', 'التفاصيل', 'الصور', 'الموقع'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      child: Row(
        children: List.generate(_labels.length, (i) {
          final isDone   = i < current;
          final isActive = i == current;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 30, height: 30,
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
                              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                              : Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isActive ? AppTheme.primaryBlue : AppTheme.neutralGray500,
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
                          color: isActive
                              ? AppTheme.primaryBlue
                              : isDone
                                  ? AppTheme.primaryBlue
                                  : AppTheme.neutralGray500,
                          fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.normal,
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
                        color: isDone ? AppTheme.primaryBlue : AppTheme.neutralGray200,
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

// ── Step 1: Category ──────────────────────────────────────────────────────────

class _Step1Category extends ConsumerWidget {
  final CategoryModel? selected;
  final bool isLocked;
  final void Function(CategoryModel) onSelect;
  /// In edit mode this is non-null and navigates to step 2 without changing category
  final VoidCallback? onNext;

  const _Step1Category({
    required this.selected,
    required this.isLocked,
    required this.onSelect,
    this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.grid_view_rounded, size: 36, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 20),

          Text(
            isLocked ? 'تصنيف الإعلان' : 'اختر تصنيف إعلانك',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.neutralGray900),
          ),
          const SizedBox(height: 8),
          Text(
            isLocked
                ? 'لا يمكن تغيير التصنيف عند تعديل الإعلان'
                : 'سيساعد اختيار التصنيف الصحيح في الوصول للمشترين',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.neutralGray500, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 32),

          // Selected badge
          if (selected != null) ...[
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
                  Text(selected!.icon ?? '📂', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    selected!.nameAr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle_rounded, color: AppTheme.primaryBlue, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // In edit mode: show locked hint + Continue button
          if (isLocked) ...[
            if (selected != null) ...[
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
                    Icon(Icons.lock_outline_rounded, size: 15, color: Colors.amber.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'التصنيف مقفل أثناء التعديل',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade700),
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
                onPressed: onNext,
              ),
            ),
          ] else ...[
            // Browse button (create mode)
            SizedBox(
              width: double.infinity,
              child: _PrimaryButton(
                label: selected == null ? 'تصفح التصنيفات' : 'تغيير التصنيف',
                icon: Icons.grid_view_rounded,
                onPressed: () async {
                  final result = await showCategoryBrowserSheet(context, ref);
                  if (result != null) onSelect(result);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Step 2: Details ───────────────────────────────────────────────────────────

class _Step2Details extends ConsumerStatefulWidget {
  final TextEditingController titleCtrl, descCtrl, priceCtrl, phoneCtrl, whatsappCtrl;
  final bool isFree, isNegotiable, isValid;
  final int? categoryId;
  final Map<String, String> fieldValues;
  final Map<String, String> errors;
  final void Function(bool) onFreeChanged;
  final void Function(bool) onNegotiableChanged;
  final void Function(String, String) onFieldChanged;
  final TextEditingController Function(String) dynCtrl;
  final VoidCallback onBack, onNext;

  const _Step2Details({
    required this.titleCtrl, required this.descCtrl, required this.priceCtrl,
    required this.phoneCtrl, required this.whatsappCtrl,
    required this.isFree, required this.isNegotiable, required this.isValid,
    required this.categoryId,
    required this.fieldValues, required this.errors,
    required this.onFreeChanged, required this.onNegotiableChanged, required this.onFieldChanged,
    required this.dynCtrl, required this.onBack, required this.onNext,
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
          _SectionHeader(title: 'معلومات الإعلان', icon: Icons.edit_note_rounded),
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
                hint: 'صف السلعة بتفاصيل كافية — الحالة، الموصفات، سبب البيع...',
                error: widget.errors['description'],
              ),
            ),
          ),

          // ── Price ────────────────────────────────────────────────────────
          _SectionHeader(title: 'السعر', icon: Icons.payments_outlined),
          const SizedBox(height: 12),

          // Free toggle
          _ToggleRow(
            label: 'مجاني',
            value: widget.isFree,
            onChanged: (v) { widget.onFreeChanged(v); setState(() {}); },
          ),
          if (!widget.isFree) ...[
            _ToggleRow(
              label: 'قابل للتفاوض',
              value: widget.isNegotiable,
              onChanged: (v) { widget.onNegotiableChanged(v); setState(() {}); },
            ),
            const SizedBox(height: 8),
            _FormField(
              label: 'السعر',
              required: true,
              child: TextField(
                controller: widget.priceCtrl,
                textDirection: TextDirection.rtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppTheme.neutralGray900, fontSize: 18, fontWeight: FontWeight.w700),
                decoration: _inputDecoration(
                  hint: '0',
                  error: widget.errors['price'],
                  prefix: const Text('ر.س  ', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),

          // ── Dynamic category fields ───────────────────────────────────────
          if (categoryFieldsState != null) ...[
            categoryFieldsState.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (fields) {
                if (fields.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'المواصفات', icon: Icons.tune_rounded),
                    const SizedBox(height: 12),
                    ...fields.map((f) {
                      if (f.options.isNotEmpty) {
                        // Select dropdown
                        return _FormField(
                          label: f.labelAr,
                          required: f.isRequired,
                          child: DropdownButtonFormField<String>(
                            value: widget.fieldValues[f.fieldKey],
                            hint: Text(f.placeholderAr ?? 'اختر...', style: const TextStyle(color: AppTheme.neutralGray500)),
                            decoration: InputDecoration(
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
                            ),
                            items: f.options.map((o) => DropdownMenuItem(
                              value: o,
                              child: Text(o, textDirection: TextDirection.rtl),
                            )).toList(),
                            onChanged: (v) { if (v != null) widget.onFieldChanged(f.fieldKey, v); },
                          ),
                        );
                      }
                      // Text / number field
                      return _FormField(
                        label: f.labelAr,
                        required: f.isRequired,
                        child: TextField(
                          controller: widget.dynCtrl(f.fieldKey),
                          textDirection: TextDirection.rtl,
                          keyboardType: f.fieldType == 'number' || f.fieldType == 'year'
                              ? TextInputType.number
                              : TextInputType.text,
                          style: const TextStyle(color: AppTheme.neutralGray900),
                          decoration: _inputDecoration(hint: f.placeholderAr ?? ''),
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

          _FormField(
            label: 'رقم التواصل',
            required: true,
            child: TextField(
              controller: widget.phoneCtrl,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppTheme.neutralGray900),
              decoration: _inputDecoration(
                hint: '05xxxxxxxx',
                error: widget.errors['contact_phone'],
                prefix: const Text('🇸🇦 +966  ', style: TextStyle(fontSize: 13)),
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
                prefix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('💬  ', style: TextStyle(fontSize: 15)),
                  ],
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
    required this.images, required this.onPickGallery, required this.onPickCamera,
    required this.onRemove, required this.onBack, required this.onNext,
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
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('صور الإعلان', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  Text(
                    'أضف حتى 10 صور • الصورة الأولى ستكون الرئيسية',
                    style: TextStyle(fontSize: 12, color: AppTheme.neutralGray500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Count badge
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
                  style: TextStyle(fontSize: 12, color: AppTheme.neutralGray500),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Grid
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
  const _ImageTile({required this.file, required this.isPrimary, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(file.path), fit: BoxFit.cover),
        ),
        // Primary badge
        if (isPrimary)
          Positioned(
            bottom: 0, left: 0, right: 0,
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
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        // Remove button
        Positioned(
          top: 4, left: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onPickGallery, onPickCamera;
  const _AddImageTile({required this.onPickGallery, required this.onPickCamera});

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
                Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: AppTheme.neutralGray200, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryBlue),
                  title: const Text('اختر من المعرض'),
                  onTap: () { Navigator.pop(context); onPickGallery(); },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryBlue),
                  title: const Text('التقط صورة'),
                  onTap: () { Navigator.pop(context); onPickCamera(); },
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
            const Icon(Icons.add_photo_alternate_rounded, size: 30, color: AppTheme.primaryBlue),
            const SizedBox(height: 6),
            Text('إضافة صورة', style: TextStyle(fontSize: 11, color: AppTheme.neutralGray500, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: Location + Pledge + Submit ────────────────────────────────────────

class _Step4LocationSubmit extends ConsumerWidget {
  final RegionModel? selectedRegion;
  final CityModel?   selectedCity;
  final bool pledgeAccepted, submitting, isEditMode;
  final String? priceText;
  final int? categoryId;
  final void Function(RegionModel, CityModel?) onSelectLocation;
  final void Function(bool) onPledgeChanged;
  final VoidCallback onBack, onSubmit;

  const _Step4LocationSubmit({
    required this.selectedRegion, required this.selectedCity,
    required this.pledgeAccepted, required this.submitting,
    required this.isEditMode,
    required this.priceText,
    required this.categoryId,
    required this.onSelectLocation, required this.onPledgeChanged,
    required this.onBack, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSubmit = selectedCity != null && pledgeAccepted && !submitting;
    final price = double.tryParse(priceText ?? '');
    final commissionState = (price != null && price > 0)
        ? ref.watch(commissionPreviewProvider(price))
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'موقع الإعلان', icon: Icons.location_on_rounded),
          const SizedBox(height: 12),

          // Location picker
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
                  color: selectedCity != null ? AppTheme.primaryBlue : AppTheme.neutralGray200,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: selectedCity != null ? AppTheme.primaryBlue : AppTheme.neutralGray500,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedCity != null
                          ? '${selectedCity!.nameAr}، ${selectedRegion!.nameAr}'
                          : 'اختر المنطقة والمدينة',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selectedCity != null ? FontWeight.w700 : FontWeight.normal,
                        color: selectedCity != null ? AppTheme.neutralGray900 : AppTheme.neutralGray500,
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

          // ── Commission preview ──────────────────────────────────────────
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
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
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
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: Text('💰', style: TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'عمولة متوقعة: ${preview.commissionAmount.toStringAsFixed(0)} ر.س',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            preview.note,
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade800, height: 1.4),
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

          const SizedBox(height: 28),

          // ── Pledge ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pledgeAccepted
                  ? AppTheme.primaryBlue.withValues(alpha: .04)
                  : AppTheme.neutralGray50,
              border: Border.all(
                color: pledgeAccepted ? AppTheme.primaryBlue : AppTheme.neutralGray200,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.scale(
                  scale: 1.1,
                  child: Checkbox(
                    value: pledgeAccepted,
                    onChanged: (v) => onPledgeChanged(v ?? false),
                    activeColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 13),
                    child: const Text(
                      'أُقِرُّ بأن هذا الإعلان حقيقي وغير مخالف للأنظمة، وأوافق على شروط الاستخدام وسياسة الخصوصية',
                      style: TextStyle(fontSize: 13, height: 1.6, color: AppTheme.neutralGray800),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Bottom nav ─────────────────────────────────────────────────
          Row(
            children: [
              OutlinedButton(
                onPressed: submitting ? null : onBack,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.neutralGray200),
                  foregroundColor: AppTheme.neutralGray600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('→ السابق'),
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
                              colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
                            )
                          : null,
                      color: canSubmit ? null : AppTheme.neutralGray200,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: canSubmit
                          ? [BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: .3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )]
                          : null,
                    ),
                    child: Center(
                      child: submitting
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isEditMode ? Icons.save_rounded : Icons.rocket_launch_rounded,
                                  color: Colors.white, size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isEditMode ? 'حفظ التعديلات' : 'نشر الإعلان',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: canSubmit ? Colors.white : AppTheme.neutralGray500,
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
  const _FormField({required this.label, required this.required, required this.child});

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
                  ? [const TextSpan(text: ' *', style: TextStyle(color: Colors.red))]
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
  const _ToggleRow({required this.label, required this.value, required this.onChanged});

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
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: value ? AppTheme.primaryBlue : Colors.white,
                border: Border.all(color: value ? AppTheme.primaryBlue : AppTheme.neutralGray200, width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  const _NavRow({required this.onBack, required this.onNext, required this.nextLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.neutralGray200),
            foregroundColor: AppTheme.neutralGray600,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('→ السابق'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrimaryButton(
            label: nextLabel,
            onPressed: onNext,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const _PrimaryButton({required this.label, required this.onPressed, this.icon});

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
              ? const LinearGradient(colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight])
              : null,
          color: enabled ? null : AppTheme.neutralGray200,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: .25), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: enabled ? Colors.white : AppTheme.neutralGray500, size: 18),
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
