// lib/shared/widgets/share_account_sheet.dart
//
// "مشاركة الحساب" — the share dialog behind the QR button on a profile.
// Shows the account's identity, its canonical @handle link (copyable), a QR
// code for scanning in person, and one-tap hand-offs to the messaging apps
// people actually use here.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

// ── Public API ────────────────────────────────────────────────────────────────

/// Everything the sheet needs to render one account.
class ShareAccountData {
  final String name;

  /// Public @handle without the leading "@". Null for pre-handle accounts,
  /// in which case only the link and QR are shown.
  final String? username;

  final String? avatarUrl;

  /// Canonical profile link. Always absolute.
  final String profileUrl;

  const ShareAccountData({
    required this.name,
    required this.profileUrl,
    this.username,
    this.avatarUrl,
  });
}

/// Opens the share dialog. Returns once it is dismissed.
Future<void> showShareAccountSheet(
  BuildContext context, {
  required ShareAccountData account,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .45),
    builder: (_) => _ShareAccountDialog(account: account),
  );
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _ShareAccountDialog extends StatelessWidget {
  final ShareAccountData account;
  const _ShareAccountDialog({required this.account});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(),
                const SizedBox(height: 8),
                _Identity(account: account),
                const SizedBox(height: 16),
                _LinkRow(url: account.profileUrl),
                const SizedBox(height: 20),
                _QrCard(url: account.profileUrl),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppTheme.neutralGray200),
                const SizedBox(height: 16),
                _ShareTargets(account: account),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Leading in RTL sits on the right; the close button belongs on the
        // left, matching the reference layout.
        const Spacer(),
        const Text(
          'مشاركة الحساب',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryBlue,
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.close_rounded),
              color: AppTheme.neutralGray800,
              tooltip: 'إغلاق',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  final ShareAccountData account;
  const _Identity({required this.account});

  @override
  Widget build(BuildContext context) {
    final avatar = account.avatarUrl;

    return Column(
      children: [
        CircleAvatar(
          radius: 38,
          backgroundColor: AppTheme.neutralGray200,
          backgroundImage: avatar != null && avatar.isNotEmpty
              ? CachedNetworkImageProvider(
                  AppConstants.normalizeImageUrl(avatar),
                )
              : null,
          child: avatar == null || avatar.isEmpty
              ? const Icon(Icons.person, size: 42, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          account.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.neutralGray900,
          ),
        ),
        if (account.username != null) ...[
          const SizedBox(height: 2),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '@${account.username}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlueLight,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String url;
  const _LinkRow({required this.url});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط الحساب'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _copy(context),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  AppConstants.displayUrl(url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.copy,
              size: 18,
              color: AppTheme.neutralGray600,
            ),
          ],
        ),
      ),
    );
  }
}

class _QrCard extends StatelessWidget {
  final String url;
  const _QrCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: QrImageView(
        data: url,
        version: QrVersions.auto,
        size: 172,
        backgroundColor: AppTheme.primaryBlue,
        // High correction keeps the code scannable despite the rounded modules.
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.white,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Share targets ─────────────────────────────────────────────────────────────

class _ShareTargets extends StatelessWidget {
  final ShareAccountData account;
  const _ShareTargets({required this.account});

  /// Text handed to apps that accept a message rather than a bare link.
  String get _message => '${account.name}\n${account.profileUrl}';

  @override
  Widget build(BuildContext context) {
    final targets = <_ShareTarget>[
      _ShareTarget(
        label: 'واتساب',
        icon: LucideIcons.phone,
        background: const Color(0xFF25D366),
        uri: Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_message)}'),
      ),
      _ShareTarget(
        label: 'اكس',
        icon: LucideIcons.x,
        background: const Color(0xFF000000),
        uri: Uri.parse(
          'https://x.com/intent/post'
          '?text=${Uri.encodeComponent(account.name)}'
          '&url=${Uri.encodeComponent(account.profileUrl)}',
        ),
      ),
      _ShareTarget(
        label: 'سناب',
        icon: LucideIcons.ghost,
        background: const Color(0xFFFFFC00),
        foreground: AppTheme.neutralGray900,
        uri: Uri.parse(
          'https://www.snapchat.com/scan'
          '?attachmentUrl=${Uri.encodeComponent(account.profileUrl)}',
        ),
      ),
      _ShareTarget(
        label: 'انستقرام',
        icon: LucideIcons.instagram,
        background: const Color(0xFFC13584),
        // Instagram has no link-share intent, so copy the link and open the
        // app — the same compromise every other app makes here.
        copyFirst: true,
        uri: Uri.parse('instagram://app'),
      ),
      _ShareTarget(
        label: 'فيسبوك',
        icon: LucideIcons.facebook,
        background: const Color(0xFF1877F2),
        uri: Uri.parse(
          'https://www.facebook.com/sharer/sharer.php'
          '?u=${Uri.encodeComponent(account.profileUrl)}',
        ),
      ),
      _ShareTarget(
        label: 'ماسنجر',
        icon: LucideIcons.messageCircle,
        background: const Color(0xFF0084FF),
        uri: Uri.parse(
          'fb-messenger://share?link=${Uri.encodeComponent(account.profileUrl)}',
        ),
      ),
      _ShareTarget(
        label: 'المزيد',
        icon: LucideIcons.share2,
        background: AppTheme.neutralGray600,
        // No uri — always falls through to the system share sheet.
      ),
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: targets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) => _ShareTargetButton(
          target: targets[i],
          onFallback: () => _systemShare(context),
          message: _message,
        ),
      ),
    );
  }

  Future<void> _systemShare(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await Share.share(
        _message,
        subject: account.name,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      // No share targets at all — the clipboard is the last resort.
      await Clipboard.setData(ClipboardData(text: account.profileUrl));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم نسخ رابط الحساب'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _ShareTarget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Uri? uri;

  /// Put the link on the clipboard before opening the app — for targets that
  /// can't accept a link through their URL scheme.
  final bool copyFirst;

  const _ShareTarget({
    required this.label,
    required this.icon,
    required this.background,
    this.foreground = Colors.white,
    this.uri,
    this.copyFirst = false,
  });
}

class _ShareTargetButton extends StatelessWidget {
  final _ShareTarget target;
  final Future<void> Function() onFallback;
  final String message;

  const _ShareTargetButton({
    required this.target,
    required this.onFallback,
    required this.message,
  });

  Future<void> _open(BuildContext context) async {
    final uri = target.uri;

    if (uri == null) {
      await onFallback();
      return;
    }

    if (target.copyFirst) {
      await Clipboard.setData(ClipboardData(text: message));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ الرابط — الصقه في تطبيق انستقرام'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // App not installed, or the scheme isn't queryable on this platform.
    }

    await onFallback();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: target.background,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _open(context),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(target.icon, color: target.foreground, size: 25),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            target.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.neutralGray700,
            ),
          ),
        ],
      ),
    );
  }
}
