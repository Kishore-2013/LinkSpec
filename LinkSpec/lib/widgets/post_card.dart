import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clay_container.dart';
import '../screens/member_profile_screen.dart';
import 'comments_bottom_sheet.dart';
import 'share_post_dialog.dart';
import '../screens/saved_items_screen.dart';
import '../services/supabase_service.dart';

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

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostDeleted;

  const PostCard({super.key, required this.post, this.onPostDeleted});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isFollowing = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
    _isLiked = widget.post.isLiked;
    _isFollowing = widget.post.isFollowing;
    _isSaved = SavedPostsStore.isSaved(widget.post.id);
    // Defer impression tracking to AFTER the first frame is painted on screen.
    // This ensures only posts actually rendered in the viewport are counted,
    // not posts built during tree construction but not yet visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recordImpression();
    });
  }

  void _recordImpression() {
    // Session guard: only count each post once per session
    final isFirstView = ViewTracker.markSeen(widget.post.id);
    if (!isFirstView) return;
    // Never count the author viewing their own post
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == widget.post.authorId) return;
    // Fire-and-forget \u2014 errors swallowed inside incrementViewCount
    SupabaseService.incrementViewCount(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      borderRadius: 14,
      depth: 3,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Connect
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
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                // Connect Button
                GestureDetector(
                  onTap: () => setState(() => _isFollowing = !_isFollowing),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width < 400 ? 8 : 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isFollowing
                          ? const Color(0xFF0066CC).withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF0066CC),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isFollowing ? Icons.check : Icons.add,
                          size: 14,
                          color: const Color(0xFF0066CC),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isFollowing ? 'Following' : 'Connect',
                          style: const TextStyle(
                            color: Color(0xFF0066CC),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
          Divider(height: 1, thickness: 0.5, color: Colors.grey[200]),
          const SizedBox(height: 8),
          // Actions: Like, Comment, Share, Save
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionBtn(
                  icon: _isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                  emoji: _isLiked ? '👍' : '🤍',
                  label: 'Like',
                  count: _likeCount,
                  active: _isLiked,
                  onTap: () => _handleLike(),
                ),
                _buildActionBtn(
                  icon: Icons.mode_comment_outlined,
                  emoji: '💬',
                  label: 'Comment',
                  count: _commentCount,
                  onTap: _handleComment,
                ),
                _buildActionBtn(
                  icon: Icons.share_outlined,
                  emoji: '🔗',
                  label: 'Share',
                  onTap: _handleShare,
                ),
                _buildActionBtn(
                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
                  emoji: _isSaved ? '🔖' : '📌',
                  label: _isSaved ? 'Saved' : 'Save',
                  active: _isSaved,
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        // Use upsert to avoid duplicate key errors
        await Supabase.instance.client.from('likes').upsert({
          'post_id': widget.post.id,
          'user_id': userId,
        });
      } else {
        await Supabase.instance.client
            .from('likes')
            .delete()
            .eq('post_id', widget.post.id)
            .eq('user_id', userId);
      }
    } catch (e) {
      // Rollback on failure
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
        debugPrint('Like error: $e');
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
    // Use the in-memory store — no Supabase table required
    final nowSaved = SavedPostsStore.toggle(widget.post.id);
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
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.asMap().entries.map((entry) {
        final line = entry.value;
        if (line.isEmpty) return const SizedBox(height: 8);

        if (line.trim().startsWith('✓') || line.trim().startsWith('-')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.replaceAll('✓', '').replaceAll('-', '').trim(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            line,
            style: TextStyle(
              fontSize: 14,
              fontWeight: entry.key == 0 ? FontWeight.w900 : FontWeight.w600,
              height: 1.5,
              color: entry.key == 0 ? const Color(0xFF003366) : const Color(0xFF1A2740),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String emoji,
    required String label,
    int count = 0,
    bool active = false,
    VoidCallback? onTap,
  }) {
    final color = active ? const Color(0xFF0066CC) : const Color(0xFF65676B);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 480;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 10,
          vertical: 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isMobile ? 18 : 20, color: color),
            if (!isMobile) ...[
              const SizedBox(width: 5),
              Text(
                count > 0 ? '$label  $count' : label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ] else if (count > 0) ...[
              const SizedBox(width: 3),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
