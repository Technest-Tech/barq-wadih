import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../ads/domain/ad_model.dart';
import '../../../ads/presentation/widgets/ad_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/auth_bottom_sheet.dart';
import '../../data/favorite_repository.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border_rounded, size: 72, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'سجّل الدخول لعرض مفضلتك',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => showAuthBottomSheet(context, onSuccess: () {}),
                child: const Text('تسجيل الدخول'),
              ),
            ],
          ),
        ),
      );
    }

    final favAsync = ref.watch(favoritesListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: _buildAppBar(),
      body: favAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('خطأ في التحميل: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(favoritesListProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (ads) {
          if (ads.isEmpty) return _buildEmpty();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(favoritesListProvider),
            child: ListView.builder(
              itemCount: ads.length,
              itemBuilder: (context, index) {
                final ad = ads[index];
                return AdCard(
                  ad: ad,
                  isFavorited: true,
                  onTap: () => context.push(AppRoutes.adDetailPath(ad.id)),
                  onFavorite: () => _removeFavorite(ref, ad),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _removeFavorite(WidgetRef ref, AdListModel ad) async {
    try {
      await ref.read(favoriteRepositoryProvider).toggleFavorite(ad.id);
      ref.invalidate(favoritesListProvider);
    } catch (_) {}
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'المفضلة',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: 0.2,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border_rounded, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'لا توجد إعلانات في المفضلة',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على ♡ في أي إعلان لإضافته هنا',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
