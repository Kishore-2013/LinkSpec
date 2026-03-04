import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/group.dart';
import '../models/event.dart';
import 'group_detail_screen.dart';

// ─── Unified activity item ────────────────────────────────────────────────────
enum _ActivityType { post, group, event }

class _ActivityItem {
  final _ActivityType type;
  final DateTime timestamp;
  final String id;

  // Post fields
  final Post? post;

  // Group fields
  final Group? group;

  // Event fields
  final AppEvent? event;

  _ActivityItem.fromPost(this.post)
      : type = _ActivityType.post,
        id = post!.id,
        timestamp = post.createdAt,
        group = null,
        event = null;

  _ActivityItem.fromGroup(this.group, DateTime ts)
      : type = _ActivityType.group,
        id = group!.id,
        timestamp = ts,
        post = null,
        event = null;

  _ActivityItem.fromEvent(this.event)
      : type = _ActivityType.event,
        id = event!.id,
        timestamp = event.date,
        post = null,
        group = null;
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class RecentActivityScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const RecentActivityScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  List<_ActivityItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Fetch current user's private activity (likes, comments, own posts)
      // This is strictly filtered by auth.uid() in the service.
      final activityData = await SupabaseService.getMyRecentActivity(limit: 25);
      
      final items = <_ActivityItem>[];

      for (final raw in activityData) {
        final type = raw['type'] as String;
        final ts   = DateTime.tryParse(raw['created_at'] as String? ?? '') ?? DateTime.now();
        
        if (type == 'post') {
          final p = Post(
            id: raw['id'],
            authorId: SupabaseService.getCurrentUserId() ?? '',
            domainId: '', 
            content: raw['summary'] ?? '',
            createdAt: ts,
            updatedAt: ts,
            authorName: 'You',
          );
          items.add(_ActivityItem.fromPost(p));
        } else if (type == 'comment' || type == 'like') {
          final p = Post(
            id: raw['id'],
            authorId: SupabaseService.getCurrentUserId() ?? '',
            domainId: type.toUpperCase(),
            content: raw['summary'] ?? '',
            createdAt: ts,
            updatedAt: ts,
            authorName: 'You',
          );
          items.add(_ActivityItem.fromPost(p));
        }
      }

      // Note: Groups and events are now excluded from "My Activity" 
      // as they are typically public browse items, keeping this view strictly personal.

      if (mounted) setState(() { _items = items; _isLoading = false; });
    } catch (e) {
      debugPrint('RecentActivityScreen error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Recent Activity',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2740)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildCard(_items[i]),
                  ),
                ),
    );
  }

  Widget _buildCard(_ActivityItem item) {
    switch (item.type) {
      case _ActivityType.post:
        return _buildPostCard(item.post!);
      case _ActivityType.group:
        return _buildGroupCard(item.group!, item.timestamp);
      case _ActivityType.event:
        return _buildEventCard(item.event!);
    }
  }

  // ── Post card ───────────────────────────────────────────────────────────────
  Widget _buildPostCard(Post post) {
    return _ActivityCard(
      typeLabel: 'POST',
      typeColor: Colors.blue,
      typeIcon: Icons.article_outlined,
      timestamp: post.createdAt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue[50],
                backgroundImage: post.authorAvatar != null
                    ? NetworkImage(post.authorAvatar!)
                    : null,
                child: post.authorAvatar == null
                    ? Text(
                        (post.authorName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      post.domainId,
                      style: TextStyle(color: Colors.blue[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            post.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A2740)),
          ),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                post.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 140,
                  width: double.infinity,
                  color: Colors.blue[50],
                  child: const Icon(Icons.broken_image_rounded, color: Colors.blue, size: 30),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('${post.likeCount}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('${post.commentCount}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  // ── Group card ──────────────────────────────────────────────────────────────
  Widget _buildGroupCard(Group group, DateTime ts) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
      ),
      child: _ActivityCard(
        typeLabel: 'GROUP',
        typeColor: Colors.purple,
        typeIcon: Icons.group_outlined,
        timestamp: ts,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: group.coverUrl != null
                  ? Image.network(
                      group.coverUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: Colors.purple[50],
                        child: const Icon(Icons.groups, color: Colors.purple, size: 28),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: Colors.purple[50],
                      child: const Icon(Icons.groups, color: Colors.purple, size: 28),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${group.memberCount} members · ${group.domainId}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Event card ──────────────────────────────────────────────────────────────
  Widget _buildEventCard(AppEvent event) {
    final isPast = event.date.isBefore(DateTime.now());
    final daysLabel = isPast
        ? 'Ended ${timeago.format(event.date)}'
        : 'In ${event.date.difference(DateTime.now()).inDays} days';

    return _ActivityCard(
      typeLabel: 'EVENT',
      typeColor: Colors.orange,
      typeIcon: Icons.event_outlined,
      timestamp: event.date,
      child: Row(
        children: [
          // Date badge
          Container(
            width: 52,
            height: 56,
            decoration: BoxDecoration(
              color: isPast ? Colors.grey[100] : Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.date.day.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isPast ? Colors.grey : Colors.orange[700],
                  ),
                ),
                Text(
                  _monthAbbr(event.date.month),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPast ? Colors.grey[500] : Colors.orange[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        event.location,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  daysLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isPast ? Colors.grey : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _monthAbbr(int month) {
    const months = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return months[month - 1];
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.blue[100]),
          const SizedBox(height: 16),
          const Text('Nothing recent yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2740))),
          const SizedBox(height: 8),
          const Text('Posts, groups, and events you interact with will appear here', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// ─── Shared card shell ────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final String typeLabel;
  final Color typeColor;
  final IconData typeIcon;
  final DateTime timestamp;
  final Widget child;

  const _ActivityCard({
    required this.typeLabel,
    required this.typeColor,
    required this.typeIcon,
    required this.timestamp,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAED), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge + timestamp row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 11, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                timeago.format(timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
