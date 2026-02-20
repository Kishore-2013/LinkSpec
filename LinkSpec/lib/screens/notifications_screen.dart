import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/notification.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

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
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = data.map((n) => AppNotification.fromJson(n)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await SupabaseService.markNotificationAsRead(id);
      _loadNotifications();
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
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
      case 'connection':
        message = 'connected with you';
        icon = Icons.person_add;
        iconColor = Colors.blue[700];
        break;
      default:
        message = 'interacted with you';
        icon = Icons.notifications;
        iconColor = Colors.orange;
    }

    return Card(
      elevation: 0,
      color: notif.isRead ? Colors.white.withOpacity(0.6) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: notif.isRead ? Colors.transparent : Colors.blue.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: () => _markAsRead(notif.id),
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
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 14, color: iconColor),
              ),
            ),
          ],
        ),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
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
        trailing: !notif.isRead
            ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle))
            : null,
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
              style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('We\'ll notify you when someone interacts with your posts', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
