import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/services/app_update_service.dart';
import 'core/widgets/app_update_dialog.dart';
import 'core/services/marketing_tracking_service.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/data/notification_providers.dart';
import 'features/settings/providers/theme_provider.dart';
import 'features/settings/providers/locale_provider.dart';

/// Root application widget.
class BarqWadihApp extends ConsumerStatefulWidget {
  const BarqWadihApp({super.key});

  @override
  ConsumerState<BarqWadihApp> createState() => _BarqWadihAppState();
}

class _BarqWadihAppState extends ConsumerState<BarqWadihApp>
    with WidgetsBindingObserver {
  final _updates = AppUpdateService();
  bool _updateDialogOpen = false;
  AppUpdate? _pendingUpdate;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listen for notification taps (background / local) and navigate.
    FCMService.pendingRoute.addListener(_onPendingRoute);
    // A push that lands while the app is open must move the bell badge right
    // away, not on the next accidental rebuild.
    FCMService.inboundPush.addListener(_onInboundPush);
    // Check if the app was opened from a terminated-state notification tap.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_checkForUpdate());
      unawaited(ref.read(marketingTrackingProvider).initialize());
      try {
        await FCMService.instance.checkInitialMessage();
      } catch (_) {
        // Firebase is initialized during production bootstrap. Keeping the
        // root widget resilient also lets previews/tests render without it.
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FCMService.pendingRoute.removeListener(_onPendingRoute);
    FCMService.inboundPush.removeListener(_onInboundPush);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_checkForUpdate());
    // Notifications may have been read on another device — or arrived while
    // this one was backgrounded — so re-sync the bell and the icon badge.
    unawaited(refreshUnreadNotifications(ref));
  }

  void _onInboundPush() {
    unawaited(refreshUnreadNotifications(ref));
  }

  Future<void> _checkForUpdate() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.android) ||
        _updateDialogOpen) {
      return;
    }
    final update = _pendingUpdate ?? await _updates.check();
    if (!mounted || update == null || _updateDialogOpen) return;
    _pendingUpdate = update;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    final navigatorContext = ref
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (navigatorContext == null || !navigatorContext.mounted) return;
    _updateDialogOpen = true;
    _pendingUpdate = null;
    try {
      await showDialog<void>(
        context: navigatorContext,
        builder: (_) => AppUpdateDialog(update: update),
      );
      await _updates.remindTomorrow();
    } finally {
      _updateDialogOpen = false;
    }
  }

  void _onPendingRoute() {
    final route = FCMService.pendingRoute.value;
    if (route == null) return;
    FCMService.pendingRoute.value = null;
    ref.read(appRouterProvider).go(route);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(appRouterProvider);

    final isDark = themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'برق واضح',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Routing
      routerConfig: router,

      // Localizations
      locale: locale,
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
