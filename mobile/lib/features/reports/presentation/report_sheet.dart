import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, required this.adId});
  final int adId;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  final List<_Reason> _reasons = const [
    _Reason('fake', '🚫 إعلان مزيف'),
    _Reason('spam', '📢 إعلان مزعج'),
    _Reason('prohibited_content', '⛔ محتوى محظور'),
    _Reason('wrong_category', '📂 تصنيف خاطئ'),
    _Reason('duplicate_ad', '📋 إعلان مكرر'),
    _Reason('scam_or_fraud', '⚠️ احتيال'),
    _Reason('inappropriate_images', '🖼️ صور غير لائقة'),
    _Reason('other', '❓ أخرى'),
  ];

  String? _selected;
  final _descCtrl = TextEditingController();
  bool _loading = false;
  bool _success = false;
  String _error = '';

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) {
      setState(() => _error = 'اختر سبب البلاغ');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await ref
          .read(dioProvider)
          .post<void>(
            '/ads/${widget.adId}/report',
            data: {
              'reason': _selected,
              'description': _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
            },
          );
      setState(() => _success = true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      // This screen talks to the raw dio provider, which does not map errors to
      // ApiException. Without this the sheet printed the whole DioException —
      // e.g. reporting the same ad twice showed an English stack blurb instead
      // of the server's "لقد أبلغت عن هذا الإعلان مسبقاً".
      setState(() => _error = _messageFor(e));
    } catch (_) {
      setState(() => _error = 'تعذر إرسال البلاغ. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Prefer the API's own Arabic message; fall back to a plain sentence so the
  /// user never sees a transport-level dump.
  String _messageFor(DioException e) {
    // Reporting requires an account; the API answers 401 with an English
    // framework string that would look broken inside this Arabic sheet.
    if (e.response?.statusCode == 401) {
      return 'سجّل الدخول أولاً لإرسال البلاغ.';
    }

    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'تعذر الاتصال بالشبكة. تحقق من اتصالك وحاول مرة أخرى.';
    }
    return 'تعذر إرسال البلاغ. حاول مرة أخرى.';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: SizedBox(
          height: availableHeight * 0.9,
          child: _success ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x2610B981),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF10B981),
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'تم إرسال البلاغ',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF10B981),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'سيتم مراجعته من قِبَل فريق الإشراف',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'الإبلاغ عن الإعلان',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A1628),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              ..._reasons.map(
                (r) => _ReasonTile(
                  reason: r,
                  selected: _selected == r.value,
                  onTap: () => setState(() => _selected = r.value),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descCtrl,
                minLines: 2,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'تفاصيل إضافية (اختياري)',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'إرسال البلاغ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Reason {
  final String value;
  final String label;
  const _Reason(this.value, this.label);
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final _Reason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
          border: Border.all(
            color: selected ? const Color(0xFFEF4444) : const Color(0xFFE2E8F0),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF94A3B8),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                reason.label,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 14,
                  color: selected
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF0A1628),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
