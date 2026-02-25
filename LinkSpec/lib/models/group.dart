
class Group {
  final String id;
  final String name;
  final String description;
  final String? coverUrl;
  final String memberCount;
  final String domainId;
  final DateTime? createdAt;

  Group({
    required this.id,
    required this.name,
    required this.description,
    this.coverUrl,
    required this.memberCount,
    required this.domainId,
    this.createdAt,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      coverUrl: json['cover_url'],
      memberCount: json['member_count']?.toString() ?? '0',
      domainId: json['domain_id'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}
