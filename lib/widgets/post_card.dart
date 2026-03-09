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
import '../services/supabase_service.dart';
import '../screens/search_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../models/job.dart';
import '../screens/job_detail_screen.dart';
import '../api/job_service.dart';

import '../providers/follow_provider.dart';
import '../providers/saved_posts_provider.dart';
import '../api/web_cache_manager.dart';
import '../utils/performance_utils.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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
  bool _isLikeProcessing = false;
  bool _isExpanded = false; // For Read More
  double? _imageAspectRatio; // Loaded from actual image dimensions
  Uint8List? _cachedImageBytes;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
    _isLiked = widget.post.isLiked;

    // Initialize follow provider with the author's status from the post object
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(followProvider.notifier).setFollowStatus(widget.post.authorId, widget.post.isFollowing);
        _recordImpression();
      }
    });
    // Pre-load image to get real aspect ratio and check byte cache
    if (widget.post.imageUrl != null && widget.post.imageUrl!.trim().isNotEmpty) {
      _resolveImageAspectRatio(widget.post.imageUrl!);
      _loadCachedImageBytes(widget.post.imageUrl!);
    }
  }

  Future<void> _loadCachedImageBytes(String url) async {
    final bytes = await WebCacheManager.getCachedImage(url);
    if (bytes != null && mounted) {
      setState(() => _cachedImageBytes = bytes);
    }
  }

  void _resolveImageAspectRatio(String url) {
    final imageProvider = NetworkImage(url);
    final stream = imageProvider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener(
      (info, _) {
        if (mounted) {
          final w = info.image.width.toDouble();
          final h = info.image.height.toDouble();
          if (h > 0) setState(() => _imageAspectRatio = w / h);
        }
      },
      onError: (_, __) {}, // keep null ratio, fallback to unconstrained
    ));
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

    // Use memoized engagement calculation
    final engagement = PerformanceUtils.calculatePostEngagement(_likeCount, _commentCount);
    
    return GestureDetector(
      onTap: widget.post.isAutomated && widget.post.linkedJobId != null
          ? () => _handleViewJob(widget.post.linkedJobId!)
          : null,
      child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1), 
          width: 0.6
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ClayContainer(
          color: widget.backgroundColor ?? Theme.of(context).cardColor,
          borderRadius: 16,
          depth: 1,
          spread: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
          // Header: Avatar, Name, Unite
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MemberProfileScreen(userId: widget.post.authorId),
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundImage: widget.post.authorAvatar != null
                              ? null
                              : null,
                          foregroundImage: widget.post.authorAvatar != null
                              ? CachedNetworkImageProvider(widget.post.authorAvatar!)
                              : null,

                          child: widget.post.authorAvatar == null
                              ? Text(
                                  (widget.post.authorName ?? 'U').substring(0, 1).toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.post.authorName ?? 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900, 
                                      fontSize: 14.5,
                                      color: Theme.of(context).textTheme.bodyLarge?.color,
                                      letterSpacing: -0.1,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                const Text('• 1st', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
                                if (widget.post.isTrending) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 9),
                                        SizedBox(width: 1),
                                        Text(
                                          'Trending',
                                          style: TextStyle(
                                            color: Colors.orange, 
                                            fontSize: 8, 
                                            fontWeight: FontWeight.w900
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              timeago.format(widget.post.createdAt),
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
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
                        color: isFollowing 
                            ? Theme.of(context).dividerColor.withOpacity(0.1) 
                            : Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(20),
                        border: isFollowing ? Border.all(color: Theme.of(context).primaryColor) : null,
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

          // Post Image
          if (widget.post.imageUrl != null && widget.post.imageUrl!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _cachedImageBytes != null 
                ? Image.memory(
                    _cachedImageBytes!,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  )
                : CachedNetworkImage(
                    imageUrl: widget.post.imageUrl!,
                    alignment: Alignment.center,
                    fit: BoxFit.contain, 
                    width: double.infinity,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[200]!,
                      highlightColor: Colors.grey[100]!,
                      child: AspectRatio(
                        aspectRatio: _imageAspectRatio ?? 16/9,
                        child: Container(color: Colors.white)
                      ),
                    ),
                    imageBuilder: (context, imageProvider) {
                      // Once loaded, try to cache bytes if not already done
                      // (Practical implementation would use a specialized manager)
                      return Image(image: imageProvider, fit: BoxFit.contain);
                    },
                    errorWidget: (context, url, error) => const SizedBox.shrink(),
                  ),
            ),
          ],
          
          // View Job Button (for automated job posts)
          if (widget.post.linkedJobId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleViewJob(widget.post.linkedJobId!),
                icon: const Icon(Icons.launch_rounded, size: 16),
                label: const Text('View Full Job Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          // Divider
          Divider(height: 0.5, thickness: 0.5, color: Theme.of(context).dividerColor),
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
            ],          // Column children
          ),            // Column
          ),            // ClayContainer
        ),              // ClipRRect
      ),                // Container
    );                  // GestureDetector
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
    // After toggle, check the new state from the provider
    final nowSaved = ref.read(savedPostsProvider).contains(widget.post.id);
  
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nowSaved ? '✓ Post saved to your collection' : 'Post removed from saved',
        ),
        backgroundColor: nowSaved ? Theme.of(context).primaryColor : Theme.of(context).hintColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleViewJob(String jobId) async {
    try {
      final jobData = await JobService.fetchJobById(jobId);
      if (jobData != null && mounted) {
        final job = Job.fromJson(jobData);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job listing no longer available')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading job: $e')),
        );
      }
    }
  }

  // ─── Hashtag navigation ───────────────────────────────────────

  void _navigateToTag(String tag) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => _TagSearchPage(initialTag: tag),
      ),
    );
  }

  // ─── UI Builders ─────────────────────────────────────────────

  static final _tagPattern = RegExp(r'(#[A-Za-z][A-Za-z0-9_]*)');

  Widget _buildPostContent(String content) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        );

        // ── Overflow detection (same as before) ────────────────
        final textSpan = TextSpan(text: content, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: 4,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final isOverflowing = textPainter.didExceedMaxLines;

        // ── Parse into plain + hashtag spans ──────────────────
        final spans = <InlineSpan>[];
        int cursor = 0;
        for (final match in _tagPattern.allMatches(content)) {
          if (match.start > cursor) {
            spans.add(TextSpan(
              text: content.substring(cursor, match.start),
              style: textStyle,
            ));
          }
          final tag = match.group(0)!;
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _navigateToTag(tag),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  tag,
                  style: textStyle.copyWith(
                    color: Theme.of(context).primaryColor,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ));
          cursor = match.end;
        }
        if (cursor < content.length) {
          spans.add(TextSpan(text: content.substring(cursor), style: textStyle));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              maxLines: _isExpanded ? null : 4,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.fade,
              text: TextSpan(
                style: textStyle.copyWith(fontFamily: 'SF Pro Display'),
                children: spans,
              ),
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
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
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

// ─── Tag Search Page ─────────────────────────────────────────────────────────
/// Thin wrapper that opens SearchScreen with [initialTag] pre-populated.
class _TagSearchPage extends StatefulWidget {
  final String initialTag;
  const _TagSearchPage({required this.initialTag});
  @override
  State<_TagSearchPage> createState() => _TagSearchPageState();
}

class _TagSearchPageState extends State<_TagSearchPage> {
  @override
  Widget build(BuildContext context) {
    return SearchScreen(
      initialQuery: widget.initialTag,
      autofocusSearch: false,
      onBack: () => Navigator.of(context).pop(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

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
