import 'package:flutter/foundation.dart';

/// Post Model
class Post {
  final String id;
  final String authorId;
  final String domainId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  final String? imageUrl;
  final bool isAutomated;
  final String? linkedJobId;
  
  // Additional fields from posts_with_stats view
  final String? authorName;
  final String? authorAvatar;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isFollowing;
  final bool isTrending; // Flag for top weekly posts

  Post({
    required this.id,
    required this.authorId,
    required this.domainId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.authorName,
    this.authorAvatar,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isFollowing = false,
    this.isTrending = false,
    this.isAutomated = false,
    this.linkedJobId,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    if (json['image_url'] != null) {
      debugPrint('DEBUG: Model parsing post ${json['id']} with image: ${json['image_url']}');
    }
    return Post(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      domainId: json['domain_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      imageUrl: json['image_url'] as String?,
      authorName: json['author_name'] as String?,
      authorAvatar: json['author_avatar'] as String?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isFollowing: json['is_following'] as bool? ?? false,
      isTrending: json['is_trending'] as bool? ?? false,
      isAutomated: json['is_automated'] as bool? ?? false,
      linkedJobId: json['linked_job_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'domain_id': domainId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'image_url': imageUrl,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'like_count': likeCount,
      'is_automated': isAutomated,
      'linked_job_id': linkedJobId,
    };
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? domainId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imageUrl,
    String? authorName,
    String? authorAvatar,
    int? likeCount,
    bool? isAutomated,
    String? linkedJobId,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      domainId: domainId ?? this.domainId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      likeCount: likeCount ?? this.likeCount,
      isAutomated: isAutomated ?? this.isAutomated,
      linkedJobId: linkedJobId ?? this.linkedJobId,
    );
  }

  @override
  String toString() {
    return 'Post(id: $id, authorId: $authorId, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}...)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Post && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
