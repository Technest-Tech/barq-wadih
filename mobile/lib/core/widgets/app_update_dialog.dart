import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({super.key, required this.update, this.openStore});
  final AppUpdate update;
  final Future<bool> Function(Uri)? openStore;

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _opening = false;
  bool _failed = false;

  Future<void> _open() async {
    setState(() {
      _opening = true;
      _failed = false;
    });
    var opened = false;
    try {
      opened =
          await (widget.openStore?.call(widget.update.storeUrl) ??
              launchUrl(
                widget.update.storeUrl,
                mode: LaunchMode.externalApplication,
              ));
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _opening = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final store = widget.update.storeUrl.host == 'play.google.com'
        ? 'Google Play'
        : 'App Store';
    final versionText = widget.update.version.isEmpty
        ? (ar ? 'يتوفر إصدار جديد.' : 'A new version is available.')
        : (ar
              ? 'الإصدار ${widget.update.version} متاح الآن.'
              : 'Version ${widget.update.version} is available.');
    return AlertDialog(
      scrollable: true,
      title: Text(ar ? 'يتوفر تحديث جديد' : 'Update available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ar
                ? '$versionText يمكنك تحديث برق واضح من $store أو المتابعة والتحديث لاحقًا.'
                : '$versionText Update Barq Wadih in $store, or continue and update later.',
          ),
          if (_failed) ...[
            const SizedBox(height: 16),
            Text(
              ar
                  ? 'تعذّر فتح المتجر. حاول مجددًا أو افتح $store لتحديث برق واضح.'
                  : 'Could not open the store. Try again or open $store to update Barq Wadih.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ar ? 'لاحقًا' : 'Later'),
        ),
        FilledButton(
          onPressed: _opening ? null : _open,
          child: Text(
            _opening
                ? (ar ? 'جارٍ فتح المتجر…' : 'Opening store…')
                : (ar ? 'تحديث الآن' : 'Update now'),
          ),
        ),
      ],
    );
  }
}
