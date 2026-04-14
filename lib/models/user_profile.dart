class UserProfile {
  final String id;
  final String fullName;
  final String domainId;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final List<Map<String, dynamic>> experience;
  final List<Map<String, dynamic>> education;
  final List<Map<String, dynamic>> projects;
  final List<String> skills;
  final String? motherDomain;
  final String? tag; // Legacy support
  final String? email;
  final String? verificationStatus; // 'none', 'pending', 'verified'
  final String? workEmail; // Stores semicolon-separated verified emails
  final bool isWorkEmailVerified;
  final String? phone;
  final bool isWorkEmailPublic;
  final bool isPhonePublic;
  final bool isPersonalEmailPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.domainId,
    this.motherDomain,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.experience = const [],
    this.education = const [],
    this.projects = const [],
    this.skills = const [],
    this.tag = 'User',
    this.email,
    this.verificationStatus = 'none',
    this.workEmail,
    this.isWorkEmailVerified = false,
    this.phone,
    this.isWorkEmailPublic = false,
    this.isPhonePublic = false,
    this.isPersonalEmailPublic = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns a list of all verified work emails
  List<String> get verifiedWorkEmails {
    if (workEmail == null || workEmail!.isEmpty) return [];
    return workEmail!.split(';').where((e) => e.isNotEmpty).toList();
  }

  /// Checks if a specific email is in the verified collection
  bool isEmailVerified(String? email) {
    if (email == null || email.isEmpty) return false;
    return verifiedWorkEmails.contains(email.toLowerCase().trim());
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      domainId: json['domain_id'] as String,
      motherDomain: json['mother_domain'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverUrl: json['cover_url'] as String?,
      experience: List<Map<String, dynamic>>.from(json['experience'] ?? []),
      education: List<Map<String, dynamic>>.from(json['education'] ?? []),
      projects: List<Map<String, dynamic>>.from(json['projects'] ?? []),
      skills: List<String>.from(json['skills'] ?? []),
      tag: json['tag'] as String? ?? 'User',
      email: json['email'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'none',
      workEmail: json['work_email'] as String?,
      isWorkEmailVerified: json['is_work_email_verified'] as bool? ?? false,
      phone: json['phone'] as String?,
      isWorkEmailPublic: json['is_work_email_public'] as bool? ?? false,
      isPhonePublic: json['is_phone_public'] as bool? ?? false,
      isPersonalEmailPublic: json['is_personal_email_public'] as bool? ?? false,
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
      'cover_url': coverUrl,
      'experience': experience,
      'education': education,
      'projects': projects,
      'skills': skills,
      'mother_domain': motherDomain,
      'tag': tag,
      'email': email,
      'verification_status': verificationStatus,
      'work_email': workEmail,
      'is_work_email_verified': isWorkEmailVerified,
      'phone': phone,
      'is_work_email_public': isWorkEmailPublic,
      'is_phone_public': isPhonePublic,
      'is_personal_email_public': isPersonalEmailPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? domainId,
    String? motherDomain,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? education,
    List<Map<String, dynamic>>? projects,
    List<String>? skills,
    String? tag,
    String? email,
    String? verificationStatus,
    String? workEmail,
    bool? isWorkEmailVerified,
    String? phone,
    bool? isWorkEmailPublic,
    bool? isPhonePublic,
    bool? isPersonalEmailPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      domainId: domainId ?? this.domainId,
      motherDomain: motherDomain ?? this.motherDomain,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      experience: experience ?? this.experience,
      education: education ?? this.education,
      projects: projects ?? this.projects,
      skills: skills ?? this.skills,
      tag: tag ?? this.tag,
      email: email ?? this.email,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      workEmail: workEmail ?? this.workEmail,
      isWorkEmailVerified: isWorkEmailVerified ?? this.isWorkEmailVerified,
      phone: phone ?? this.phone,
      isWorkEmailPublic: isWorkEmailPublic ?? this.isWorkEmailPublic,
      isPhonePublic: isPhonePublic ?? this.isPhonePublic,
      isPersonalEmailPublic: isPersonalEmailPublic ?? this.isPersonalEmailPublic,
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
