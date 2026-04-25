import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/messages/data/chat_providers.dart';
import '../../features/notifications/data/notification_providers.dart';
import '../theme/app_theme.dart';

/// Main app shell — matches the Haraj/target screenshot exactly:
///  - White BottomAppBar with CircularNotchedRectangle smooth curve
///  - Blue circular FAB docked at center
///  - 4 nav items: Home | Favorites | [notch] | Notifications | Messages
///  - Soft top shadow, NO hard border line
///  - extendBody: false so the notch background matches the scaffold (white)
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  static const _routes = [
    '/',
    '/messages',
    '/post-ad',
    '/notifications',
    '/profile',
  ];

  void _onTap(int index) {
    if (index == 2) {
      final auth = ref.read(authProvider);
      if (auth is AuthAuthenticated) {
        context.push('/post-ad');
      } else {
        context.push('/login');
      }
      return;
    }
    if (index == 1 || index == 3 || index == 4) {
      if (ref.read(authProvider) is! AuthAuthenticated) {
        context.push('/login');
        return;
      }
    }
    HapticFeedback.lightImpact();
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    int activeIndex = 0;
    if (location.startsWith('/messages'))          { activeIndex = 1; }
    else if (location.startsWith('/notifications')) { activeIndex = 3; }
    else if (location.startsWith('/profile'))       { activeIndex = 4; }

    // Real-time unread count for messages tab badge
    final user = ref.watch(currentUserProvider);
    final unread = user != null
        ? ref.watch(totalUnreadProvider(user.id.toString()))
        : 0;

    // Unread notification count for notifications tab badge
    final notifCountAsync = user != null
        ? ref.watch(unreadNotificationCountProvider)
        : const AsyncValue<int>.data(0);
    final notifUnread = notifCountAsync.when(
      data: (c) => c,
      loading: () => 0,
      error: (_, __) => 0,
    );

    return Scaffold(
      // extendBody MUST be false so the notch cutout shows the white scaffold BG
      extendBody: false,
      backgroundColor: Colors.white,
      body: widget.child,

      // ── Floating Action Button ──────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _PostFab(onTap: () => _onTap(2)),

      // ── Bottom Bar ─────────────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(context, activeIndex, unread, notifUnread),
    );
  }

  Widget _buildBottomBar(BuildContext context, int activeIndex, int unread, int notifUnread) {
    return Container(
      // Soft shadow above the bar (no hard border)
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),   // ~10% black
            blurRadius: 16,
            spreadRadius: 0,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 0,              // shadow handled by parent Container
        surfaceTintColor: Colors.transparent,
        padding: EdgeInsets.zero,
        height: 65,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // RTL order: الرئيسية | الرسائل | [notch gap] | الإشعارات | حسابي
            _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'الرئيسية',
              isActive: activeIndex == 0,
              onTap: () => _onTap(0),
            ),
            _NavItemBadge(
              icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded,
              label: 'الرسائل',
              isActive: activeIndex == 1,
              onTap: () => _onTap(1),
              badgeCount: unread,
            ),

            // Gap for the FAB notch
            const SizedBox(width: 72),

            _NavItemBadge(
              icon: Icons.notifications_none_rounded,
              activeIcon: Icons.notifications_rounded,
              label: 'الإشعارات',
              isActive: activeIndex == 3,
              onTap: () => _onTap(3),
              badgeCount: notifUnread,
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'حسابي',
              isActive: activeIndex == 4,
              onTap: () => _onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Nav Item ──────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor   = AppTheme.primaryBlue;
    const inactiveColor = AppTheme.neutralGray500;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        label: label,
        selected: isActive,
        child: SizedBox(
          width: 68,
          height: 65,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 26,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Nav Item with unread badge ─────────────────────────────────────────────────

class _NavItemBadge extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItemBadge({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor   = AppTheme.primaryBlue;
    const inactiveColor = AppTheme.neutralGray500;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        label: label,
        selected: isActive,
        child: SizedBox(
          width: 68,
          height: 65,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isActive ? activeIcon : icon,
                      key: ValueKey(isActive),
                      size: 26,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD63031),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Floating Post Button ──────────────────────────────────────────────────────

class _PostFab extends StatefulWidget {
  final VoidCallback onTap;
  const _PostFab({required this.onTap});

  @override
  State<_PostFab> createState() => _PostFabState();
}

class _PostFabState extends State<_PostFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Solid blue — matches the screenshot exactly
            color: AppTheme.primaryBlue,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: .35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
