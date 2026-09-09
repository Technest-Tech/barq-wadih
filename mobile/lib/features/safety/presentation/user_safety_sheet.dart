import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../ads/data/ad_api.dart';
import '../data/user_safety_repository.dart';

Future<bool?> showUserSafetySheet(
  BuildContext context, {
  required int userId,
  required String userName,
  String? conversationId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _UserSafetySheet(
      userId: userId,
      userName: userName,
      conversationId: conversationId,
    ),
  );
}

class _UserSafetySheet extends ConsumerStatefulWidget {
  final int userId;
  final String userName;
  final String? conversationId;

  const _UserSafetySheet({
    required this.userId,
    required this.userName,
    this.conversationId,
  });

  @override
  ConsumerState<_UserSafetySheet> createState() => _UserSafetySheetState();
}

class _UserSafetySheetState extends ConsumerState<_UserSafetySheet> {
  bool _working = false;
  bool _showReport = false;
  String _reason = 'spam';
  final _details = TextEditingController();

  static const _reasons = {
    'spam': 'رسائل مزعجة أو متكررة',
    'scam_or_fraud': 'احتيال أو محاولة خداع',
    'prohibited_content': 'محتوى مسيء أو محظور',
    'inappropriate_images': 'صور غير لائقة',
    'other': 'سبب آخر',
  };

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _toggleBlock(bool currentlyBlocked) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(currentlyBlocked ? 'إلغاء الحظر' : 'حظر المستخدم'),
        content: Text(
          currentlyBlocked
              ? 'هل تريد السماح بالتواصل مع ${widget.userName} مرة أخرى؟'
              : 'سيختفي محتوى هذا المستخدم من صفحتك فورًا، وسيتم إبلاغ فريق الإشراف لمراجعة المحتوى أو السلوك غير اللائق. ولن يتمكن أي منكما من التواصل مع الآخر.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: currentlyBlocked ? Colors.blue : Colors.red,
            ),
            child: Text(currentlyBlocked ? 'إلغاء الحظر' : 'حظر'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _working = true);
    try {
      final repo = ref.read(userSafetyRepositoryProvider);
      if (currentlyBlocked) {
        await repo.unblock(widget.userId);
      } else {
        await repo.block(widget.userId, conversationId: widget.conversationId);
        ref.read(adsFeedProvider.notifier).hideSeller(widget.userId);
      }
      ref.invalidate(blockedUserIdsProvider);
      ref.invalidate(userSafetyStatusProvider(widget.userId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            currentlyBlocked
                ? 'تم إلغاء الحظر'
                : 'تم حظر المستخدم وإبلاغ فريق الإشراف. اختفى محتواه من صفحتك.',
          ),
          backgroundColor: currentlyBlocked ? null : Colors.green,
        ),
      );
      Navigator.pop(context, !currentlyBlocked);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _submitReport() async {
    setState(() => _working = true);
    try {
      await ref
          .read(userSafetyRepositoryProvider)
          .report(
            userId: widget.userId,
            reason: _reason,
            description: _details.text,
            conversationId: widget.conversationId,
          );
      if (!mounted) return;
      Navigator.pop(context, false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال البلاغ. سيراجعه فريق الإشراف خلال 24 ساعة.'),
          backgroundColor: Colors.green,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(userSafetyStatusProvider(widget.userId));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'سلامتك في برق واضح',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text('إدارة التواصل مع ${widget.userName}'),
              const SizedBox(height: 18),
              if (_showReport) ...[
                const Text(
                  'سبب البلاغ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  items: _reasons.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: _working
                      ? null
                      : (value) => setState(() => _reason = value ?? _reason),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _details,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل إضافية (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _working ? null : _submitReport,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('إرسال البلاغ'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                ),
                TextButton(
                  onPressed: _working
                      ? null
                      : () => setState(() => _showReport = false),
                  child: const Text('رجوع'),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => setState(() => _showReport = true),
                  icon: const Icon(Icons.flag_outlined, color: Colors.red),
                  label: const Text('الإبلاغ عن المستخدم'),
                ),
                const SizedBox(height: 10),
                status.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(userSafetyStatusProvider(widget.userId)),
                    child: const Text('إعادة المحاولة'),
                  ),
                  data: (value) => FilledButton.icon(
                    onPressed: _working
                        ? null
                        : () => _toggleBlock(value.isBlocked),
                    icon: Icon(
                      value.isBlocked
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                    ),
                    label: Text(
                      value.isBlocked ? 'إلغاء حظر المستخدم' : 'حظر المستخدم',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: value.isBlocked
                          ? Colors.blue
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
