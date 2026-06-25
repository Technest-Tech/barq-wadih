import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shows a premium "هل تريد الخروج؟" exit-confirmation dialog.
///
/// Returns `true` only when the user confirms exit. Used by the home shell and
/// the search screen so the back-button exit flow is identical everywhere.
Future<bool> showExitConfirmDialog(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'هل تريد الخروج؟',
    barrierColor: Colors.black.withValues(alpha: .55),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, __, ___) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.scale(
          // easeOutBack overshoots slightly past 1.0 for a subtle premium pop.
          scale: 0.9 + (0.1 * curved.value),
          child: const _ExitConfirmDialog(),
        ),
      );
    },
  );
  return result == true;
}

class _ExitConfirmDialog extends StatelessWidget {
  const _ExitConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withValues(alpha: .18),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Iconic header ─────────────────────────────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accentGold.withValues(alpha: .18),
                      AppTheme.accentGold.withValues(alpha: .08),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.accentGold,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),

              // ── Title ─────────────────────────────────────────────────────
              const Text(
                'هل تريد الخروج؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.neutralGray900,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),

              // ── Subtitle ──────────────────────────────────────────────────
              const Text(
                'سيتم إغلاق التطبيق، هل أنت متأكد؟',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.neutralGray500,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),

              // ── Actions ───────────────────────────────────────────────────
              Row(
                children: [
                  // Stay (cancel)
                  Expanded(
                    child: _DialogButton(
                      label: 'البقاء',
                      filled: false,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Exit (confirm)
                  Expanded(
                    child: _DialogButton(
                      label: 'خروج',
                      filled: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppTheme.primaryBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: filled
                ? null
                : Border.all(color: AppTheme.neutralGray200, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : AppTheme.neutralGray700,
            ),
          ),
        ),
      ),
    );
  }
}
