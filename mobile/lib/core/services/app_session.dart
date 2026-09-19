import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the user has asked to leave the app, so the next time it
/// comes back to the foreground can be treated as a fresh start.
///
/// `SystemNavigator.pop()` is not a guaranteed process kill: iOS only suspends
/// the app, and Android may hand the very same task back on the next launcher
/// tap. Either way the user reopens the app exactly where they left it —
/// halfway down a stale ad feed — instead of on a freshly loaded home. The exit
/// is recorded here and [BarqWadihApp] rebuilds the home state by hand on the
/// following resume. When the process really is killed the flag dies with it,
/// which is harmless: that launch starts from home anyway.
class AppSession {
  AppSession._();

  static bool _restartPending = false;

  /// Close the app the way the confirm dialog promises, and remember that the
  /// next foreground must land on a clean home feed.
  static Future<void> exitApp() async {
    _restartPending = true;
    await SystemNavigator.pop();
  }

  /// True once per exit — reading it clears the flag so an ordinary resume
  /// (app switcher, incoming call, notification) keeps the user in place.
  static bool consumeRestart() {
    final restart = _restartPending;
    _restartPending = false;
    return restart;
  }
}

/// Bumped every time the app restarts into a fresh session. Screens holding
/// local state the providers know nothing about — scroll offsets, filter chips,
/// the search field — reset themselves when this changes.
final appResetSignalProvider = NotifierProvider<AppResetSignal, int>(
  AppResetSignal.new,
);

class AppResetSignal extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
