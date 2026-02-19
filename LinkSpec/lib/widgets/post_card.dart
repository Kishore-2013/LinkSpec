import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'share_post_dialog.dart';
import 'comments_bottom_sheet.dart';
import '../screens/member_profile_screen.dart';

/// Post Card Widget
class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onPostDeleted;

  const PostCard({
    Key? key,
    required this.post,
    this.onPostDeleted,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLiking = false;
  int _commentCount = 0;
  bool _isLoadingCount = true;
  bool _isFollowing = false;
  bool _isFollowingLoading = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _commentCount = widget.post.commentCount;
    _isLoadingCount = false;
    _checkIfLiked();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    if (_isOwnPost()) return;
    try {
      final following = await SupabaseService.isFollowing(widget.post.authorId);
      if (mounted) {
        setState(() {
          _isFollowing = following;
        });
      }
    } catch (e) {
      print('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowingLoading) return;

    setState(() {
      _isFollowingLoading = true;
    });

    try {
      if (_isFollowing) {
        await SupabaseService.unfollowUser(widget.post.authorId);
        if (mounted) {
          setState(() {
            _isFollowing = false;
          });
        }
      } else {
        // Strict guard against self-following
        if (widget.post.authorId == Supabase.instance.client.auth.currentUser?.id) {
          throw Exception("You cannot connect with yourself.");
        }

        await SupabaseService.followUser(widget.post.authorId);
        if (mounted) {
          setState(() {
            _isFollowing = true;
          });
        }
      }
    } catch (e) {
      // If the error is about a duplicate key, it means we ARE following, so just update the UI
      if (e.toString().contains('23505') || e.toString().contains('duplicate key')) {
        if (mounted) {
          setState(() {
            _isFollowing = true;
          });
        }
      } else {
        _showErrorSnackBar('Error updating connection: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowingLoading = false;
        });
      }
    }
  }

  Future<void> _loadCommentCount() async {
    try {
      final count = await SupabaseService.getCommentCount(widget.post.id);
      if (mounted) {
        setState(() {
          _commentCount = count;
          _isLoadingCount = false;
        });
      }
    } catch (e) {
      print('Error loading comment count: $e');
      if (mounted) setState(() => _isLoadingCount = false);
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(postId: widget.post.id),
    ).then((_) => _loadCommentCount()); // Refresh count when closed
  }

  Future<void> _checkIfLiked() async {
    try {
      final liked = await SupabaseService.hasLikedPost(widget.post.id);
      if (mounted) {
        setState(() {
          _isLiked = liked;
        });
      }
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    setState(() {
      _isLiking = true;
    });

    try {
      if (_isLiked) {
        await SupabaseService.unlikePost(widget.post.id);
        if (mounted) {
          setState(() {
            _isLiked = false;
            _likeCount = (_likeCount - 1).clamp(0, double.infinity).toInt();
          });
        }
      } else {
        await SupabaseService.likePost(widget.post.id);
        if (mounted) {
          setState(() {
            _isLiked = true;
            _likeCount++;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error updating like: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLiking = false;
        });
      }
    }
  }

  Future<void> _deletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.deletePost(widget.post.id);
        if (mounted) {
          widget.onPostDeleted?.call();
          _showSuccessSnackBar('Post deleted');
        }
      } catch (e) {
        _showErrorSnackBar('Error deleting post: $e');
      }
    }
  }

  Future<void> _sharePost() async {
    // Show a share options dialog
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Post',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_search),
              title: const Text('Share with a Colleague'),
              subtitle: const Text('Search users in your domain'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => SharePostDialog(postId: widget.post.id),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share Experimentally'),
              onTap: () async {
                Navigator.pop(context);
                final String postUrl = '${Uri.base.origin}/#/home?post=${widget.post.id}';
                final String shareText = '${widget.post.authorName} posted on LinkSpec:\n\n'
                    '${widget.post.content}\n\n'
                    'Domain: ${widget.post.domainId}\n\n'
                    'View post: $postUrl';
                
                if (widget.post.imageUrl != null) {
                  await Share.share('$shareText\n\nImage: ${widget.post.imageUrl}');
                } else {
                  await Share.share(shareText);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _isOwnPost() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return false;
    // Use lowerCase and trim for a safer identity check
    return currentUserId.trim().toLowerCase() == widget.post.authorId.trim().toLowerCase();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MemberProfileScreen(userId: widget.post.authorId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: widget.post.authorAvatar != null
                          ? NetworkImage(widget.post.authorAvatar!)
                          : null,
                      child: widget.post.authorAvatar == null
                          ? Text(
                              widget.post.authorName?.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MemberProfileScreen(userId: widget.post.authorId),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.post.authorName ?? 'Unknown User',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF191919)),
                              ),
                              const SizedBox(width: 4),
                              Text('• 1st', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          Text(
                            widget.post.domainId.toUpperCase(),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                timeago.format(widget.post.createdAt),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.public, size: 12, color: Colors.grey[600]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isOwnPost())
                    IconButton(
                      icon: const Icon(Icons.more_horiz, size: 24),
                      onPressed: _deletePost,
                      color: Colors.grey[700],
                    )
                  else
                    TextButton.icon(
                      onPressed: _isFollowingLoading ? null : _toggleFollow,
                      icon: Icon(_isFollowing ? Icons.check : Icons.add, size: 18),
                      label: Text(_isFollowing ? 'Following' : 'Connect'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue[700],
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Post Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildParsedContent(widget.post.content),
            ),
            const SizedBox(height: 12),

            // Post Image (if any)
            if (widget.post.imageUrl != null) ...[
              Image.network(
                widget.post.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    width: double.infinity,
                    color: Colors.grey[50],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            // Stats row (LinkedIn style)
            if (_likeCount > 0 || _commentCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    if (_likeCount > 0) ...[
                      const Icon(Icons.thumb_up, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text('$_likeCount', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                    const Spacer(),
                    if (_commentCount > 0)
                      Text('$_commentCount comments', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
            ),
            
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionBarItem(
                    _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    'Like',
                    _isLiked ? Colors.blue : Colors.grey[600]!,
                    _toggleLike,
                  ),
                  _buildActionBarItem(
                    Icons.chat_bubble_outline,
                    'Comment',
                    Colors.grey[600]!,
                    _showComments,
                  ),
                  _buildActionBarItem(
                    Icons.repeat,
                    'Repost',
                    Colors.grey[600]!,
                    _sharePost,
                  ),
                  _buildActionBarItem(
                    Icons.send,
                    'Send',
                    Colors.grey[600]!,
                    _sharePost,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedContent(String content) {
    if (content.startsWith('ARTICLE_TITLE:')) {
      final lines = content.split('\n\n');
      final titleLine = lines[0].replaceFirst('ARTICLE_TITLE: ', '');
      final body = lines.sublist(1).join('\n\n');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Text('ARTICLE', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 8),
          Text(titleLine, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191919), height: 1.3)),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(fontSize: 14, color: Color(0xFF191919), height: 1.5, fontWeight: FontWeight.w400)),
        ],
      );
    } else if (content.startsWith('EVENT_TITLE:')) {
      final lines = content.split('\n\n');
      final header = lines[0].split('\n');
      final body = lines.sublist(1).join('\n\n');

      String title = '';
      String venue = '';
      String date = '';
      String time = '';

      for (var line in header) {
        if (line.startsWith('EVENT_TITLE:')) title = line.replaceFirst('EVENT_TITLE: ', '');
        if (line.startsWith('VENUE:')) venue = line.replaceFirst('VENUE: ', '');
        if (line.startsWith('DATE:')) date = line.replaceFirst('DATE: ', '');
        if (line.startsWith('TIME:')) time = line.replaceFirst('TIME: ', '');
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Colors.orange[800], size: 16),
                const SizedBox(width: 8),
                Text('EVENT', style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF191919))),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(venue, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('$date • $time', style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            if (body.isNotEmpty) ...[
              const Divider(height: 24),
              Text(body, style: const TextStyle(fontSize: 14, color: Color(0xFF191919), height: 1.4)),
            ],
          ],
        ),
      );
    }

    return Text(
      content,
      style: const TextStyle(fontSize: 14, color: Color(0xFF191919), height: 1.4),
    );
  }

  Widget _buildActionBarItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
