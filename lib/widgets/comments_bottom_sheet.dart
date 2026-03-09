
import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/supabase_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsBottomSheet extends StatefulWidget {
  final String postId;

  const CommentsBottomSheet({Key? key, required this.postId}) : super(key: key);

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  Comment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.getComments(widget.postId);
      if (mounted) {
        setState(() {
          _comments = data.map((c) => Comment.fromJson(c)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.createComment(
        postId: widget.postId,
        content: content,
        parentId: _replyingTo?.id,
      );
      _commentController.clear();
      setState(() => _replyingTo = null);
      await _loadComments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _toggleLike(Comment comment) async {
    try {
      await SupabaseService.toggleCommentLike(comment.id);
      // Local update for immediate feedback
      _loadComments(); 
    } catch (e) {
      debugPrint('Error liking comment: $e');
    }
  }

  void _startReply(Comment comment) {
    setState(() {
      _replyingTo = comment;
    });
    _commentFocusNode.requestFocus();
  }

  List<Comment> _getThreadedComments() {
    final List<Comment> topLevel = _comments.where((c) => c.parentId == null).toList();
    final List<Comment> threaded = [];
    for (var parent in topLevel) {
      threaded.add(parent);
      threaded.addAll(_comments.where((c) => c.parentId == parent.id));
    }
    return threaded;
  }

  @override
  Widget build(BuildContext context) {
    final threadedComments = _getThreadedComments();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),

          // Comments List
          Expanded(
            child: _isLoading && _comments.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : threadedComments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 60, color: Colors.blue[50]),
                            const SizedBox(height: 16),
                            Text('No comments yet', style: TextStyle(color: Colors.grey[400])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: threadedComments.length,
                        itemBuilder: (context, index) {
                          final comment = threadedComments[index];
                          final isReply = comment.parentId != null;
                          
                          return Padding(
                            padding: EdgeInsets.only(
                              left: isReply ? 54.0 : 16.0,
                              right: 16.0,
                              bottom: 16.0,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: isReply ? 14 : 18,
                                  backgroundColor: Colors.blue[50],
                                  backgroundImage: comment.authorAvatar != null
                                      ? NetworkImage(comment.authorAvatar!)
                                      : null,
                                  child: comment.authorAvatar == null
                                      ? Text(
                                          comment.authorName?[0].toUpperCase() ?? '?',
                                          style: TextStyle(fontSize: isReply ? 11 : 14, color: Colors.blue),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey[50]?.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              comment.authorName ?? 'Unknown',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isReply ? 12 : 13,
                                                color: const Color(0xFF1A2740),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              comment.content,
                                              style: TextStyle(fontSize: isReply ? 13 : 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const SizedBox(width: 4),
                                          Text(
                                            timeago.format(comment.createdAt),
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                          ),
                                          const SizedBox(width: 16),
                                          GestureDetector(
                                            onTap: () => _toggleLike(comment),
                                            child: Text(
                                              'Like',
                                              style: TextStyle(
                                                color: comment.isLiked ? Colors.blue : Colors.grey[600],
                                                fontWeight: comment.isLiked ? FontWeight.bold : FontWeight.normal,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          if (!isReply) // Don't allow nested replies for simplicity
                                            GestureDetector(
                                              onTap: () => _startReply(comment),
                                              child: Text(
                                                'Reply',
                                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                              ),
                                            ),
                                          if (comment.likeCount > 0) ...[
                                            const Spacer(),
                                            Icon(Icons.thumb_up_alt_rounded, size: 12, color: Colors.blue[300]),
                                            const SizedBox(width: 4),
                                            Text(
                                              comment.likeCount.toString(),
                                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),

          // Input field
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingTo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Replying to ${_replyingTo!.authorName}',
                          style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _replyingTo = null),
                          child: Icon(Icons.close, size: 14, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        decoration: InputDecoration(
                          hintText: _replyingTo != null ? 'Add a reply...' : 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSubmitting ? null : _submitComment,
                      icon: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, color: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
