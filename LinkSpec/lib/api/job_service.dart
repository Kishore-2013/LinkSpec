import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'post_service.dart';


/// Service to handle Job-related API calls.
class JobService {
  static final _client = Supabase.instance.client;

  /// Fetch jobs with pagination, filtering, and search.
  static Future<List<Map<String, dynamic>>> fetchJobs({
    int page = 0,
    int pageSize = 10,
    String? query,
    String? domain,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Base query including join with saved_jobs and job_applications to get status flags
    var selectStr = '*, saved_jobs(id), job_applications(id)';
    
    var request = _client
        .from('jobs')
        .select(selectStr);

    // Filter by domain. If not provided, fetch current user's domain to enforce restriction.
    String? domainToUse = domain;
    if (domainToUse == null || domainToUse.isEmpty) {
      final profile = await SupabaseService.getCurrentUserProfile();
      domainToUse = profile?['domain_id'];
    }

    if (domainToUse != null && domainToUse.isNotEmpty) {
      request = request.eq('domain_id', domainToUse);
    }

    // Filter by search query (title or company)
    if (query != null && query.isNotEmpty) {
      request = request.or('title.ilike.%$query%,company.ilike.%$query%');
    }

    // Pagination & Order
    final response = await request
        .order('posted_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final data = List<Map<String, dynamic>>.from(response);

    // Map the relational data to simplified boolean flags
    return data.map((job) {
      final savedList = job['saved_jobs'] as List?;
      final appliedList = job['job_applications'] as List?;
      
      return {
        ...job,
        'is_saved': savedList != null && savedList.isNotEmpty,
        'has_applied': appliedList != null && appliedList.isNotEmpty,
        'posted_by': job['posted_by'],
      };
    }).toList();
  }

  /// Fetch a single job by ID.
  static Future<Map<String, dynamic>?> fetchJobById(String jobId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('jobs')
        .select('*, saved_jobs(id), job_applications(id)')
        .eq('id', jobId)
        .maybeSingle();

    if (response == null) return null;

    final savedList = response['saved_jobs'] as List?;
    final appliedList = response['job_applications'] as List?;

    return {
      ...response,
      'is_saved': savedList != null && savedList.isNotEmpty,
      'has_applied': appliedList != null && appliedList.isNotEmpty,
      'posted_by': response['posted_by'],
    };
  }

  /// Check if the currently logged in user has the 'HR' tag.
  static Future<bool> isCurrentUserHR({String? cachedTag}) async {
    if (cachedTag != null) return cachedTag == 'HR';
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    
    try {
      final profile = await SupabaseService.getUserProfile(userId);
      return profile?['tag'] == 'HR';
    } catch (e) {
      return false;
    }
  }

  /// Create a new job listing (HR only).
  static Future<void> createJob({
    required String title,
    required String company,
    required String location,
    required String type,
    required String salary,
    required String description,
    required String domainId,
    List<String>? applicationFormSchema,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // 1. Verify HR status
    final profile = await SupabaseService.getCurrentUserProfile();
    final bool isHR = profile?['tag'] == 'HR';
    if (!isHR) throw Exception('Unauthorized: Only HR users can create jobs.');

    // Use provided domainId, or fallback to user's domain if somehow null
    final String finalDomain = domainId.isNotEmpty ? domainId : (profile?['domain_id'] ?? 'IT/Software');

    // 2. Insert job and get the created job data
    final jobResponse = await _client.from('jobs').insert({
      'title': title,
      'company': company,
      'location': location,
      'type': type,
      'salary': salary,
      'description': description,
      'domain_id': finalDomain,
      'application_form_schema': applicationFormSchema ?? [],
      'posted_by': userId,
      'posted_at': DateTime.now().toIso8601String(),
    }).select().single();

    final String jobId = jobResponse['id'] as String;

    // 3. Automatically create a social feed post for this job
    try {
      final String postContent = 
          "📢 New Job Alert: $title\n"
          "🏢 Company: $company\n"
          "💰 Salary: $salary\n"
          "📍 Location: $location\n\n"
          "We are looking for talent! View the full details in the Jobs Board. #Hiring #$finalDomain #LinkSpec";

      await PostService.createPost(
        content: postContent,
        targetDomainId: finalDomain,
        isAutomated: true,
        linkedJobId: jobId,
      );
    } catch (e) {
      // Silently fail post creation if it errors, so the job creation itself isn't blocked
      print('JobService: Failed to create automated post for job $jobId: $e');
    }
  }

  /// Fetch all users who applied for a specific job (Job Poster only).
  static Future<List<Map<String, dynamic>>> fetchApplicantsForJob(String jobId) async {
    try {
      final response = await _client
          .from('job_applications')
          .select('''
            *,
            profiles:user_id (
              id,
              full_name,
              avatar_url,
              domain_id,
              skills,
              bio
            )
          ''')
          .eq('job_id', jobId)
          .order('applied_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('JobService error (fetchApplicantsForJob): $e');
      return [];
    }
  }

  /// Submit an application for a specific job.
  static Future<bool> applyForJob(String jobId, {Map<String, dynamic>? answers}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // 1. Check if already applied
      final existing = await _client
          .from('job_applications')
          .select()
          .eq('user_id', userId)
          .eq('job_id', jobId)
          .maybeSingle();

      if (existing != null) return true; // Already applied

      // 2. Insert application
      await _client.from('job_applications').insert({
        'user_id': userId,
        'job_id': jobId,
        'answers_json': answers ?? {},
      });
      
      return true;
    } catch (e) {
      print('JobService error (applyForJob): $e');
      rethrow;
    }
  }

  /// Delete a job listing (Poster only).
  static Future<void> deleteJob(String jobId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // The Supabase RLS policy "Jobs are deletable by poster" handles the safety.
      await _client.from('jobs').delete().eq('id', jobId).eq('posted_by', userId);
    } catch (e) {
      print('JobService error (deleteJob): $e');
      rethrow;
    }
  }

  /// Get real-time stream of new jobs for "New" badge implementation.
  static Stream<List<Map<String, dynamic>>> getLatestJobsStream({int limit = 1}) {
    return _client
        .from('jobs')
        .stream(primaryKey: ['id'])
        .order('posted_at', ascending: false)
        .limit(limit);
  }

  /// Get real-time stream for job applications for jobs posted by the current HR user.
  static Future<Stream<List<Map<String, dynamic>>>> getNewApplicationsStream() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    // 1. Get job IDs created by this HR user
    final jobs = await _client
        .from('jobs')
        .select('id')
        .eq('posted_by', userId);
    
    final jobIds = (jobs as List).map((j) => j['id'] as String).toList();
    if (jobIds.isEmpty) return const Stream.empty();

    // 2. Return stream of applications for those IDs
    return _client
        .from('job_applications')
        .stream(primaryKey: ['id'])
        .order('applied_at', ascending: false)
        .limit(1);
  }
}
