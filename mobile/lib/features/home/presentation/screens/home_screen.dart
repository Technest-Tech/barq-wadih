import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../banners/presentation/widgets/banner_carousel.dart';
import '../../../categories/presentation/category_browser_sheet.dart';
import '../../../regions/presentation/region_city_picker.dart';
import '../../../regions/domain/region_model.dart';


// ── Provider ─────────────────────────────────────────────────────────────────

final healthProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/health');
    return response.data['data'] as Map<String, dynamic>;
  } catch (e) {
    throw ApiException(message: 'تعذّر الاتصال بالخادم');
  }
});

// ── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<CityModel>? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    final health = ref.watch(healthProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // ── Logo / Title ─────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.flash_on_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'برق واضح',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'منصة الإعلانات المبوبة الأولى في السعودية',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── Banner carousel ────────────────────────────────────────
              const BannerCarousel(position: 'home_top'),
              const SizedBox(height: 24),

              // ── Sprint 4 Demo shortcuts ───────────────────────────────────
              Text(
                'Sprint 4 — التصفح والمناطق',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),

              _DemoButton(
                icon: Icons.grid_view_rounded,
                label: 'تصفح التصنيفات',
                subtitle: 'فتح قائمة الأقسام',
                color: theme.colorScheme.primary,
                onTap: () => showCategoryBrowserSheet(context, ref),
              ),
              const SizedBox(height: 12),

              _DemoButton(
                icon: Icons.location_city_rounded,
                label: _selectedLocation != null && _selectedLocation!.isNotEmpty
                    ? '${_selectedLocation!.map((c) => c.nameAr).join('، ')} ✓'
                    : 'اختر المدينة',
                subtitle: 'اختيار المدن للمطابقة',
                color: theme.colorScheme.secondary,
                onTap: () async {
                  final result = await showRegionCityPicker(
                    context, 
                    ref, 
                    isMultiSelect: true,
                    initialSelection: _selectedLocation,
                  );
                  if (result != null && mounted) {
                     setState(() => _selectedLocation = result);
                  }
                },
              ),

              const SizedBox(height: 40),

              // ── Health status ─────────────────────────────────────────────
              Text(
                'حالة النظام',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 16),

              health.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _OfflineCard(theme: theme),
                data: (data) => _HealthCard(data: data, theme: theme),
              ),

              const SizedBox(height: 32),
              Center(
                child: Chip(
                  label: const Text('Sprint 4 — الأقسام والمناطق ✅'),
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                  labelStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Demo button ───────────────────────────────────────────────────────────────

class _DemoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DemoButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(label,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(subtitle,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_back_ios_rounded,
                  size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Health card ───────────────────────────────────────────────────────────────

class _HealthCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ThemeData theme;

  const _HealthCard({required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    final services = data['services'] as Map<String, dynamic>? ?? {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _ServiceRow('قاعدة البيانات 🗄️', services['database'], theme),
            const Divider(height: 24),
            _ServiceRow('Redis ⚡', services['redis'], theme),
            const Divider(height: 24),
            _ServiceRow('محرك البحث 🔍', services['meilisearch'], theme),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String label;
  final dynamic status;
  final ThemeData theme;

  const _ServiceRow(this.label, this.status, this.theme);

  @override
  Widget build(BuildContext context) {
    final isOk = status == 'ok';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isOk ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isOk ? 'يعمل' : 'خطأ',
            style: TextStyle(
              color: isOk ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineCard extends StatelessWidget {
  final ThemeData theme;
  const _OfflineCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFEF3C7),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          '⚠️  تعذّر الاتصال بالخادم.\nتأكد من تشغيل php artisan serve وأن الجهاز يستخدم عنوان IP الصحيح',
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Color(0xFFB45309),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}
