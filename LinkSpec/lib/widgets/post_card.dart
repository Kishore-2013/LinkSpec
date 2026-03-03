import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clay_container.dart';
import '../screens/member_profile_screen.dart';
import 'comments_bottom_sheet.dart';
import 'share_post_dialog.dart';
import '../screens/saved_items_screen.dart';
import '../services/supabase_service.dart';

import '../providers/follow_provider.dart';
import '../providers/saved_posts_provider.dart';

/// Session-level tracker so each post is counted as an impression only ONCE
/// per app session, no matter how many times the user scrolls past it.
class ViewTracker {
  ViewTracker._();
  static final Set<String> _seenPostIds = {};

  /// Returns true and records the ID if this is the FIRST time seeing this post.
  /// Returns false (does nothing) if the post was already seen this session.
  static bool markSeen(String postId) {
    if (_seenPostIds.contains(postId)) return false;
    _seenPostIds.add(postId);
    return true;
  }

  /// Clear on logout so next login starts fresh
  static void clear() => _seenPostIds.clear();
}

class PostCard extends ConsumerStatefulWidget {
  final Post post;
  final VoidCallback? onPostDeleted;
  final Color? backgroundColor;

  const PostCard({super.key, required this.post, this.onPostDeleted, this.backgroundColor});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isSaved = false;
  bool _isLikeProcessing = false;
  bool _isExpanded = false; // For Read More

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
    _isLiked = widget.post.isLiked;
    _isSaved = ref.read(savedPostsProvider).contains(widget.post.id);

    // Initialize follow provider with the author's status from the post object
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(followProvider.notifier).setFollowStatus(widget.post.authorId, widget.post.isFollowing);
        _recordImpression();
      }
    });
  }

  void _recordImpression() {
    // Session guard: only count each post once per session
    final isFirstView = ViewTracker.markSeen(widget.post.id);
    if (!isFirstView) return;
    // Never count the author viewing their own post
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.post.authorId) return;
    // Fire-and-forget — errors swallowed inside incrementViewCount
    SupabaseService.incrementViewCount(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global follow status for this specific author
    final isFollowing = ref.watch(followProvider)[widget.post.authorId] ?? widget.post.isFollowing;
    // Watch saved status
    final isSaved = ref.watch(savedPostsProvider).contains(widget.post.id);

    return ClayContainer(
      color: widget.backgroundColor ?? Colors.white,
      borderRadius: 14,
      depth: 3,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Unite
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberProfileScreen(userId: widget.post.authorId),
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundImage: widget.post.authorAvatar != null
                        ? NetworkImage(widget.post.authorAvatar!)
                        : null,
                    child: widget.post.authorAvatar == null
                        ? Text(
                            (widget.post.authorName ?? 'U').substring(0, 1).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.post.authorName ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900, 
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('• 1st', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                      Text(
                        timeago.format(widget.post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Connect/Follow Button - Not shown for current user's own posts
                if (Supabase.instance.client.auth.currentUser?.id != widget.post.authorId)
                  GestureDetector(
                    onTap: () async {
                      try {
                        await ref.read(followProvider.notifier).toggleFollow(widget.post.authorId);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update follow status: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isFollowing ? Colors.grey[100] : const Color(0xFF0066CC),
                        borderRadius: BorderRadius.circular(20),
                        border: isFollowing ? Border.all(color: const Color(0xFF0066CC)) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFollowing ? Icons.check : Icons.add_rounded,
                            color: isFollowing ? const Color(0xFF0066CC) : Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isFollowing ? 'Following' : 'Unite',
                            style: TextStyle(
                              color: isFollowing ? const Color(0xFF0066CC) : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Content
          _buildPostContent(widget.post.content),
          const SizedBox(height: 20),
          // Divider
          Divider(height: 0.5, thickness: 0.5, color: Colors.grey[200]),
          const SizedBox(height: 6),
          // Actions: Like, Comment, Share, Save
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionBtn(
                  icon: Icons.favorite_border,
                  lottieUrl: 'https://cdn.lordicon.com/nvsfzbop.json',
                  markerName: 'morph-two-hearts',
                  emoji: _isLiked ? '❤️' : '🤍',
                  label: 'Like',
                  count: _likeCount,
                  active: _isLiked,
                  onTap: () => _handleLike(),
                ),
                _ActionBtn(
                  icon: Icons.mode_comment_outlined,
                  svgPath: 'assets/svg/wired-outline-981-consultation-hover-conversation-alt.svg',
                  lottieUrl: 'https://cdn.lordicon.com/jdgfsfzr.json',
                  markerName: 'hover-conversation-alt',
                  emoji: '💬',
                  label: 'Comment',
                  count: _commentCount,
                  onTap: _handleComment,
                ),
                _ActionBtn(
                  icon: Icons.share_outlined,
                  emoji: '🔗',
                  label: 'Share',
                  onTap: _handleShare,
                ),
                _ActionBtn(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
                  emoji: isSaved ? '🔖' : '📌',
                  label: isSaved ? 'Saved' : 'Save',
                  active: isSaved,
                  onTap: _handleSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Handlers ────────────────────────────────────────────────

  Future<void> _handleLike() async {
    if (_isLikeProcessing) return;
    
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    setState(() {
      _isLikeProcessing = true;
    });

    final wasLiked = _isLiked;

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await Supabase.instance.client.from('likes').upsert({
          'post_id': widget.post.id,
          'user_id': userId,
        }, onConflict: 'post_id,user_id');
      } else {
        await Supabase.instance.client
            .from('likes')
            .delete()
            .eq('post_id', widget.post.id)
            .eq('user_id', userId);
      }
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        if (mounted) {
          setState(() {
            _isLiked = wasLiked;
            _likeCount = widget.post.likeCount + (_isLiked ? 0 : -1);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = wasLiked;
          _likeCount = widget.post.likeCount + (_isLiked ? 0 : -1);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeProcessing = false;
        });
      }
    }
  }

  void _handleComment() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsBottomSheet(postId: widget.post.id),
    ).then((_) async {
      // Refresh comment count when sheet closes
      try {
        final res = await Supabase.instance.client
            .from('comments')
            .select()
            .eq('post_id', widget.post.id);
        if (mounted) setState(() => _commentCount = (res as List).length);
      } catch (_) {}
    });
  }

  void _handleShare() {
    showDialog(
      context: context,
      builder: (_) => SharePostDialog(postId: widget.post.id),
    );
  }

  void _handleSave() {
    ref.read(savedPostsProvider.notifier).toggle(widget.post.id);
    final nowSaved = ref.read(savedPostsProvider).contains(widget.post.id);
    setState(() => _isSaved = nowSaved);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowSaved ? '✓ Post saved to your collection' : 'Post removed from saved',
        ),
        backgroundColor: nowSaved ? const Color(0xFF1565C0) : Colors.grey[700],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── UI Builders ─────────────────────────────────────────────

  Widget _buildPostContent(String content) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: Colors.black,
        );

        final textSpan = TextSpan(text: content, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 5,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        final isOverflowing = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              maxLines: _isExpanded ? null : 5,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.fade,
              style: textStyle,
            ),
            if (isOverflowing)
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _isExpanded ? 'Show less' : 'Read more...',
                      style: const TextStyle(
                        color: Color(0xFF0066CC),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String? svgPath;
  final String? lottieUrl;
  final String? markerName;
  final String emoji;
  final String label;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    this.svgPath,
    this.lottieUrl,
    this.markerName,
    required this.emoji,
    required this.label,
    this.count = 0,
    this.active = false,
    this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> with SingleTickerProviderStateMixin {
  late AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.active;
    // For buttons without an "active" concept (like Comment), 
    // we show the animated icon if URLs are provided.
    final bool showAnimated = widget.lottieUrl != null || widget.svgPath != null;
    final bool isActuallyActive = active || (widget.label == 'Comment' && showAnimated);

    final color = active ? const Color(0xFF0066CC) : const Color(0xFF65676B);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 480;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 10,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: isActuallyActive && (widget.lottieUrl != null || widget.svgPath != null)
                  ? (widget.lottieUrl != null
                      ? Lottie.network(
                          widget.lottieUrl!,
                          controller: _lottieController,
                          key: const ValueKey('active_lottie'),
                          width: isMobile ? 24 : 24,
                          height: isMobile ? 24 : 24,
                          onLoaded: (composition) {
                            if (mounted) {
                              _lottieController.duration = composition.duration;
                              final marker = composition.markers.isEmpty
                                  ? null
                                  : composition.markers.firstWhere(
                                      (m) => m.name == widget.markerName,
                                      orElse: () => composition.markers.first,
                                    );
                              if (marker != null) {
                                // Default pace, or customize per button if needed
                                final duration = widget.label == 'Like' 
                                    ? const Duration(milliseconds: 2000)
                                    : const Duration(milliseconds: 4500);
                                _lottieController.duration = duration;
                                _lottieController.repeat(
                                  min: marker.start,
                                  max: marker.end,
                                );
                              } else {
                                _lottieController.repeat();
                              }
                            }
                          },
                          delegates: LottieDelegates(
                            values: [
                              ValueDelegate.color(
                                const ['**', '.primary', '**'],
                                value: const Color(0xFF121331),
                              ),
                              ValueDelegate.color(
                                const ['**', '.secondary', '**'],
                                value: const Color(0xFF16C79E),
                              ),
                              ValueDelegate.strokeWidth(
                                const ['**', 'stroke', '**'],
                                value: 3.0,
                              ),
                            ],
                          ),
                          repeat: true,
                        )
                      : SvgPicture.asset(
                          widget.svgPath!,
                          key: const ValueKey('active_svg'),
                          width: isMobile ? 24 : 24,
                          height: isMobile ? 24 : 24,
                        ))
                  : Icon(
                      widget.icon,
                      key: const ValueKey('inactive_icon'),
                      color: color,
                      size: isMobile ? 20 : 22,
                    ),
            ),
            if (widget.count > 0) ...[
              const SizedBox(width: 4),
              Text(
                widget.count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
            const SizedBox(width: 6),
            if (screenWidth > 600)
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
