import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';

/// Application bootstrap — initialises dependencies, sets up error handling,
/// then launches the widget tree.
///
/// By extracting this from `main.dart` we can:
/// - Add DI initialisation (Hive, secure storage, etc.)
/// - Configure global error handlers
/// - Add performance monitoring
/// - Keep `main.dart` as a one-liner entry point
Future<void> bootstrap() async {
  // Preserve the native splash while we initialise — removes it as soon as
  // Flutter is ready to paint, with zero white-screen flash.
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // ── Firebase ───────────────────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Remove the native splash NOW — Flutter takes over immediately
  FlutterNativeSplash.remove();

  // ── Orientation lock ──────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Status bar style for splash ───────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // ── Global error handling ─────────────────────────────────────────────────
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      // TODO: Send to crash reporting service (Sentry / Firebase Crashlytics)
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled platform error: $error');
    debugPrint(stack.toString());
    return true;
  };

  // ── Initialise local storage ──────────────────────────────────────────────
  // await Hive.initFlutter();

  // ── Launch app ────────────────────────────────────────────────────────────
  runApp(
    const ProviderScope(
      child: BarqWadihApp(),
    ),
  );
}
