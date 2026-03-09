
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

  AppNotification copyWith({
    String? id,
    String? userId,
    String? actorId,
    String? type,
    String? postId,
    bool? isRead,
    DateTime? createdAt,
    String? actorName,
    String? actorAvatar,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      actorId: actorId ?? this.actorId,
      type: type ?? this.type,
      postId: postId ?? this.postId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      actorName: actorName ?? this.actorName,
      actorAvatar: actorAvatar ?? this.actorAvatar,
    );
  }
}
