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
    _Reason('fake',                '🚫 إعلان مزيف'),
    _Reason('spam',                '📢 إعلان مزعج'),
    _Reason('prohibited_content',  '⛔ محتوى محظور'),
    _Reason('wrong_category',      '📂 تصنيف خاطئ'),
    _Reason('duplicate_ad',        '📋 إعلان مكرر'),
    _Reason('scam_or_fraud',       '⚠️ احتيال'),
    _Reason('inappropriate_images','🖼️ صور غير لائقة'),
    _Reason('other',               '❓ أخرى'),
  ];

  String? _selected;
  final _descCtrl = TextEditingController();
  bool _loading   = false;
  bool _success   = false;
  String _error   = '';

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

    setState(() { _loading = true; _error = ''; });

    try {
      await ref.read(dioProvider).post<void>(
        '/ads/${widget.adId}/report',
        data: {
          'reason':      _selected,
          'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        },
      );
      setState(() => _success = true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16, left: 20, right: 20,
      ),
      child: _success ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 36),
        ),
        const SizedBox(height: 12),
        const Text('تم إرسال البلاغ',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: Color(0xFF10B981))),
        const SizedBox(height: 4),
        Text('سيتم مراجعته من قِبَل فريق الإشراف',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
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
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
              color: Color(0xFF0A1628)),
        ),
        const SizedBox(height: 16),

        // Reasons list
        ..._reasons.map((r) => _ReasonTile(
          reason: r,
          selected: _selected == r.value,
          onTap: () => setState(() => _selected = r.value),
        )),

        const SizedBox(height: 12),

        // Description field
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'تفاصيل إضافية (اختياري)',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
        ],
        const SizedBox(height: 16),

        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('إرسال البلاغ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Colors.white)),
          ),
        ),
        const SizedBox(height: 8),
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
          color: selected
              ? const Color(0xFFFEE2E2)
              : const Color(0xFFF8FAFC),
          border: Border.all(
            color: selected
                ? const Color(0xFFEF4444)
                : const Color(0xFFE2E8F0),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
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
