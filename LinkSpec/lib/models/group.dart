
class Group {
  final String id;
  final String name;
  final String description;
  final String? coverUrl;
  final String memberCount;
  final String domainId;

  Group({
    required this.id,
    required this.name,
    required this.description,
    this.coverUrl,
    required this.memberCount,
    required this.domainId,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      coverUrl: json['cover_url'],
      memberCount: json['member_count']?.toString() ?? '0',
      domainId: json['domain_id'] ?? '',
    );
  }
}
