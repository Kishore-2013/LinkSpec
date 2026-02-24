import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/post.dart';
import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clay_container.dart';
import '../screens/member_profile_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  const PostCard({Key? key, required this.post}) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _isLiked = widget.post.isLiked;
    _isFollowing = widget.post.isFollowing;
  }

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      borderRadius: 40,
      depth: 10,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Connect
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MemberProfileScreen(userId: widget.post.authorId))),
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: widget.post.authorAvatar != null ? NetworkImage(widget.post.authorAvatar!) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.post.authorName ?? 'Nikhil', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(width: 4),
                        const Text('• 1st', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                    Text(
                      'about ${timeago.format(widget.post.createdAt)} ago',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              // Connect Button
              _buildConnectBtn(),
            ],
          ),
          const SizedBox(height: 16),
          // Content
          _buildPostContent(widget.post.content),
          const SizedBox(height: 20),
          // Actions: Like, Share
          Row(
            children: [
              _buildActionBtn(Icons.thumb_up_alt_outlined, 'Like', count: _likeCount, active: _isLiked),
              const Spacer(),
              _buildActionBtn(Icons.share_outlined, 'Share'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectBtn() {
    return ClayContainer(
      borderRadius: 20,
      depth: 4,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.add, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            _isFollowing ? 'Following' : 'Connect',
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent(String content) {
    // Basic logic to bold the first line if it looks like a heading
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.asMap().entries.map((entry) {
        final line = entry.value;
        if (line.isEmpty) return const SizedBox(height: 8);
        
        // Bullet points with checkmarks logo
        if (line.trim().startsWith('✓') || line.trim().startsWith('-')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(line.replaceAll('✓', '').trim(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
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
              color: entry.key == 0 ? const Color(0xFF003366) : Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, {int count = 0, bool active = false}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: active ? Colors.blue : Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: active ? Colors.blue : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14),
        ),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Text(count.toString(), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}
