import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/rating_providers.dart';

class RatingSubmitSheet extends ConsumerStatefulWidget {
  const RatingSubmitSheet({
    super.key,
    required this.adId,
    required this.sellerName,
  });

  final int adId;
  final String sellerName;

  @override
  ConsumerState<RatingSubmitSheet> createState() => _RatingSubmitSheetState();
}

class _RatingSubmitSheetState extends ConsumerState<RatingSubmitSheet> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _pledge   = false;
  bool _loading  = false;
  String _error  = '';
  bool _success  = false;

  static const int _maxComment = 500;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) { setState(() => _error = 'اختر عدد النجوم'); return; }
    if (!_pledge)    { setState(() => _error = 'يجب الموافقة على التعهد'); return; }

    setState(() { _loading = true; _error = ''; });

    try {
      await ref.read(ratingRepositoryProvider).submitRating(
        adId:    widget.adId,
        stars:   _stars,
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      );
      setState(() => _success = true);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 401) {
        Navigator.of(context).pop();
        _showLoginPrompt(context);
      } else {
        final msg = e.response?.data?['message'] as String?
            ?? e.message
            ?? 'حدث خطأ، يرجى المحاولة مجدداً';
        setState(() => _error = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showLoginPrompt(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تسجيل الدخول مطلوب',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: const Text(
            'يجب تسجيل الدخول أولاً لتتمكن من كتابة تقييم.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0075C4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                ctx.push('/login');
              },
              child: const Text('تسجيل الدخول',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _success ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('شكراً لتقييمك!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF10B981),
            )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'تقييم البائع',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0A1628),
          ),
        ),
        Text(
          widget.sellerName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        // Star selector
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _stars = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      star <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      key: ValueKey<bool>(star <= _stars),
                      color: star <= _stars ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                      size: 40,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _stars == 0 ? 'اختر تقييمك'
              : _stars == 1 ? 'سيء جداً'
              : _stars == 2 ? 'سيء'
              : _stars == 3 ? 'مقبول'
              : _stars == 4 ? 'جيد'
              : 'ممتاز',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _stars > 0 ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 20),

        // Comment field
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          maxLength: _maxComment,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'شارك تجربتك مع هذا البائع (اختياري)',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            counterStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ),
        const SizedBox(height: 16),

        // Pledge checkbox
        GestureDetector(
          onTap: () => setState(() => _pledge = !_pledge),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _pledge,
                onChanged: (v) => setState(() => _pledge = v ?? false),
                activeColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'أتعهد بأن هذا التقييم صادق وعادل ويعكس تجربتي الحقيقية',
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Submit button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (_loading || _stars == 0) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A1628),
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'إرسال التقييم',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
