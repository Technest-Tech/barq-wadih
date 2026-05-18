import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../regions/domain/region_model.dart';
import '../../../regions/presentation/region_city_picker.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';
import '../providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _bioCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();

  RegionModel? _region;
  CityModel?   _city;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = _user;
    if (user != null) {
      _nameCtrl.text  = user.name;
      _bioCtrl.text   = user.bio ?? '';
      _emailCtrl.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  AuthUser? get _user {
    final s = ref.read(authProvider);
    return s is AuthAuthenticated ? s.user : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final updated = await repo.updateProfile(
        name:     _nameCtrl.text.trim(),
        bio:      _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        email:    _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        regionId: _region?.id,
        cityId:   _city?.id,
      );
      ref.read(authProvider.notifier).refreshUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('تم تحديث الملف الشخصي', style: TextStyle(color: Colors.white)),
          ]),
          backgroundColor: AppTheme.primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل الحفظ: ${e.toString()}',
            style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      backgroundColor: AppTheme.neutralGray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.neutralGray900,
        // RTL: leading appears on the right
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'تعديل الملف الشخصي',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryBlue, strokeWidth: 2.5))
                : TextButton(
                    onPressed: _save,
                    child: const Text(
                      'حفظ',
                      style: TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Personal info ─────────────────────────────────────────────
                _SectionCard(
                  title: 'المعلومات الشخصية',
                  children: [
                    _FieldGroup(
                      label: 'الاسم الكامل',
                      required: true,
                      child: TextFormField(
                        controller: _nameCtrl,
                        textDirection: TextDirection.rtl,
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'الاسم يجب أن يكون حرفين على الأقل' : null,
                        decoration: _inputDec(hint: 'أحمد محمد'),
                      ),
                    ),
                    _FieldGroup(
                      label: 'نبذة شخصية',
                      required: false,
                      child: TextFormField(
                        controller: _bioCtrl,
                        textDirection: TextDirection.rtl,
                        maxLines: 3,
                        decoration: _inputDec(hint: 'اكتب نبذة مختصرة عنك...'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Contact ───────────────────────────────────────────────────
                _SectionCard(
                  title: 'معلومات التواصل',
                  children: [
                    _FieldGroup(
                      label: 'البريد الإلكتروني',
                      required: false,
                      child: TextFormField(
                        controller: _emailCtrl,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return v.contains('@') ? null : 'البريد غير صالح';
                        },
                        decoration: _inputDec(hint: 'you@example.com (اختياري)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Location ──────────────────────────────────────────────────
                _SectionCard(
                  title: 'الموقع',
                  children: [
                    _FieldGroup(
                      label: 'المنطقة والمدينة',
                      required: false,
                      child: GestureDetector(
                        onTap: () async {
                          final result = await showRegionCityPicker(
                            context,
                            ref,
                            isMultiSelect: false,
                            initialSelection: _city != null ? [_city!] : null,
                          );
                          if (result != null && result.isNotEmpty) {
                            setState(() {
                              _city = result.first;
                              _region = result.first.region;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppTheme.neutralGray200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                color: _city != null
                                    ? AppTheme.primaryBlue : AppTheme.neutralGray500,
                                size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(
                                _city != null
                                    ? '${_city!.nameAr}، ${_region!.nameAr}'
                                    : 'اختر المنطقة والمدينة',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _city != null
                                      ? AppTheme.neutralGray900 : AppTheme.neutralGray500,
                                ),
                              )),
                              const Icon(Icons.chevron_left_rounded,
                                color: AppTheme.neutralGray500, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Save button ───────────────────────────────────────────────
                GestureDetector(
                  onTap: _saving ? null : _save,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: _saving ? null : const LinearGradient(
                        colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight]),
                      color: _saving ? AppTheme.neutralGray200 : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _saving ? null : [BoxShadow(
                        color: AppTheme.primaryBlue.withValues(alpha: .25),
                        blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                          : const Text('حفظ التغييرات',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: .04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title,
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppTheme.neutralGray500, letterSpacing: .5)),
          ),
          const Divider(height: 1, color: AppTheme.neutralGray100),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;
  const _FieldGroup({required this.label, required this.required, required this.child});

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
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.neutralGray800),
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

InputDecoration _inputDec({required String hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.neutralGray500, fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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
  );
}
