class UserProfile {
  final String id;
  final String fullName;
  final String domainId;
  final String? bio;
  final String? avatarUrl;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> projects;
  final List<String> skills;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.domainId,
    this.bio,
    this.avatarUrl,
    this.experience = const [],
    this.education = const [],
    this.projects = const [],
    this.skills = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      domainId: json['domain_id'] as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      experience: List<Map<String, dynamic>>.from(json['experience'] ?? []),
      education: List<Map<String, dynamic>>.from(json['education'] ?? []),
      projects: List<Map<String, dynamic>>.from(json['projects'] ?? []),
      skills: List<String>.from(json['skills'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'domain_id': domainId,
      'bio': bio,
      'avatar_url': avatarUrl,
      'experience': experience,
      'education': education,
      'projects': projects,
      'skills': skills,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? domainId,
    String? bio,
    String? avatarUrl,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? education,
    List<Map<String, dynamic>>? projects,
    List<String>? skills,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      domainId: domainId ?? this.domainId,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      experience: experience ?? this.experience,
      education: education ?? this.education,
      projects: projects ?? this.projects,
      skills: skills ?? this.skills,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, fullName: $fullName, domainId: $domainId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
