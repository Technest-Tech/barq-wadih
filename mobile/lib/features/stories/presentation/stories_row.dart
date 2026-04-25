// lib/features/stories/presentation/stories_row.dart
//
// Horizontal scrolling stories strip — shown at the very top of the ad feed.
// First bubble = "Add Story" button. Then story circles with gradient/gray ring.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/stories_provider.dart';
import '../domain/story_model.dart';
import '../presentation/story_viewer.dart';
import '../../../core/theme/app_theme.dart';

class StoriesRow extends ConsumerStatefulWidget {
  const StoriesRow({super.key});

  @override
  ConsumerState<StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends ConsumerState<StoriesRow> {
  final Set<int> _seenIds = {};

  void _openStory(List<StoryItem> stories, int index) {
    HapticFeedback.lightImpact();
    setState(() => _seenIds.add(stories[index].id));
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => StoryViewer(
          stories: stories,
          initialIndex: index,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(storiesProvider);

    return storiesAsync.when(
      loading: () => _buildShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stories) {
        // Total items = 1 (add button) + stories
        final itemCount = stories.length + 1;

        return SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: itemCount,
            itemBuilder: (context, i) {
              // First item — "Add Story" button
              if (i == 0) return const _AddStoryBubble();

              final story = stories[i - 1];
              final seen = _seenIds.contains(story.id) || story.isSeen;
              return _StoryBubble(
                story: story,
                seen: seen,
                onTap: () => _openStory(stories, i - 1),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: const BoxDecoration(
                  color: AppTheme.neutralGray200,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 40, height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.neutralGray200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Story Bubble ─────────────────────────────────────────────────────────

class _AddStoryBubble extends StatelessWidget {
  const _AddStoryBubble();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // TODO: open post-story flow
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.neutralGray100,
                    border: Border.all(color: AppTheme.neutralGray200, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 26,
                    color: AppTheme.neutralGray400,
                  ),
                ),
                // + badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const SizedBox(
              width: 52,
              child: Text(
                'إضافة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single Story Bubble ───────────────────────────────────────────────────────

class _StoryBubble extends StatelessWidget {
  final StoryItem story;
  final bool seen;
  final VoidCallback onTap;

  const _StoryBubble({
    required this.story,
    required this.seen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ring container
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: seen
                    ? null
                    : const LinearGradient(
                        colors: [
                          Color(0xFFf9a825),
                          Color(0xFFe91e63),
                          Color(0xFF1565c0),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                color: seen ? AppTheme.neutralGray300 : null,
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                padding: const EdgeInsets.all(1.5),
                child: ClipOval(child: _buildAvatar()),
              ),
            ),

            const SizedBox(height: 5),

            // Name label
            SizedBox(
              width: 52,
              child: Text(
                _shortName(story.ownerName),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: seen ? FontWeight.w400 : FontWeight.w700,
                  color: seen ? AppTheme.neutralGray500 : AppTheme.neutralGray900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (story.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: story.imageUrl!,
        fit: BoxFit.cover,
        width: 52,
        height: 52,
        placeholder: (_, __) => Container(color: AppTheme.neutralGray100),
        errorWidget: (_, __, ___) => _EmojiAvatar(emoji: story.adCategory),
      );
    }
    if (story.ownerAvatarUrl != null) {
      return CachedNetworkImage(
        imageUrl: story.ownerAvatarUrl!,
        fit: BoxFit.cover,
        width: 52,
        height: 52,
        errorWidget: (_, __, ___) => _EmojiAvatar(emoji: story.adCategory),
      );
    }
    return _EmojiAvatar(emoji: story.adCategory);
  }

  static String _shortName(String name) {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty ? parts.first : name;
  }
}

class _EmojiAvatar extends StatelessWidget {
  final String? emoji;
  const _EmojiAvatar({this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      color: AppTheme.neutralGray100,
      alignment: Alignment.center,
      child: Text(
        emoji ?? '📦',
        style: const TextStyle(fontSize: 20),
      ),
    );
  }
}
