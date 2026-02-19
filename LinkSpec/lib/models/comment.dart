
class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  
  // Flattened from profiles table
  final String? authorName;
  final String? authorAvatar;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.authorName,
    this.authorAvatar,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorName: json['author_name'] as String?,
      authorAvatar: json['author_avatar'] as String?,
    );
  }
}
