import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../ratings/presentation/screens/ratings_list_screen.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_user.dart';
import '../providers/auth_provider.dart';

// ── Profile Screen ─────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (authState is! AuthAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = authState.user;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.neutralGray50,
        body: CustomScrollView(
          slivers: [
            // ── Hero app bar ──────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              // In RTL context, leading appears on the right (correct for Arabic back)
              leading: IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: 'تعديل الملف الشخصي',
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.primaryBlue, AppTheme.primaryBlueLight],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _AvatarWidget(user: user),
                      const SizedBox(height: 10),
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (user.phone != null)
                        Text(
                          user.phone!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── Stats row ─────────────────────────────────────────────
                    _StatsRow(user: user),
                    const SizedBox(height: 16),

                    // ── Account info card ──────────────────────────────────────
                    _InfoCard(
                      title: 'معلومات الحساب',
                      children: [
                        _InfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'الاسم',
                          value: user.name,
                        ),
                        if (user.email != null)
                          _InfoRow(
                            icon: Icons.email_outlined,
                            label: 'البريد',
                            value: user.email!,
                            valueLtr: true,
                          ),
                        if (user.phone != null)
                          _InfoRow(
                            icon: Icons.phone_outlined,
                            label: 'الجوال',
                            value: user.phone!,
                            valueLtr: true,
                          ),
                        _InfoRow(
                          icon: Icons.verified_rounded,
                          label: 'حالة الجوال',
                          value: user.phoneVerifiedAt != null
                              ? 'تم التحقق ✓'
                              : 'لم يتم التحقق',
                          valueColor: user.phoneVerifiedAt != null
                              ? Colors.green
                              : Colors.orange,
                        ),
                        if (user.bio != null && user.bio!.isNotEmpty)
                          _InfoRow(
                            icon: Icons.info_outline_rounded,
                            label: 'نبذة',
                            value: user.bio!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Account actions ────────────────────────────────────────
                    _InfoCard(
                      title: 'الحساب',
                      children: [
                        _ActionRow(
                          icon: Icons.article_outlined,
                          label: 'إعلاناتي',
                          onTap: () => context.push('/my-ads'),
                        ),
                        _ActionRow(
                          icon: Icons.edit_outlined,
                          label: 'تعديل الملف الشخصي',
                          onTap: () => context.push('/profile/edit'),
                        ),
                        _ActionRow(
                          icon: Icons.star_rounded,
                          label: 'تقييماتي وتعليقاتي',
                          trailing: user.ratingCount > 0
                              ? _RatingBadge(
                                  rating: user.avgRating,
                                  count: user.ratingCount,
                                )
                              : null,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RatingsListScreen(
                                userId: user.id,
                                userName: user.name,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Logout ─────────────────────────────────────────────────
                    _LogoutButton(
                      onTap: () async {
                        final confirm = await _confirmLogout(context);
                        if (confirm == true && context.mounted) {
                          await ref.read(authProvider.notifier).logout();
                          if (context.mounted) context.go('/');
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('خروج', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar Widget ─────────────────────────────────────────────────────────────

class _AvatarWidget extends ConsumerWidget {
  final AuthUser user;
  const _AvatarWidget({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _pickAndUpload(context, ref),
      child: Stack(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white24,
            backgroundImage: user.avatarUrl != null
                ? CachedNetworkImageProvider(
                    AppConstants.normalizeImageUrl(user.avatarUrl!))
                : null,
            child: user.avatarUrl == null
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '؟',
                    style: const TextStyle(
                      fontSize: 30,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: AppTheme.accentGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).uploadAvatar(file);
      final updated = await ref.read(authRepositoryProvider).me();
      ref.read(authProvider.notifier).refreshUser(updated);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل رفع الصورة. حاول مرة أخرى.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final AuthUser user;
  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _StatCell(value: '${user.totalAdsCount}', label: 'إعلان'),
          _StatDivider(),
          _StatCell(value: user.avgRating, label: 'التقييم'),
          _StatDivider(),
          _StatCell(value: '${user.ratingCount}', label: 'تقييم'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value, label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.neutralGray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppTheme.neutralGray200);
}

// ── Info Card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.neutralGray500,
                letterSpacing: .5,
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.neutralGray100),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  final bool valueLtr;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueLtr = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.neutralGray500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: valueLtr ? TextAlign.left : TextAlign.right,
              textDirection:
                  valueLtr ? TextDirection.ltr : TextDirection.rtl,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppTheme.neutralGray900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.neutralGray500,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rating Badge (inline in action row) ───────────────────────────────────────

class _RatingBadge extends StatelessWidget {
  final String rating;
  final int count;
  const _RatingBadge({required this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: AppTheme.accentGold),
          const SizedBox(width: 3),
          Text(
            '$rating ($count)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentGold,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logout Button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: Colors.red.shade700, size: 18),
            const SizedBox(width: 8),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
