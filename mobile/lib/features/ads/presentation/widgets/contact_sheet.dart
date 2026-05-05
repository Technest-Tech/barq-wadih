import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messages/data/chat_providers.dart';

/// Bottom sheet shown from an ad's "تواصل" button. Mirrors the web
/// `ContactModal`: phone-call shortcut + in-app chat composer with an editable
/// opening message. Sending creates/finds the conversation, posts the message,
/// then navigates the user to the chat thread.
class ContactSheet extends ConsumerStatefulWidget {
  const ContactSheet({
    super.key,
    required this.adId,
    required this.sellerName,
    required this.phone,
  });

  final int adId;
  final String sellerName;
  final String phone;

  static Future<void> show(
    BuildContext context, {
    required int adId,
    required String sellerName,
    required String phone,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactSheet(
        adId: adId,
        sellerName: sellerName,
        phone: phone,
      ),
    );
  }

  @override
  ConsumerState<ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<ContactSheet> {
  static const _defaultDraft = 'السلام عليكم، هل السلعة متاحة؟';

  late final TextEditingController _ctrl =
      TextEditingController(text: _defaultDraft);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _callPhone() async {
    final uri = Uri(scheme: 'tel', path: widget.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _sendChat() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      Navigator.of(context).pop();
      // ignore: use_build_context_synchronously
      context.push(AppRoutes.login);
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final repo   = ref.read(chatRepositoryProvider);
      final convId = await repo.startConversation(
        adId:           widget.adId,
        myId:           user.id.toString(),
        initialMessage: text,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      context.push(AppRoutes.conversationPath(convId));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذّر إرسال الرسالة، حاول مرة أخرى';
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: EdgeInsets.only(bottom: viewInsets),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          top: false,
          // When keyboard is open, viewInsets covers the safe area — adding
          // bottom padding again would double-consume space and cause overflow.
          bottom: viewInsets == 0,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 12),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF3FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.message_rounded,
                              color: Color(0xFF1B4FE4), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تواصل مع العارض',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A1628),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.sellerName,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Phone option
                    if (widget.phone.isNotEmpty)
                      InkWell(
                        onTap: _callPhone,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16A34A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.phone, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'اتصال مباشر',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0A1628),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        widget.phone,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF16A34A),
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_left, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                    if (widget.phone.isNotEmpty) const SizedBox(height: 10),

                    // Composer card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1B4FE4), Color(0xFF1340C5)],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.chat_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'مراسلة عبر برق واضح',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0A1628),
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'تواصل آمن داخل المنصة',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _ctrl,
                            maxLines: 4,
                            minLines: 3,
                            textAlign: TextAlign.right,
                            enabled: !_sending,
                            inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                            decoration: InputDecoration(
                              hintText: 'اكتب رسالتك للبائع…',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
                              filled: true,
                              fillColor: const Color(0xFFF5F6F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey[200]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF1B4FE4), width: 1.4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Text(
                                _error!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _ctrl,
                            builder: (_, value, __) {
                              final canSend = value.text.trim().isNotEmpty && !_sending;
                              return SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: canSend ? _sendChat : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B4FE4),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey[300],
                                    elevation: canSend ? 4 : 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: _sending
                                      ? const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.send_rounded, size: 18),
                                  label: const Text(
                                    'إرسال',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '⚠️ لا تُرسل أموالاً مسبقاً ولا تشارك بياناتك البنكية قبل استلام البضاعة.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),  // SingleChildScrollView
        ),  // SafeArea
      ),    // Container
    );
  }
}
