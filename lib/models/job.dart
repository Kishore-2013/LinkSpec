
class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String domainId;
  final String salary;
  final String description;
  final DateTime postedAt;
  final String type; // Full-time, Remote, etc.
  final bool isSaved;
  final bool hasApplied;
  final String? postedBy;
  final List<String> applicationFormSchema;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.domainId,
    required this.salary,
    required this.description,
    required this.postedAt,
    required this.type,
    this.isSaved = false,
    this.hasApplied = false,
    this.postedBy,
    this.applicationFormSchema = const [],
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      title: json['title'],
      company: json['company'],
      location: json['location'],
      domainId: json['domain_id'],
      salary: json['salary'],
      description: json['description'],
      postedAt: DateTime.parse(json['posted_at']),
      type: json['type'],
      isSaved: json['is_saved'] ?? false,
      hasApplied: json['has_applied'] ?? false,
      postedBy: json['posted_by'],
      applicationFormSchema: json['application_form_schema'] != null 
          ? List<String>.from(json['application_form_schema']) 
          : [],
    );
  }

  Job copyWith({
    bool? isSaved,
    bool? hasApplied,
    String? postedBy,
  }) {
    return Job(
      id: id,
      title: title,
      company: company,
      location: location,
      domainId: domainId,
      salary: salary,
      description: description,
      postedAt: postedAt,
      type: type,
      isSaved: isSaved ?? this.isSaved,
      hasApplied: hasApplied ?? this.hasApplied,
      postedBy: postedBy ?? this.postedBy,
      applicationFormSchema: applicationFormSchema,
    );
  }
}
