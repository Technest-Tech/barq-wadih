import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ads/presentation/screens/ad_feed_screen.dart';
import '../../features/ads/presentation/screens/ad_detail_screen.dart';
import '../../features/ads/presentation/screens/post_ad_screen.dart';
import '../../features/ads/presentation/screens/my_ads_screen.dart';
import '../../features/ads/presentation/screens/search_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/edit_profile_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/messages/presentation/screens/conversation_screen.dart';
import '../../features/seller_profile/presentation/seller_profile_screen.dart';
import '../shell/main_shell.dart';

// ── Route paths ───────────────────────────────────────────────────────────────

abstract class AppRoutes {
  static const home       = '/';
  static const categories = '/categories';
  static const search     = '/search';
  static const login      = '/login';
  static const register   = '/register';
  static const profile    = '/profile';
  static const editProfile = '/profile/edit';
  static const adDetail      = '/ads/:id';
  static const sellerProfile = '/users/:id';
  static const postAd        = '/post-ad';
  static const myAds         = '/my-ads';
  static const notifications = '/notifications';
  static const messages      = '/messages';
  static const conversation  = '/messages/:conversationId';

  /// Helper to build ad detail path with actual id
  static String adDetailPath(int id) => '/ads/$id';

  /// Helper to build seller profile path with actual user id
  static String sellerProfilePath(int id) => '/users/$id';

  /// Helper to build conversation path with actual conversation id
  static String conversationPath(String id) => '/messages/$id';
}

// ── Protected paths: redirect to login if not authed ─────────────────────────

const _protectedPaths = <String>['/my-ads', '/post-ad', '/favorites', '/notifications', '/messages', '/profile'];

// ── Router provider ───────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: false,

    // ── Global auth redirect ───────────────────────────────────────────────
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoading = authState is AuthLoading || authState is AuthInitial;
      final isAuthed  = authState is AuthAuthenticated;
      final loc       = state.matchedLocation;
      final isAuthPg  = loc == AppRoutes.login || loc == AppRoutes.register;

      if (isLoading) return null;
      if (!isAuthed && _protectedPaths.any((p) => loc.startsWith(p))) return AppRoutes.login;
      if (isAuthed && isAuthPg) return AppRoutes.home;
      return null;
    },

    routes: [
      // ── Shell: screens with bottom nav bar ─────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const AdFeedScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.categories,
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const CategoriesScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.myAds,
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const MyAdsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.messages,
            pageBuilder: (context, state) => _noTransitionPage(
              key: state.pageKey,
              child: const MessagesScreen(),
            ),
          ),
        ],
      ),

      // ── Full-screen routes (no bottom nav) ─────────────────────────────
      GoRoute(
        path: '/ads/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return _slidePage(
            key: state.pageKey,
            child: AdDetailScreen(adId: id),
          );
        },
      ),
      GoRoute(
        path: '/users/:id',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return _slidePage(
            key: state.pageKey,
            child: SellerProfileScreen(userId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.postAd,
        pageBuilder: (context, state) {
          final adId = state.extra is int ? state.extra as int : null;
          return _modalPage(
            key: state.pageKey,
            child: PostAdScreen(adId: adId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.search,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        pageBuilder: (context, state) => _slidePage(
          key: state.pageKey,
          child: const EditProfileScreen(),
        ),
      ),
      // Sprint 8: Individual conversation
      GoRoute(
        path: AppRoutes.conversation,
        pageBuilder: (context, state) {
          final id = state.pathParameters['conversationId'] ?? '';
          return _slidePage(
            key: state.pageKey,
            child: ConversationScreen(conversationId: id),
          );
        },
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('الصفحة غير موجودة'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('الرئيسية'),
            ),
          ],
        ),
      ),
    ),
  );
});

// ── Page builder helpers ──────────────────────────────────────────────────────

/// Tab switch — instant, no animation (bottom nav feel)
CustomTransitionPage<void> _noTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, __, ___, child) => child,
  );
}

/// Push — slide from right (iOS style)
CustomTransitionPage<void> _slidePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

/// Modal — slide from bottom (post ad, sheets)
CustomTransitionPage<void> _modalPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}
