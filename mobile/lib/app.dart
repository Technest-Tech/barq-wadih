import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router/app_router.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/theme_provider.dart';
import 'features/settings/providers/locale_provider.dart';

/// Root application widget.
class BarqWadihApp extends ConsumerStatefulWidget {
  const BarqWadihApp({super.key});

  @override
  ConsumerState<BarqWadihApp> createState() => _BarqWadihAppState();
}

class _BarqWadihAppState extends ConsumerState<BarqWadihApp> {
  @override
  void initState() {
    super.initState();
    // Listen for notification taps (background / local) and navigate.
    FCMService.pendingRoute.addListener(_onPendingRoute);
    // Check if the app was opened from a terminated-state notification tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FCMService.instance.checkInitialMessage();
    });
  }

  @override
  void dispose() {
    FCMService.pendingRoute.removeListener(_onPendingRoute);
    super.dispose();
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
    final locale    = ref.watch(localeProvider);
    final router    = ref.watch(appRouterProvider);

    final isDark = themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp.router(
      title: 'Barq Wadih',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Routing
      routerConfig: router,

      // Localizations
      locale: locale,
      supportedLocales: const [
        Locale('ar', 'SA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

