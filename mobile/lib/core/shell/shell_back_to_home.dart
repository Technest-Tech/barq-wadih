import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Back handling for the bottom-nav tabs other than home.
///
/// Must be mounted *inside* the shell Navigator (i.e. as a page child), not in
/// [MainShell]: a `PopScope` in the shell builder registers on the root
/// Navigator, which Android's predictive back never consults while a shell tab
/// is the innermost route — the Activity just finishes and the app exits.
///
/// When the tab was reached with `context.go` it is the shell's only page, so
/// there is nothing to pop and back returns to the home tab. When it was pushed
/// (e.g. the home sidebar), the normal pop applies.
class ShellBackToHome extends StatelessWidget {
  final Widget child;
  const ShellBackToHome({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/');
      },
      child: child,
    );
  }
}
