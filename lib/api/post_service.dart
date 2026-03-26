import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/supabase_service.dart';
import 'session_cache.dart';
import '../config/supabase_config.dart';
import '../config/app_constants.dart';
import '../models/post.dart';

/// Service for handling post-related database operations.
enum FeedMode { popularity, chronological, topWeekly, recentActivity }
enum PostFilter { home, latest, topWeekly, recentActivity }

class PostService {
  static final _client = Supabase.instance.client;

  /// High-level API to fetch filtered and sorted posts.
  /// Accepts [domain] for professional filtering (uses 'Global' for all).
  static Future<List<Map<String, dynamic>>> getPosts({
    int limit = 10,
    int offset = 0,
    String? domain,
    FeedMode mode = FeedMode.popularity,
  }) {
    return getPostsByMode(mode: mode, limit: limit, offset: offset, domain: domain);
  }

  // ============================================================================
  // MASTER FIX: LATEST POSTS & TOP WEEKLY
  // ============================================================================

  static Future<List<Map<String, dynamic>>> getLatestPosts({String? domain}) async {
    dynamic query = _client.from('posts_dim').select('''
          *,
          author:profiles_dim(full_name, avatar_url)
        ''');
    
    if (domain != null && domain.toLowerCase() != 'global' && domain.toLowerCase() != 'all') {
      final ids = _getDomainIds(domain);
      query = query.inFilter('domain_id', ids);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getTopWeeklyPosts({String? domain}) async {
    final now = DateTime.now().toUtc();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    dynamic query = _client.from('posts_dim').select('''
          *,
          author:profiles_dim(full_name, avatar_url)
        ''');

    if (domain != null && domain.toLowerCase() != 'global' && domain.toLowerCase() != 'all') {
      final ids = _getDomainIds(domain);
      query = query.inFilter('domain_id', ids);
    }

    final response = await query
        .gte('created_at', sevenDaysAgo.toIso8601String())
        .order('likes_count', ascending: false)
        .order('created_at', ascending: false);
        
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getRecentActivityPosts() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // 1. Fetch user activities (posts, likes, comments)
    final results = await Future.wait([
      _client.from('posts_dim').select('id, created_at').eq('author_id', userId).limit(20),
      _client.from('likes_fact').select('post_id, created_at').eq('user_id', userId).limit(20),
      _client.from('comments_fact').select('post_id, created_at').eq('author_id', userId).limit(20),
    ]);

    final List<Map<String, dynamic>> activities = [];
    
    // Process Posts
    for (var p in results[0]) {
      activities.add({
        'post_id': p['id'],
        'type': 'Posted',
        'at': DateTime.parse(p['created_at']),
      });
    }
    // Process Likes
    for (var l in results[1]) {
      activities.add({
        'post_id': l['post_id'],
        'type': 'Liked',
        'at': DateTime.parse(l['created_at']),
      });
    }
    // Process Comments
    for (var c in results[2]) {
      activities.add({
        'post_id': c['post_id'],
        'type': 'Commented',
        'at': DateTime.parse(c['created_at']),
      });
    }

    // Sort by activity time DESC
    activities.sort((a, b) => (b['at'] as DateTime).compareTo(a['at'] as DateTime));
    
    if (activities.isEmpty) return [];

    // 2. Fetch full post details for these IDs
    final postIds = activities.map((a) => a['post_id'] as String).toSet().toList();
    final postsResponse = await _client
        .from('posts_dim')
        .select('''
          *,
          author:profiles_dim(full_name, avatar_url)
        ''')
        .inFilter('id', postIds);
        
    final List<Map<String, dynamic>> rawPosts = List<Map<String, dynamic>>.from(postsResponse);
    final Map<String, Map<String, dynamic>> postMap = {for (var p in rawPosts) p['id']: p};

    // 3. Map back to activities with full post data
    return activities.map((act) {
      final postData = postMap[act['post_id']];
      if (postData == null) return null;
      return {
        ...postData,
        'activity_label': act['type'],
        'activity_at': (act['at'] as DateTime).toIso8601String(),
      };
    }).whereType<Map<String, dynamic>>().toList();
  }

  /// Reusable function to fetch posts by feed type.
  static Future<List<Post>> fetchFeed(String feedType, {String? domain}) async {
    List<Map<String, dynamic>> rawPosts = [];
    
    switch (feedType) {
      case "home":
        // Default home feed: newest posts by domain (or global if null)
        rawPosts = await getPostsByMode(mode: FeedMode.chronological, domain: domain);
        break;
      case "latest":
        rawPosts = await getLatestPosts(domain: domain);
        break;
      case "top_weekly":
        rawPosts = await getTopWeeklyPosts(domain: domain);
        break;
      case "recent_activity":
        rawPosts = await getRecentActivityPosts();
        break;
      default:
        rawPosts = await getPostsByMode(mode: FeedMode.popularity);
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    return rawPosts.map((post) {
      final author = post['author'] as Map<String, dynamic>?;
      final Map<String, dynamic> enrichedPost = {
        ...post,
        'author_name': author?['full_name'] ?? 'Unknown',
        'author_avatar': author?['avatar_url'],
        'likes_count': (post['likes_count'] as num?)?.toInt() ?? 0,
        'comments_count': (post['comments_count'] as num?)?.toInt() ?? 0,
      };
      return Post.fromJson(enrichedPost);
    }).toList();
  }

  static void debugVerifyPosts(List<dynamic> posts, String filterName) {
    debugPrint('========== $filterName ==========');
    debugPrint('Total: ${posts.length} posts');
    debugPrint('Last 7 days from: ${DateTime.now().subtract(const Duration(days: 7)).toIso8601String()}');
    debugPrint('');
    
    for (int i = 0; i < posts.length; i++) {
      final post = posts[i] is Map ? posts[i] : (posts[i] as dynamic).toJson();
      final createdAt = post['created_at'] != null 
          ? DateTime.parse(post['created_at']) 
          : DateTime.now();
      final daysAgo = DateTime.now().difference(createdAt).inDays;
      debugPrint('${i+1}. ${post['title'] ?? post['content']?.toString().substring(0, 20)}');
      debugPrint('   Created: $createdAt ($daysAgo days ago)');
      debugPrint('   Likes: ${post['likes_count']}');
      debugPrint('   Comments: ${post['comments_count']}');
      debugPrint('');
    }
    debugPrint('===================================');
  }

  /// Unified dispatcher for different feed types.
  /// Page 0 results are cached in [SessionCache] for the lifetime of the
  /// session — tab switches and widget rebuilds serve from memory.
  /// Pages > 0 bypass the session cache (PostWindowManager handles those).
  static Future<List<Map<String, dynamic>>> getPostsByMode({
    required FeedMode mode,
    int limit = 10,
    int offset = 0,
    String? domain,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    // Only cache the first page — subsequent pages are managed by PostWindowManager
    final isFirstPage = offset == 0;
    if (isFirstPage) {
      final cacheKey = 'feed:${mode.name}:${domain ?? 'all'}:p0';
      return SessionCache.getOrFetch(
        key: cacheKey,
        fetch: () => _fetchPostsByMode(
          mode: mode,
          limit: limit,
          offset: offset,
          domain: domain,
          userId: userId,
        ),
      );
    }

    return _fetchPostsByMode(
      mode: mode,
      limit: limit,
      offset: offset,
      domain: domain,
      userId: userId,
    );
  }

  /// Raw Supabase fetch — called by [getPostsByMode]; never call directly.
  static Future<List<Map<String, dynamic>>> _fetchPostsByMode({
    required FeedMode mode,
    required int limit,
    required int offset,
    required String? domain,
    required String userId,
  }) async {
    // Use the denormalized posts_dim table directly for maximum performance.
    // Joined with profiles_dim for author details.
    dynamic baseQuery = _client.from('posts_dim').select('''
      *,
      author:profiles_dim(full_name, avatar_url)
    ''');

    // ── Reactive Domain Filter ──────────────────────────────────────────
    // Normalize domain string for comparison. 
    // Filter results by domain unless 'Global' or 'All' is selected.
    final String? dNormal = domain?.trim();
    final bool isGlobalLabel = dNormal == null || 
                               dNormal.toLowerCase() == 'global' || 
                               dNormal.toLowerCase() == 'all';

    if (!isGlobalLabel) {
      final domainIds = _getDomainIds(dNormal);
      if (domainIds.length == 1) {
        baseQuery = baseQuery.eq('domain_id', domainIds.first);
      } else {
        baseQuery = baseQuery.inFilter('domain_id', domainIds);
      }
    }

    // ── Sort Logic ─────────────────────────────────────────────────────
    switch (mode) {
      case FeedMode.popularity:
        baseQuery = baseQuery
            .order('likes_count', ascending: false)
            .order('created_at', ascending: false);
        break;

      case FeedMode.chronological:
        baseQuery = baseQuery.order('created_at', ascending: false);
        break;

      case FeedMode.topWeekly:
        final lastWeekISO = DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
        baseQuery = baseQuery
            .gte('created_at', lastWeekISO)
            .order('likes_count', ascending: false)
            .order('created_at', ascending: false);
        break;

      case FeedMode.recentActivity:
        // Handled specially in getRecentActivityPosts, but added here for dispatcher safety
        baseQuery = baseQuery.order('created_at', ascending: false);
        break;
    }

    final response = await baseQuery.range(offset, offset + limit - 1);
    final posts = List<Map<String, dynamic>>.from(response);

    if (posts.isNotEmpty) {
      debugPrint('DEBUG: Fetched ${posts.length} posts for mode $mode');
      for (var p in posts.take(3)) {
        debugPrint('DEBUG: Post ID: ${p['id']} | CreatedAt: ${p['created_at']} | Likes: ${p['likes_count'] ?? p['like_count']}');
      }
    }

    if (posts.isEmpty) return [];

    // Batch-fetch follows and likes in parallel for speed
    final authorIds = posts.map((p) => p['author_id'] as String).toSet().toList();
    final postIds   = posts.map((p) => p['id'] as String).toList();

    final results = await Future.wait<Set<String>>([
      SupabaseService.getFollowStatuses(authorIds),
      SupabaseService.getLikeStatuses(postIds),
    ]);

    final followingSet = results[0];
    final likedSet     = results[1];

    return posts.map((post) {
      final postId   = post['id']        as String;
      final authorId = post['author_id'] as String;
      
      // Flatten the joined author profile
      final author = post['author'] as Map<String, dynamic>?;

      return {
        ...post,
        'author_name':   author?['full_name'] ?? 'Unknown',
        'author_avatar': author?['avatar_url'],
        'likes_count':   (post['likes_count']   as num?)?.toInt() ?? (post['like_count'] as num?)?.toInt() ?? 0,
        'comments_count': (post['comments_count'] as num?)?.toInt() ?? (post['comment_count'] as num?)?.toInt() ?? 0,
        'is_liked':      likedSet.contains(postId),
        'is_following':  followingSet.contains(authorId),
        'is_trending':   mode == FeedMode.topWeekly,
      };
    }).toList();
  }

  /// Upload a post image using strictly Uint8List (Standard for Web/Mobile)
  static Future<String> uploadPostImage({
    required Uint8List bytes,
    required String extension,
  }) async {
    // Size Validation
    if (bytes.length > AppConstants.maxMediaSize) {
      throw Exception('File size exceeds limit (Max: 10MB). Please upload a smaller file.');
    }

    // Type Validation
    final ext = extension.toLowerCase();
    if (!AppConstants.allowedImageExtensions.contains(ext) && 
        !AppConstants.allowedVideoExtensions.contains(ext)) {
      throw Exception('Unsupported file format. Please upload JPG, PNG, or MP4.');
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final bucketFromEnv = () {
      try {
        return dotenv.env['SUPABASE_POST_BUCKET'] ?? SupabaseConfig.postBucket;
      } catch (_) {
        return SupabaseConfig.postBucket;
      }
    }();
    final bucket = bucketFromEnv;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = '$userId/$fileName';
    
    await _client.storage.from(bucket).uploadBinary(
      path, 
      bytes,
      fileOptions: FileOptions(
        contentType: _getMimeType(ext),
        upsert: true,
        cacheControl: AppConstants.defaultCacheControl,
      ),
    );
    
    final url = _client.storage.from(bucket).getPublicUrl(path);
    debugPrint('DEBUG: Uploaded post image URL: $url');
    return url;
  }

  /// Create a new post
  /// [targetDomainId] — if provided, the post appears in THAT domain's feed
  /// instead of the author's own domain.
  static Future<Map<String, dynamic>> createPost({
    required String content,
    String? imageUrl,
    String? targetDomainId,
    bool isAutomated = false,
    String? linkedJobId,
  }) async {
    return SupabaseService.createPost(
      content: content,
      imageUrl: imageUrl,
      targetDomainId: targetDomainId,
      isAutomated: isAutomated,
      linkedJobId: linkedJobId,
    );
  }

  /// Maps a display domain to its set of database identifiers (for legacy content).
  static List<String> _getDomainIds(String domain) {
    switch (domain) {
      case 'Healthcare & Life Sciences':
        return ['Healthcare & Life Sciences', 'Medical', 'Healthcare'];
      case 'Software Development':
        return ['Software Development', 'IT', 'Software', 'Technology'];
      case 'AI, Data & Analytics':
        return ['AI, Data & Analytics', 'AI', 'Data Science', 'Data Analytics'];
      case 'Business, Product & Management':
        return ['Business, Product & Management', 'Business', 'Management', 'Product'];
      case 'Finance, Risk & Compliance':
        return ['Finance, Risk & Compliance', 'Finance', 'Banking'];
      case 'Core Engineering':
        return ['Core Engineering', 'Engineering'];
      case 'Design & Creative':
        return ['Design & Creative', 'Design', 'Creative'];
      case 'Sales, Marketing & CRM':
        return ['Sales, Marketing & CRM', 'Sales', 'Marketing', 'CRM'];
      case 'HR, Operations & Support':
        return ['HR, Operations & Support', 'HR', 'Human Resources', 'Operations'];
      case 'Agriculture & Environmental':
        return ['Agriculture & Environmental', 'Agriculture', 'Environmental'];
      default:
        return [domain];
    }
  }

  static String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'heic': return 'image/heic';
      case 'gif': return 'image/gif';
      case 'mp4': return 'video/mp4';
      case 'jpg':
      case 'jpeg':
      case 'jfif':
        return 'image/jpeg';
      default: return 'application/octet-stream';
    }
  }
}
