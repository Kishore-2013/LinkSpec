import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/notification.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';

class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onRefreshBadges;
  const NotificationsScreen({Key? key, this.onBack, this.onRefreshBadges}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  StreamSubscription? _notifSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtime();
  }

  void _setupRealtime() {
    _notifSubscription = SupabaseService.getNotificationsStream().listen((data) {
      // Stream only returns raw data, so we refresh the rich data (with joins)
      if (mounted) _loadNotifications();
    });
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    // Immediate action: mark all as read so the badge disappears instantly
    try {
      debugPrint('UI: NotificationsScreen calling markAllNotificationsAsRead');
      await SupabaseService.markAllNotificationsAsRead();
      // Small delay to allow DB sync before parent re-fetches count
      await Future.delayed(const Duration(milliseconds: 300));
      widget.onRefreshBadges?.call();
    } catch (e) {
      debugPrint('UI: markAllNotificationsAsRead failed: $e');
    }

    // Only show full-screen loader if we have no data yet
    if (_notifications.isEmpty && mounted) setState(() => _isLoading = true);
    
    try {
      final data = await SupabaseService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = data.map((n) => AppNotification.fromJson(n)).toList();
          // Update local state so matches DB (all read)
          _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(AppNotification notif) async {
    if (notif.isRead) return;
    try {
      debugPrint('UI: Marking single notification ${notif.id} as read');
      await SupabaseService.markNotificationAsRead(notif.id);
      _loadNotifications();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      debugPrint('UI: Requesting deletion of notification $id');
      await SupabaseService.deleteNotification(id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted'), duration: Duration(seconds: 2)),
        );
      }
      
      await _loadNotifications(); // Refresh list to remove it from UI
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Custom back: switches tab instead of popping the home route
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Colors.blue, size: 22),
            onPressed: () async {
              await SupabaseService.markAllNotificationsAsRead();
              _loadNotifications();
            },
            tooltip: 'Mark all as read',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return _buildNotificationCard(notif);
                      },
                    ),
            ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    String message = '';
    IconData icon;
    Color iconColor;

    switch (notif.type) {
      case 'like':
        message = 'liked your post';
        icon = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment':
        message = 'commented on your post';
        icon = Icons.chat_bubble;
        iconColor = Colors.blue;
        break;
      case 'like_comment':
        message = 'liked your comment';
        icon = Icons.favorite_border_rounded;
        iconColor = Colors.pink;
        break;
      case 'connection':
        message = 'united with you';
        icon = Icons.person_add;
        iconColor = Colors.blue[700]!;
        break;
      default:
        message = 'interacted with you';
        icon = Icons.notifications;
        iconColor = Colors.orange;
    }

    return Card(
      elevation: 0,
      color: notif.isRead ? Theme.of(context).cardTheme.color?.withOpacity(0.6) : Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: notif.isRead ? Colors.transparent : Colors.blue.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: () => _markAsRead(notif),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Colors.blue[50],
              backgroundImage: notif.actorAvatar != null ? NetworkImage(notif.actorAvatar!) : null,
              child: notif.actorAvatar == null
                  ? Text(notif.actorName?[0].toUpperCase() ?? 'U', style: const TextStyle(color: Colors.blue))
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ),
          ],
        ),
        title: RichText(
          text: TextSpan(
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
            children: [
              TextSpan(text: notif.actorName ?? 'Someone', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: ' $message'),
            ],
          ),
        ),
        subtitle: Text(
          timeago.format(notif.createdAt),
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notif.isRead)
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 20, color: Colors.grey[500]),
              onPressed: () => _deleteNotification(notif.id),
              tooltip: 'Delete notification',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 80, color: Colors.blue[100]),
          const SizedBox(height: 16),
          const Text('No notifications yet',
              style: TextStyle(color: Color(0xFF1A2740), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('We\'ll notify you when someone interacts with your posts', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
