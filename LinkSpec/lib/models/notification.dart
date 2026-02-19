
class AppNotification {
  final String id;
  final String userId;
  final String actorId;
  final String type; // 'like', 'comment', 'connection'
  final String? postId;
  final bool isRead;
  final DateTime createdAt;
  
  // Flattened actor info
  final String? actorName;
  final String? actorAvatar;

  AppNotification({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    this.postId,
    this.isRead = false,
    required this.createdAt,
    this.actorName,
    this.actorAvatar,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      actorId: json['actor_id'],
      type: json['type'],
      postId: json['post_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      actorName: json['actor_name'],
      actorAvatar: json['actor_avatar'],
    );
  }
}
