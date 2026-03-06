import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/supabase_service.dart';
import 'session_cache.dart';
import '../config/supabase_config.dart';


/// Service for handling post-related database operations.
enum FeedMode { popularity, chronological, topWeekly }

class PostService {
  static final _client = Supabase.instance.client;

  /// High-level API to fetch filtered and sorted posts.
  /// Accepts [domain] for professional filtering (uses 'Global' for all).
  static Future<List<Map<String, dynamic>>> fetchPosts({
    int limit = 10,
    int offset = 0,
    String? domain,
    FeedMode mode = FeedMode.popularity,
  }) {
    return getPostsByMode(mode: mode, limit: limit, offset: offset, domain: domain);
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
    // Use the posts_with_stats view which has aggregated counts
    dynamic baseQuery = _client.from('posts_with_stats').select();

    // ── Reactive Domain Filter ──────────────────────────────────────────
    // If 'Global' or 'All' is selected, we omit the filter to show everyone's posts.
    if (domain != null && domain != 'Global' && domain != 'All') {
      baseQuery = baseQuery.eq('domain_id', domain);
    }

    // ── Sort Logic ─────────────────────────────────────────────────────
    switch (mode) {
      case FeedMode.popularity:
        baseQuery = baseQuery
            .order('like_count', ascending: false)
            .order('created_at', ascending: false);
        break;

      case FeedMode.chronological:
        baseQuery = baseQuery.order('created_at', ascending: false);
        break;

      case FeedMode.topWeekly:
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
        baseQuery = baseQuery
            .gt('created_at', sevenDaysAgo)
            .order('like_count', ascending: false)
            .order('created_at', ascending: false);
        break;
    }

    final response = await baseQuery.range(offset, offset + limit - 1);
    final posts = List<Map<String, dynamic>>.from(response);

    // Fallback for Weekly Top: If no trending posts exist, show latest
    if (posts.isEmpty && mode == FeedMode.topWeekly && offset == 0) {
      return _fetchPostsByMode(
        mode: FeedMode.chronological,
        limit: limit,
        offset: offset,
        domain: domain,
        userId: userId,
      );
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
      return {
        ...post,
        'like_count':    (post['like_count']    as num?)?.toInt() ?? 0,
        'comment_count': (post['comment_count'] as num?)?.toInt() ?? 0,
        'is_liked':      likedSet.contains(postId),
        'is_following':  followingSet.contains(authorId),
        'is_trending':   mode == FeedMode.topWeekly,
      };
    }).toList();
  }

  /// High-level alias for chronological feed
  static Future<List<Map<String, dynamic>>> getChronologicalFeed({int limit = 10, int offset = 0, String? domain}) {
    return getPostsByMode(mode: FeedMode.chronological, limit: limit, offset: offset, domain: domain);
  }

  /// Upload a post image using strictly Uint8List (Standard for Web/Mobile)
  static Future<String> uploadPostImage({
    required Uint8List bytes,
    required String extension,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final bucket = dotenv.env['SUPABASE_POST_BUCKET'] ?? SupabaseConfig.postBucket;

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$userId/$fileName';
    
    await _client.storage.from(bucket).uploadBinary(
      path, 
      bytes,
      fileOptions: FileOptions(
        contentType: _getMimeType(extension),
        upsert: true,
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

  static String _getMimeType(String ext) {

    switch (ext.toLowerCase()) {
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'heic': return 'image/heic';
      case 'gif': return 'image/gif';
      case 'jpg':
      case 'jpeg':
      case 'jfif':
        return 'image/jpeg';
      default: return 'image/octet-stream';
    }
  }
}
