import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/question_providers.dart';
import '../../domain/question_model.dart';

const _kBrandBlue = Color(0xFF0075C4);

/// Comments on an ad — anyone signed in may ask, and the seller answers.
///
/// Mirrors the questions & answers section the website shows on ad pages, and
/// is backed by the same `/ads/{id}/questions` endpoints.
class AdCommentsSection extends ConsumerStatefulWidget {
  final int adId;

  /// Owner of the ad — only they get the reply affordance.
  final int? sellerId;

  const AdCommentsSection({super.key, required this.adId, this.sellerId});

  @override
  ConsumerState<AdCommentsSection> createState() => _AdCommentsSectionState();
}

class _AdCommentsSectionState extends ConsumerState<AdCommentsSection> {
  static const int _maxBody = 1000;

  final _commentCtrl = TextEditingController();
  bool _commentSubmitting = false;
  String? _commentError;
  bool _commentSuccess = false;

  int? _replyingTo;
  final _replyCtrl = TextEditingController();
  bool _replySubmitting = false;
  String? _replyError;

  @override
  void dispose() {
    _commentCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _commentSubmitting) return;

    if (ref.read(currentUserProvider) == null) {
      _showLoginPrompt('يجب تسجيل الدخول أولاً لتتمكن من إضافة تعليق.');
      return;
    }

    setState(() {
      _commentSubmitting = true;
      _commentError = null;
      _commentSuccess = false;
    });

    try {
      await ref
          .read(questionRepositoryProvider)
          .postQuestion(adId: widget.adId, body: body);
      if (!mounted) return;
      _commentCtrl.clear();
      FocusScope.of(context).unfocus();
      setState(() => _commentSuccess = true);
      ref.invalidate(adQuestionsProvider(widget.adId));
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        _showLoginPrompt('يجب تسجيل الدخول أولاً لتتمكن من إضافة تعليق.');
      } else {
        setState(() => _commentError = _apiError(e));
      }
    } finally {
      if (mounted) setState(() => _commentSubmitting = false);
    }
  }

  Future<void> _submitReply(int questionId) async {
    final body = _replyCtrl.text.trim();
    if (body.isEmpty || _replySubmitting) return;

    setState(() {
      _replySubmitting = true;
      _replyError = null;
    });

    try {
      await ref
          .read(questionRepositoryProvider)
          .postReply(questionId: questionId, body: body);
      if (!mounted) return;
      _replyCtrl.clear();
      FocusScope.of(context).unfocus();
      setState(() => _replyingTo = null);
      ref.invalidate(adQuestionsProvider(widget.adId));
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        _showLoginPrompt('يجب تسجيل الدخول أولاً لتتمكن من الرد.');
      } else {
        setState(() => _replyError = _apiError(e));
      }
    } finally {
      if (mounted) setState(() => _replySubmitting = false);
    }
  }

  void _openReplyBox(int questionId) {
    setState(() {
      _replyingTo = questionId;
      _replyError = null;
      _replyCtrl.clear();
    });
  }

  bool _isUnauthorized(Object e) =>
      e is DioException && e.response?.statusCode == 401;

  String _apiError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
        final message = data['message'];
        if (message is String && message.isNotEmpty) return message;
      }
      return e.message ?? 'حدث خطأ، يرجى المحاولة مجدداً';
    }
    return 'حدث خطأ، يرجى المحاولة مجدداً';
  }

  void _showLoginPrompt(String message) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'تسجيل الدخول مطلوب',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Text(message, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrandBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                context.push('/login');
              },
              child: const Text(
                'تسجيل الدخول',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(adQuestionsProvider(widget.adId));
    final currentUser = ref.watch(currentUserProvider);
    final isSeller =
        widget.sellerId != null && currentUser?.id == widget.sellerId;

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.forum_outlined,
                color: _kBrandBlue,
                size: 20,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'الأسئلة والاستفسارات',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.neutralGray800,
                  ),
                ),
              ),
              if (questionsAsync.hasValue)
                Text(
                  '${questionsAsync.value!.length} سؤال',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.neutralGray500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Comment list
          questionsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: _kBrandBlue,
                  strokeWidth: 2,
                ),
              ),
            ),
            error: (e, _) => Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'تعذر تحميل الأسئلة',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(adQuestionsProvider(widget.adId)),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
            data: (questions) {
              if (questions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لا توجد أسئلة بعد، كن أول من يسأل!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: questions
                    .map(
                      (q) => _CommentCard(
                        question: q,
                        sellerId: widget.sellerId,
                        canReply: isSeller,
                        isReplying: _replyingTo == q.id,
                        replyController: _replyCtrl,
                        replySubmitting: _replySubmitting,
                        replyError: _replyingTo == q.id ? _replyError : null,
                        maxBody: _maxBody,
                        onOpenReply: () => _openReplyBox(q.id),
                        onCancelReply: () =>
                            setState(() => _replyingTo = null),
                        onSubmitReply: () => _submitReply(q.id),
                      ),
                    )
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 8),

          // New comment composer
          _CommentComposer(
            controller: _commentCtrl,
            submitting: _commentSubmitting,
            error: _commentError,
            success: _commentSuccess,
            maxBody: _maxBody,
            onChanged: () {
              if (_commentSuccess || _commentError != null) {
                setState(() {
                  _commentSuccess = false;
                  _commentError = null;
                });
              }
            },
            onSubmit: _submitComment,
          ),
        ],
      ),
    );
  }
}

// ── Comment card ──────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  final QuestionModel question;
  final int? sellerId;
  final bool canReply;
  final bool isReplying;
  final TextEditingController replyController;
  final bool replySubmitting;
  final String? replyError;
  final int maxBody;
  final VoidCallback onOpenReply;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmitReply;

  const _CommentCard({
    required this.question,
    required this.sellerId,
    required this.canReply,
    required this.isReplying,
    required this.replyController,
    required this.replySubmitting,
    required this.replyError,
    required this.maxBody,
    required this.onOpenReply,
    required this.onCancelReply,
    required this.onSubmitReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentHeader(
            name: question.user.name,
            avatar: question.user.avatar,
            createdAt: question.createdAt,
            isSeller: sellerId != null && question.user.id == sellerId,
            radius: 16,
          ),
          const SizedBox(height: 10),
          Text(
            question.body,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),

          // Replies
          if (question.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsetsDirectional.only(start: 12),
              decoration: const BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: Color(0xFFE2E8F0), width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: question.replies
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CommentHeader(
                              name: r.user.name,
                              avatar: r.user.avatar,
                              createdAt: r.createdAt,
                              isSeller:
                                  sellerId != null && r.user.id == sellerId,
                              radius: 13,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r.body,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475569),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          // Reply affordance — the seller only
          if (canReply) ...[
            const SizedBox(height: 8),
            if (isReplying)
              _ReplyForm(
                controller: replyController,
                submitting: replySubmitting,
                error: replyError,
                maxBody: maxBody,
                onSubmit: onSubmitReply,
                onCancel: onCancelReply,
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpenReply,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _kBrandBlue,
                  ),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text(
                    'رد',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Comment header (avatar · name · badge · time) ─────────────────────────────

class _CommentHeader extends StatelessWidget {
  final String name;
  final String? avatar;
  final DateTime createdAt;
  final bool isSeller;
  final double radius;

  const _CommentHeader({
    required this.name,
    required this.avatar,
    required this.createdAt,
    required this.isSeller,
    required this.radius,
  });

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
    if (diff.inDays < 365) return 'منذ ${(diff.inDays / 30).floor()} شهر';
    return 'منذ ${(diff.inDays / 365).floor()} سنة';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: _kBrandBlue,
          backgroundImage: avatar != null
              ? NetworkImage(AppConstants.normalizeImageUrl(avatar!))
              : null,
          child: avatar == null
              ? Text(
                  name.isNotEmpty ? name[0] : '؟',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * .8,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.neutralGray800,
                      ),
                    ),
                  ),
                  if (isSeller) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _kBrandBlue.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'البائع',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _kBrandBlue,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                _timeAgo(createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.neutralGray500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Inline reply form ─────────────────────────────────────────────────────────

class _ReplyForm extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final String? error;
  final int maxBody;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _ReplyForm({
    required this.controller,
    required this.submitting,
    required this.error,
    required this.maxBody,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          maxLines: 2,
          maxLength: maxBody,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          enabled: !submitting,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'اكتب ردك هنا...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: AppTheme.neutralGray500,
            ),
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: .3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: .3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kBrandBlue),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(fontSize: 12, color: AppTheme.colorError),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrandBlue,
                disabledBackgroundColor: AppTheme.neutralGray300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'إرسال الرد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: submitting ? null : onCancel,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.neutralGray600,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
              ),
              child: const Text('إلغاء', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
      ],
    );
  }
}

// ── New comment composer ──────────────────────────────────────────────────────

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final String? error;
  final bool success;
  final int maxBody;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  const _CommentComposer({
    required this.controller,
    required this.submitting,
    required this.error,
    required this.success,
    required this.maxBody,
    required this.onChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: .15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اكتب سؤالك للعارض',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.neutralGray800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: 3,
            maxLength: maxBody,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            enabled: !submitting,
            onChanged: (_) => onChanged(),
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ما الذي تريد معرفته عن هذا الإعلان؟',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppTheme.neutralGray500,
              ),
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: .3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: .3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBrandBlue),
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: const TextStyle(fontSize: 12, color: AppTheme.colorError),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton(
                onPressed: submitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBrandBlue,
                  disabledBackgroundColor: AppTheme.neutralGray300,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'إرسال',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.send, size: 15, color: Colors.white),
                        ],
                      ),
              ),
              if (success) ...[
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    '✓ تم إرسال سؤالك',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.colorSuccess,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
