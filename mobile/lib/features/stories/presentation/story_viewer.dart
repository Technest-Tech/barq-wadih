// lib/features/stories/presentation/story_viewer.dart
//
// Full-screen story viewer — Instagram/Snapchat style.
// Tap left half → previous. Tap right half → next.
// Hold → pause. Release → resume.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/story_model.dart';
import '../../../core/theme/app_theme.dart';

class StoryViewer extends StatefulWidget {
  final List<StoryItem> stories;
  final int initialIndex;

  const StoryViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _controller;
  static const _duration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _goNext();
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _controller
      ..duration = _duration
      ..reset()
      ..forward();
  }

  void _goNext() {
    if (!mounted) return;
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _restartTimer();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goPrev() {
    if (!mounted) return;
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _restartTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [

            // ── 1. Background image ────────────────────────────────────────
            _Background(story: story),

            // ── 2. Top gradient shadow ─────────────────────────────────────
            _TopGradient(),

            // ── 3. Bottom gradient shadow ──────────────────────────────────
            _BottomGradient(),

            // ── 4. Left / right tap zones ──────────────────────────────────
            _TapZones(
              onLeft: _goPrev,
              onRight: _goNext,
              onHoldStart: () => _controller.stop(),
              onHoldEnd: () => _controller.forward(),
            ),

            // ── 5. Progress bars ───────────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Row(
                    children: List.generate(widget.stories.length, (i) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (_, __) => _ProgressBar(
                              value: i < _currentIndex
                                  ? 1.0
                                  : i == _currentIndex
                                      ? _controller.value
                                      : 0.0,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

            // ── 6. Top bar: avatar + name + time + close ───────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 26, 4, 0),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: story.ownerAvatarUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: story.ownerAvatarUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _InitialAvatar(name: story.ownerName),
                                )
                              : _InitialAvatar(name: story.ownerName),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              story.ownerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                shadows: [
                                  Shadow(blurRadius: 6, color: Colors.black54),
                                ],
                              ),
                            ),
                            Text(
                              _timeAgo(story.createdAt),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 7. Bottom info card ────────────────────────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: SafeArea(
                top: false,
                child: _BottomCard(story: story),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }
}

// ── Bottom info card ─────────────────────────────────────────────────────────

class _BottomCard extends StatelessWidget {
  final StoryItem story;
  const _BottomCard({required this.story});

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Category badge + title ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Category chip
                  if (story.adCategory != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.accentGold.withValues(alpha: .5)),
                      ),
                      child: Text(
                        story.adCategory!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    story.title,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.neutralGray900,
                      height: 1.3,
                    ),
                  ),

                  // Description
                  if (story.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      story.description!,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.neutralGray600,
                        height: 1.45,
                      ),
                    ),
                  ],

                  // Price
                  if (story.price != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      story.price!,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.colorSuccess,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1, color: AppTheme.neutralGray100),

            // ── Seller row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  // Seller avatar small
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.primaryBlue,
                    child: Icon(Icons.person_rounded,
                        size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.ownerName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.neutralGray800,
                          ),
                        ),
                        const Text(
                          'البائع',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.neutralGray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Verified badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 12, color: AppTheme.colorSuccess),
                        SizedBox(width: 3),
                        Text('موثّق',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.colorSuccess,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Contact buttons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Row(
                children: [
                  // WhatsApp button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (story.contactPhone != null) {
                          _whatsapp(story.contactPhone!);
                        }
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'واتساب',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Call button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (story.contactPhone != null) {
                        _call(story.contactPhone!);
                      }
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.phone_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tap zone widget ─────────────────────────────────────────────────────────

class _TapZones extends StatelessWidget {
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  const _TapZones({
    required this.onLeft,
    required this.onRight,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onLeft,
            onLongPressStart: (_) => onHoldStart(),
            onLongPressEnd: (_) => onHoldEnd(),
            child: const SizedBox.expand(),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRight,
            onLongPressStart: (_) => onHoldStart(),
            onLongPressEnd: (_) => onHoldEnd(),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

// ── Gradients ────────────────────────────────────────────────────────────────

class _TopGradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      height: MediaQuery.of(context).size.height * 0.28,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xBB000000), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _BottomGradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      height: MediaQuery.of(context).size.height * 0.50,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

// ── Progress bar ─────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double value;
  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 2.5,
        backgroundColor: Colors.white30,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}

// ── Background image ─────────────────────────────────────────────────────────

class _Background extends StatelessWidget {
  final StoryItem story;
  const _Background({required this.story});

  @override
  Widget build(BuildContext context) {
    if (story.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: story.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(color: Colors.black87),
        errorWidget: (_, __, ___) => _Fallback(emoji: story.adCategory),
      );
    }
    return _Fallback(emoji: story.adCategory);
  }
}

class _Fallback extends StatelessWidget {
  final String? emoji;
  const _Fallback({this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.primaryBlue, Color(0xFF0a1628)],
        ),
      ),
      alignment: Alignment.center,
      child: Text(emoji ?? '📦', style: const TextStyle(fontSize: 100)),
    );
  }
}

// ── Avatar initials ───────────────────────────────────────────────────────────

class _InitialAvatar extends StatelessWidget {
  final String name;
  const _InitialAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primaryBlue,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '؟',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      ),
    );
  }
}
