import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/supabase_config.dart';


// Diagnostic: Force filesystem update. Corrected unread counts.
/// Supabase Service for LinkSpec
/// Handles all database operations with domain-gated logic
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  
  // Cache for current user data to avoid redundant network calls
  static Map<String, dynamic>? _currentUserProfile;
  static String? _myDomain;

  /// Clear image cache to prevent memory-related rendering glitches on Web
  static void optimizeMemory() {
    PaintingBinding.instance.imageCache.clearLiveImages();
    PaintingBinding.instance.imageCache.clear();
  }

  static String? getCurrentUserId() => _client.auth.currentUser?.id;

  /// Send a password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    // Redirect to the dedicated reset-password path on Web
    final String? redirectTo = kIsWeb ? '${Uri.base.origin}/reset-password' : null;
        
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectTo,
    );
  }

  /// Clear the in-memory cache (called on logout)
  static void clearCache() {
    _currentUserProfile = null;
    _myDomain = null;
  }

  /// Sign in with Microsoft (MS360 Professional Login)
  static Future<void> signInWithMicrosoft() async {
    final String? redirectTo = kIsWeb ? Uri.base.origin : null;
    await _client.auth.signInWithOAuth(
      OAuthProvider.azure,
      redirectTo: redirectTo,
    );
  }

  // ============================================================================
  // PROFILE OPERATIONS
  // ============================================================================

  /// Save user profile with domain selection
  /// This is called during onboarding after user registration
  static Future<void> saveDomainSelection({
    required String fullName,
    required String domainId,
    String? bio,
    String? avatarUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client.from('profiles').insert({
      'id': userId,
      'full_name': fullName,
      // mother_domain: permanent home domain set at registration.
      // RLS messaging policies compare this field, not domain_id.
      'mother_domain': domainId,
      // domain_id: current active domain (mirrors mother_domain at sign-up;
      // may diverge later if the user switches domains).
      'domain_id': domainId,
      'bio': bio,
      'avatar_url': avatarUrl,
    });
  }

  /// Update user profile
  static Future<void> updateProfile({
    String? fullName,
    String? bio,
    String? avatarUrl,
    List<Map<String, dynamic>>? experience,
    List<Map<String, dynamic>>? education,
    List<Map<String, dynamic>>? projects,
    List<String>? skills,
  }) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final Map<String, dynamic> updates = {};
    if (fullName != null) updates['full_name'] = fullName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (experience != null) updates['experience'] = experience;
    if (education != null) updates['education'] = education;
    if (projects != null) updates['projects'] = projects;
    if (skills != null) updates['skills'] = skills;

    if (updates.isNotEmpty) {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      
      // Update local cache if avatar or fullName changed
      final profile = _currentUserProfile;
      if (profile != null) {
        if (fullName != null) profile['full_name'] = fullName;
        if (avatarUrl != null) profile['avatar_url'] = avatarUrl;
        if (bio != null) profile['bio'] = bio;
        if (experience != null) profile['experience'] = experience;
        if (education != null) profile['education'] = education;
        if (projects != null) profile['projects'] = projects;
        if (skills != null) profile['skills'] = skills;
      }
    }
  }

  /// Switch the current user's domain
  static Future<void> switchDomain(String newDomain) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('profiles')
        .update({
          'domain_id': newDomain,
          'industry': newDomain,
        })
        .eq('id', userId);
    
    // Clear local cache to force refresh with new domain content
    _myDomain = newDomain;
    final profile = _currentUserProfile;
    if (profile != null) {
      profile['domain_id'] = newDomain;
      profile['industry'] = newDomain;
    }
  }

  /// Upload avatar image and return public URL (Binary-Standard)
  static Future<String> uploadAvatar(Uint8List bytes, String fileName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    final profileBucket = () {
      try {
        return dotenv.env['SUPABASE_PROFILE_BUCKET'] ?? SupabaseConfig.profileBucket;
      } catch (_) {
        return SupabaseConfig.profileBucket;
      }
    }();

    final ext = fileName.split('.').last.toLowerCase();
    final path = 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    await _client.storage.from(profileBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true, 
        contentType: _getMimeType(ext),
      ),
    );
    final url = _client.storage.from(profileBucket).getPublicUrl(path);
    await _client.from('profiles').update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  /// Upload cover photo and return public URL (Binary-Standard)
  static Future<String> uploadCoverPhoto(Uint8List bytes, String fileName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    
    final profileBucket = () {
      try {
        return dotenv.env['SUPABASE_PROFILE_BUCKET'] ?? SupabaseConfig.profileBucket;
      } catch (_) {
        return SupabaseConfig.profileBucket;
      }
    }();

    final ext = fileName.split('.').last.toLowerCase();
    final path = 'covers/$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    await _client.storage.from(profileBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        upsert: true, 
        contentType: _getMimeType(ext),
      ),
    );
    final url = _client.storage.from(profileBucket).getPublicUrl(path);
    await _client.from('profiles').update({'cover_url': url}).eq('id', userId);
    return url;
  }

  static String _getMimeType(String ext) {
    switch (ext) {
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'heic': return 'image/heic';
      case 'gif': return 'image/gif';
      case 'jpg':
      case 'jpeg':
      case 'jfif':
        return 'image/jpeg';
      default: return 'image/octet-stream'; // Safe fallback for binary data
    }
  }

  /// Get current user's profile with in-memory caching
  static Future<Map<String, dynamic>?> getCurrentUserProfile({bool forceRefresh = false}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      // Return cached profile if available and not forcing refresh
      if (_currentUserProfile != null && !forceRefresh) {
        return _currentUserProfile;
      }

      var profile = await getUserProfile(userId);
      
      // If profile is missing, it might be due to database trigger lag.
      // Retry once after a short delay.
      if (profile == null) {
        await Future.delayed(const Duration(milliseconds: 1500));
        profile = await getUserProfile(userId);
      }

      if (profile != null) {
        _currentUserProfile = profile;
        _myDomain = profile['domain_id'] as String?;
      }
      return profile;
    } on AuthException catch (e) {
      // 422 usually means the session is invalid or stale.
      if (e.statusCode == '422' || e.message.contains('422')) {
        await _client.auth.signOut();
      }
      debugPrint('SupabaseService: Auth error in getCurrentUserProfile: $e');
      rethrow; // Let the caller handle UI fallback
    } catch (e) {
      debugPrint('SupabaseService: Unexpected error in getCurrentUserProfile: $e');
      rethrow;
    }
  }

  /// Get a specific user's profile by ID
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('SupabaseService: Error fetching profile for $userId: $e');
      return null;
    }
  }

  /// Get total post count for a user
  static Future<int> getUserPostCount(String userId) async {
    final response = await _client
        .from('posts')
        .select('id')
        .eq('author_id', userId)
        .count(CountOption.exact);
    
    return response.count;
  }

  /// Get users in the same domain (optimized with cached domain and server-side filtering)
  static Future<List<Map<String, dynamic>>> getProfilesInSameDomain({
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    if (_myDomain == null) {
      await getCurrentUserProfile();
    }
    
    final domain = _myDomain;
    if (domain == null) return [];

    var query = _client
        .from('profiles')
        .select()
        .eq('domain_id', domain);
        
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('full_name', '%$searchQuery%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get ALL users in the database (no domain filter).
  /// Used for the messaging directory so users can message anyone.
  static Future<List<Map<String, dynamic>>> getAllProfiles({
    int limit = 100,
    int offset = 0,
    String? searchQuery,
  }) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    var query = _client
        .from('profiles')
        .select()
        .neq('id', myId); // exclude self

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('full_name', '%$searchQuery%');
    }

    final response = await query
        .order('full_name', ascending: true)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Check if user has completed domain selection
  static Future<bool> hasCompletedDomainSelection() async {
    final profile = await getCurrentUserProfile();
    return profile != null && profile['domain_id'] != null;
  }

  /// Global search for posts — hashtag-aware.
  ///
  /// • Queries < 2 characters or without any letter/digit are ignored (returns []).
  /// • If [query] starts with '#', we look for the exact hashtag token in content.
  /// • Otherwise we search for the query as a hashtag (prefix-match, e.g. '#med' → '#Medical')
  ///   AND as a plain word. Single chars like '.' are rejected.
  static Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    return searchPostsByHashtag(query);
  }

  /// Core hashtag-aware implementation (also called by SearchManager).
  static Future<List<Map<String, dynamic>>> searchPostsByHashtag(String rawQuery) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Reject trivially short or symbol-only queries.
    final q = rawQuery.trim();
    if (q.length < 2 || !q.contains(RegExp(r'[a-zA-Z0-9]'))) return [];

    // Normalise: strip leading '#'
    final tagWord = q.startsWith('#') ? q.substring(1) : q;

    // Build the filter: match '#<tagWord>' as a word boundary token.
    // We look for the literal string '#<tag>' inside content (case-insensitive).
    final filter = '#$tagWord';

    final response = await _client
        .from('posts')
        .select('''
          *,
          profiles:author_id (
            full_name,
            avatar_url,
            domain_id
          ),
          likes:likes(count),
          comments:comments(count)
        ''')
        .ilike('content', '%$filter%')
        .order('created_at', ascending: false)
        .limit(30);

    final rawPosts = List<Map<String, dynamic>>.from(response);
    return _mapPostResponse(rawPosts);
  }

  /// Refactored helper to map raw Supabase rows into curated Post objects.
  /// Deduplicates mapping logic across all post-fetching methods.
  static Future<List<Map<String, dynamic>>> _mapPostResponse(List<Map<String, dynamic>> posts) async {
    if (posts.isEmpty) return [];

    final postIds = posts.map((p) => p['id'] as String).toList();
    final authorIds = posts.map((p) => p['author_id'] as String).toSet().toList();
    
    // Optimized: Fetch like/follow statuses concurrently
    final results = await Future.wait([
      getLikeStatuses(postIds),
      getFollowStatuses(authorIds),
    ]);
    
    final likedSet = results[0];
    final followingSet = results[1];

    return posts.map((post) {
      final profile = post['profiles'];
      final postId = post['id'] as String;
      final authorId = post['author_id'] as String;

      // Logic: Prefer joined profile data, fallback to flat fields if RPC result
      final likeData = post['likes'] as List?;
      final likeCount = (likeData != null && likeData.isNotEmpty) 
          ? (likeData[0]['count'] ?? 0) 
          : (post['like_count'] ?? 0);

      final commentData = post['comments'] as List?;
      final commentCount = (commentData != null && commentData.isNotEmpty) 
          ? (commentData[0]['count'] ?? 0) 
          : (post['comment_count'] ?? 0);

      return {
        ...post,
        'author_name': profile?['full_name'] ?? post['author_name'],
        'author_avatar': profile?['avatar_url'] ?? post['author_avatar'],
        'author_domain': profile?['domain_id'] ?? post['author_domain'],
        'like_count': (likeCount as num).toInt(),
        'comment_count': (commentCount as num).toInt(),
        'is_liked': likedSet.contains(postId),
        'is_following': followingSet.contains(authorId),
      };
    }).toList();
  }

  /// Global search for people across all domains
  static Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final response = await _client
        .from('profiles')
        .select()
        .or('full_name.ilike.%$query%,bio.ilike.%$query%')
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Search for people only among accepted connections
  static Future<List<Map<String, dynamic>>> searchConnections(String query) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      // 1. Get IDs of accepted connections
      final requests = await _client
          .from('connection_requests')
          .select('sender_id, receiver_id')
          .eq('status', 'accepted')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId');

      final connectionIds = (requests as List).map((req) {
        return req['sender_id'] == myId ? req['receiver_id'] : req['sender_id'];
      }).cast<String>().toList();

      if (connectionIds.isEmpty) return [];

      // 2. Search profiles among these IDs
      final response = await _client
          .from('profiles')
          .select()
          .inFilter('id', connectionIds)
          .or('full_name.ilike.%$query%,bio.ilike.%$query%')
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching connections: $e');
      return [];
    }
  }

  // ============================================================================
  // POST OPERATIONS
  // ============================================================================

  /// Create a new post
  /// [targetDomainId] — if provided, the post appears in THAT domain's feed
  /// instead of the author's own domain (useful for cross-domain job posts, etc.).
  static Future<Map<String, dynamic>> createPost({
    required String content,
    String? imageUrl,
    String? targetDomainId, // Optional: override target domain
    bool isAutomated = false,
    String? linkedJobId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Use target domain if provided, otherwise default to user's domain
    String? domainId = targetDomainId;
    if (domainId == null) {
      final profile = await _client
          .from('profiles')
          .select('domain_id')
          .eq('id', userId)
          .maybeSingle();
      domainId = profile?['domain_id'];
    }

    final payload = <String, dynamic>{
      'author_id': userId,
      'content': content,
      if (imageUrl != null) 'image_url': imageUrl,
      if (domainId != null) 'domain_id': domainId,
      // Only include automated fields if they're actually set
      // (gracefully skipped if columns don't yet exist in the DB)
      if (isAutomated) 'is_automated': true,
      if (linkedJobId != null) 'linked_job_id': linkedJobId,
    };
    debugPrint('DEBUG: Creating post with payload: $payload');

    final response = await _client
        .from('posts')
        .insert(payload)
        .select()
        .single();
    debugPrint('DEBUG: Post created response: $response');

    return response;
  }

  /// Get posts sorted by like count (most liked first).
  /// Falls back to creation date as a tie-breaker.
  /// Uses the [get_posts_by_domain_sorted] Postgres RPC so sorting
  /// happens entirely in the database — PostgREST cannot sort by aggregate counts directly.
  static Future<List<Map<String, dynamic>>> getPosts({
    int limit = 20,
    int offset = 0,
    String? domain,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Resolve domain
    String? filterDomain = domain;
    if (filterDomain == null) {
      if (_myDomain == null) await getCurrentUserProfile();
      filterDomain = _myDomain;
    } else {
      _myDomain = filterDomain;
    }

    if (filterDomain == null) return [];

    // Call the RPC — sorted by like_count DESC, then created_at DESC
    final response = await _client.rpc(
      'get_posts_by_domain_sorted',
      params: {
        'p_domain': filterDomain,
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    final rawPosts = List<Map<String, dynamic>>.from(response as List);
    return _mapPostResponse(rawPosts);
  }

  /// Batch check if current user liked posts
  static Future<Set<String>> getLikeStatuses(List<String> postIds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || postIds.isEmpty) return {};

    final response = await _client
        .from('likes')
        .select('post_id')
        .eq('user_id', userId)
        .inFilter('post_id', postIds);

    return (response as List).map((row) => row['post_id'] as String).toSet();
  }

  /// Get posts by a specific user with full insights
  static Future<List<Map<String, dynamic>>> getPostsByUser({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from('posts')
        .select('''
          *,
          profiles:author_id (
            full_name,
            avatar_url,
            domain_id
          ),
          likes:likes(count),
          comments:comments(count)
        ''')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final rawPosts = List<Map<String, dynamic>>.from(response);
    return _mapPostResponse(rawPosts);
  }

  /// Update a post
  static Future<void> updatePost({
    required String postId,
    required String content,
  }) async {
    await _client
        .from('posts')
        .update({'content': content})
        .eq('id', postId);
  }

  /// Delete a post
  static Future<void> deletePost(String postId) async {
    await _client
        .from('posts')
        .delete()
        .eq('id', postId);
  }

  /// Get specific posts by their IDs (Optimized for Saved Items)
  static Future<List<Map<String, dynamic>>> getPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) return [];

    final response = await _client
        .from('posts')
        .select('''
          *,
          profiles:author_id (
            full_name,
            avatar_url,
            domain_id
          ),
          likes:likes(count),
          comments:comments(count)
        ''')
        .filter('id', 'in', postIds);

    final rawPosts = List<Map<String, dynamic>>.from(response);
    return _mapPostResponse(rawPosts);
  }

  /// Increment post view count
  static Future<void> incrementViewCount(String postId) async {
    try {
      await _client.rpc('increment_post_views', params: {'post_id': postId});
    } catch (_) {
      // Fallback if RPC not defined
      try {
        await _client.from('posts').update({
          'views_count': (await _client.from('posts').select('views_count').eq('id', postId).single())['views_count'] + 1
        }).eq('id', postId);
      } catch (e) {
        print('Error incrementing views: $e');
      }
    }
  }

  /// Increment post share count
  static Future<void> incrementShareCount(String postId) async {
    try {
      await _client.rpc('increment_post_shares', params: {'post_id': postId});
    } catch (_) {
      // Fallback
      try {
        await _client.from('posts').update({
          'shares_count': (await _client.from('posts').select('shares_count').eq('id', postId).single())['shares_count'] + 1
        }).eq('id', postId);
      } catch (e) {
        print('Error incrementing shares: $e');
      }
    }
  }

  // ============================================================================
  // LIKE OPERATIONS
  // ============================================================================

  /// Like a post
  static Future<void> likePost(String postId) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client.from('likes').insert({
      'post_id': postId,
      'user_id': userId,
    });
  }

  /// Unlike a post
  static Future<void> unlikePost(String postId) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client
        .from('likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  /// Check if current user has liked a post
  static Future<bool> hasLikedPost(String postId) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      return false;
    }

    final response = await _client
        .from('likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null;
  }

  // ============================================================================
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Send a message to any user — no domain restriction.
  static Future<void> sendMessage({
    required String receiverId,
    String? content,
    String? postId,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) throw Exception('User not authenticated');

    await _client.from('messages').insert({
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'post_id': postId,
    });
  }

  static Future<List<Map<String, dynamic>>> getMessages(String otherUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _client
        .from('messages')
        .select('''
          *,
          posts:post_id (
            *,
            profiles:author_id (
              full_name,
              avatar_url
            )
          )
        ''')
        .or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)')
        .order('created_at', ascending: true);

    final messages = List<Map<String, dynamic>>.from(response);
    
    // Flatten post author info so Post.fromJson works correctly
    return messages.map((msg) {
      if (msg['posts'] != null) {
        final post = Map<String, dynamic>.from(msg['posts']);
        final profile = post['profiles'];
        if (profile != null) {
          post['author_name'] = profile['full_name'];
          post['author_avatar'] = profile['avatar_url'];
        }
        msg['posts'] = post;
      }
      return msg;
    }).toList();
  }

  /// Get count of unread messages for current user.
  /// Catches both is_read = false AND is_read = NULL (Supabase column default
  /// is often NULL rather than false, so .eq('is_read', false) misses them).
  static Future<int> getUnreadMessageCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final response = await _client
          .from('messages')
          .select('id')
          .eq('receiver_id', userId)
          .or('is_read.eq.false,is_read.is.null')
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('getUnreadMessageCount error: $e');
      return 0;
    }
  }

  /// Get the set of sender IDs that have sent unread messages to the current user.
  /// Used to drive the per-user blue bubble indicator in the messaging directory.
  static Future<Set<String>> getUnreadSenderIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final response = await _client
          .from('messages')
          .select('sender_id')
          .eq('receiver_id', userId)
          .or('is_read.eq.false,is_read.is.null');
      return (response as List)
          .map((row) => row['sender_id'] as String)
          .toSet();
    } catch (e) {
      debugPrint('getUnreadSenderIds error: $e');
      return {};
    }
  }

  /// Mark all messages from a specific sender as read.
  static Future<void> markMessagesAsRead(String otherUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('receiver_id', userId)
          .eq('sender_id', otherUserId)
          .or('is_read.eq.false,is_read.is.null'); // mark NULL and false rows
    } catch (e) {
      // Surface the error so it's visible during debugging rather than failing silently
      debugPrint('markMessagesAsRead error (senderId=$otherUserId): $e');
    }
  }

  /// Mark ALL messages for current user as read
  static Future<void> markAllMessagesAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // Simplest approach: mark all where we are the receiver as read.
      // This bypasses any NULL vs false logic issues.
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('receiver_id', userId);
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Get list of unique users the current user has chatted with
  static Future<List<Map<String, dynamic>>> getConversations() async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    // Fetch all messages involving the user
    final response = await _client
        .from('messages')
        .select('''
          sender_id,
          receiver_id,
          sender:profiles!sender_id (id, full_name, avatar_url, domain_id),
          receiver:profiles!receiver_id (id, full_name, avatar_url, domain_id)
        ''')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .order('created_at', ascending: false);

    final messages = List<Map<String, dynamic>>.from(response);
    final Map<String, Map<String, dynamic>> uniqueUsers = {};

    for (var msg in messages) {
      final otherUser = msg['sender_id'] == myId ? msg['receiver'] : msg['sender'];
      if (otherUser != null && !uniqueUsers.containsKey(otherUser['id'])) {
        uniqueUsers[otherUser['id']] = Map<String, dynamic>.from(otherUser);
      }
    }

    return uniqueUsers.values.toList();
  }

  /// Subscribe to new messages for the current user
  static RealtimeChannel subscribeToMessages({
    required void Function(Map<String, dynamic> message) onNewMessage,
  }) {
    final myId = _client.auth.currentUser?.id;
    
    return _client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final msg = payload.newRecord;
            if (msg['receiver_id'] == myId || msg['sender_id'] == myId) {
              onNewMessage(msg);
            }
          },
        )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
          // Silently handle WebSocket failures
        });
  }

  // ============================================================================
  // FOLLOW OPERATIONS (one-way)
  // ============================================================================

  /// Follow a user
  static Future<void> followUser(String followingId) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client.from('connections').insert({
      'follower_id': userId,
      'following_id': followingId,
    });
  }

  /// Unfollow a user
  static Future<void> unfollowUser(String followingId) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _client
        .from('connections')
        .delete()
        .eq('follower_id', userId)
        .eq('following_id', followingId);
  }

  /// Check if current user is following another user
  static Future<bool> isFollowing(String followingId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('connections')
        .select()
        .eq('follower_id', userId)
        .eq('following_id', followingId)
        .maybeSingle();

    return response != null;
  }

  /// Batch check follow status (Optimized)
  static Future<Set<String>> getFollowStatuses(List<String> targetUserIds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || targetUserIds.isEmpty) return {};

    final response = await _client
        .from('connections')
        .select('following_id')
        .eq('follower_id', userId)
        .inFilter('following_id', targetUserIds);

    return (response as List).map((row) => row['following_id'] as String).toSet();
  }

  /// Get followers of a user
  static Future<List<Map<String, dynamic>>> getFollowers({
    required String userId,
    int limit = 50,
  }) async {
    final response = await _client
        .from('connections')
        .select('follower_id, profiles!connections_follower_id_fkey(*)')
        .eq('following_id', userId)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get users that a user is following
  static Future<List<Map<String, dynamic>>> getFollowing({
    required String userId,
    int limit = 50,
  }) async {
    final response = await _client
        .from('connections')
        .select('following_id, profiles!connections_following_id_fkey(*)')
        .eq('follower_id', userId)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get follower and following counts
  static Future<Map<String, int>> getConnectionCounts(String userId) async {
    // Count followers
    final followersData = await _client
        .from('connections')
        .select('id')
        .eq('following_id', userId);
    
    // Count following
    final followingData = await _client
        .from('connections')
        .select('id')
        .eq('follower_id', userId);

    return {
      'followers': (followersData as List).length,
      'following': (followingData as List).length,
    };
  }

  // ============================================================================
  // UNITE OPERATIONS (mutual connection requests)
  // ============================================================================

  /// Send a unite request to another user
  /// Status flow: pending → accepted
  static Future<void> sendUniteRequest(String targetUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('connection_requests').insert({
      'sender_id': userId,
      'receiver_id': targetUserId,
      'status': 'pending',
    });
  }

  /// Withdraw a pending unite request
  static Future<void> withdrawUniteRequest(String targetUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('connection_requests')
        .delete()
        .eq('sender_id', userId)
        .eq('receiver_id', targetUserId);
  }

  /// Accept a unite request from another user
  static Future<void> acceptUniteRequest(String senderUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('connection_requests')
        .update({'status': 'accepted'})
        .eq('sender_id', senderUserId)
        .eq('receiver_id', userId);
  }

  /// Disconnect (remove accepted connection)
  static Future<void> removeConnection(String otherUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Remove in both directions
    await _client
        .from('connection_requests')
        .delete()
        .or('and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)');
  }

  /// Get the connection request status between the current user and another user
  /// Returns: 'none' | 'pending_sent' | 'pending_received' | 'connected'
  static Future<String> getConnectionRequestStatus(String otherUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 'none';

    try {
      // Check if we sent a request
      final sent = await _client
          .from('connection_requests')
          .select('status')
          .eq('sender_id', userId)
          .eq('receiver_id', otherUserId)
          .maybeSingle();

      if (sent != null) {
        return sent['status'] == 'accepted' ? 'connected' : 'pending_sent';
      }

      // Check if they sent us a request
      final received = await _client
          .from('connection_requests')
          .select('status')
          .eq('sender_id', otherUserId)
          .eq('receiver_id', userId)
          .maybeSingle();

      if (received != null) {
        return received['status'] == 'accepted' ? 'connected' : 'pending_received';
      }
    } catch (_) {
      // Table might not exist yet — treat as none
    }

    return 'none';
  }

  /// Batch check connection statuses (Optimized)
  /// Returns: Map<userId, status>
  static Future<Map<String, String>> getConnectionStatuses(List<String> targetUserIds) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || targetUserIds.isEmpty) return {};

    try {
      final List<dynamic> response = await _client
          .from('connection_requests')
          .select()
          .or('sender_id.eq.$userId,receiver_id.eq.$userId');

      final Map<String, String> statusMap = {};
      for (var id in targetUserIds) statusMap[id] = 'none';

      for (var req in response) {
        final String senderId = req['sender_id'];
        final String receiverId = req['receiver_id'];
        final String status = req['status'];
        final String otherId = senderId == userId ? receiverId : senderId;

        if (!targetUserIds.contains(otherId)) continue;

        if (status == 'accepted') {
          statusMap[otherId] = 'connected';
        } else if (senderId == userId) {
          statusMap[otherId] = 'pending_sent';
        } else {
          statusMap[otherId] = 'pending_received';
        }
      }
      return statusMap;
    } catch (_) {
      return {};
    }
  }

  /// Get unite (mutual) count for a user
  static Future<int> getUniteCount(String userId) async {
    try {
      final myId = _client.auth.currentUser?.id;
      if (myId == null) return 0;
      final data = await _client
          .from('connection_requests')
          .select('id')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .eq('status', 'accepted');
      return (data as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Get list of mutual connections (accepted) with profiles
  static Future<List<Map<String, dynamic>>> getAcceptedConnections(String userId) async {
    try {
      final response = await _client
          .from('connection_requests')
          .select('sender_id, receiver_id, sender:profiles!connection_requests_sender_id_fkey(*), receiver:profiles!connection_requests_receiver_id_fkey(*)')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .eq('status', 'accepted');
      
      final List<Map<String, dynamic>> connections = [];
      for (var row in (response as List)) {
        if (row['sender_id'] == userId) {
          if (row['receiver'] != null) {
            connections.add(row['receiver'] as Map<String, dynamic>);
          }
        } else {
          if (row['sender'] != null) {
            connections.add(row['sender'] as Map<String, dynamic>);
          }
        }
      }
      return connections;
    } catch (e) {
      debugPrint('Error fetching connections: $e');
      return [];
    }
  }

  // ============================================================================
  // REALTIME SUBSCRIPTIONS
  // ============================================================================

  /// Subscribe to new posts in the user's domain
  static RealtimeChannel subscribeToNewPosts({
    required void Function(Map<String, dynamic> post) onNewPost,
  }) {
    return _client
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            onNewPost(payload.newRecord);
          },
        )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
          // Silently handle WebSocket failures
        });
  }

  /// Subscribe to likes on a specific post
  static RealtimeChannel subscribeToPostLikes({
    required String postId,
    required void Function(Map<String, dynamic> like) onLike,
    required void Function(Map<String, dynamic> like) onUnlike,
  }) {
    return _client
        .channel('public:likes:$postId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            onLike(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'likes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            onUnlike(payload.oldRecord);
          },
        )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
          // Silently handle WebSocket failures
        });
  }

  /// Get jobs for the user's domain (Optimized)
  static Future<List<Map<String, dynamic>>> getJobs() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Ensure domain is cached
    if (_myDomain == null) {
      await getCurrentUserProfile();
    }

    var query = _client.from('jobs').select('*, saved_jobs(id)');
    
    // Filter by domain if available
    final domain = _myDomain;
    if (domain != null) {
      query = query.eq('domain_id', domain);
    }
    
    final response = await query.order('posted_at', ascending: false);
    
    final data = List<Map<String, dynamic>>.from(response);
    return data.map((job) {
      final saved = job['saved_jobs'] as List?;
      return {
        ...job,
        'is_saved': saved != null && saved.isNotEmpty,
      };
    }).toList();
  }

  /// Get groups for the user's domain
  static Future<List<Map<String, dynamic>>> getGroups() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    if (_myDomain == null) {
      await getCurrentUserProfile();
    }

    final query = _client.from('groups').select();
    
    final domain = _myDomain;
    if (domain != null) {
      return List<Map<String, dynamic>>.from(
        await query.eq('domain_id', domain).order('created_at', ascending: false)
      );
    }
    
    return List<Map<String, dynamic>>.from(await query.order('created_at', ascending: false));
  }

  /// Create a new group
  static Future<void> createGroup({
    required String name,
    required String description,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Fetch the freshest domain directly from the profile to ensure RLS compliance
    final profile = await _client
        .from('profiles')
        .select('domain_id')
        .eq('id', userId)
        .maybeSingle();
    
    final domainId = profile?['domain_id'];
    if (domainId == null) throw Exception('User domain not found. Please complete your profile.');

    await _client.from('groups').insert({
      'name': name,
      'description': description,
      'domain_id': domainId,
    });
  }

  /// Get events for the user's domain
  static Future<List<Map<String, dynamic>>> getEvents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    if (_myDomain == null) {
      await getCurrentUserProfile();
    }

    final query = _client.from('events').select();
    
    final domain = _myDomain;
    if (domain != null) {
      return List<Map<String, dynamic>>.from(
        await query.eq('domain_id', domain).order('date', ascending: true)
      );
    }
    
    return List<Map<String, dynamic>>.from(await query.order('date', ascending: true));
  }

  /// Check if a job is saved by the current user
  static Future<bool> isJobSaved(String jobId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _client
        .from('saved_jobs')
        .select()
        .eq('user_id', userId)
        .eq('job_id', jobId)
        .maybeSingle();
    
    return response != null;
  }

  /// Save a job
  static Future<void> saveJob(String jobId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('saved_jobs').insert({
      'user_id': userId,
      'job_id': jobId,
    });
  }

  /// Unsave a job
  static Future<void> unsaveJob(String jobId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('saved_jobs')
        .delete()
        .eq('user_id', userId)
        .eq('job_id', jobId);
  }
  // ============================================================================
  // COMMENT OPERATIONS
  // ============================================================================

  /// Create a new comment (supports replies via parentId)
  static Future<void> createComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('comments').insert({
      'post_id': postId,
      'author_id': userId,
      'content': content,
      'parent_id': parentId,
    });
  }

  /// Get comments for a specific post (including like info)
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final userId = _client.auth.currentUser?.id;
    
    final response = await _client
        .from('comments')
        .select('''
          *,
          profiles:author_id (
            full_name,
            avatar_url
          ),
          likes:comment_likes(user_id)
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    final comments = List<Map<String, dynamic>>.from(response);
    return comments.map((comment) {
      final profile = comment['profiles'];
      final likes = comment['likes'] as List? ?? [];
      
      return {
        ...comment,
        'author_name': profile?['full_name'],
        'author_avatar': profile?['avatar_url'],
        'like_count': likes.length,
        'is_liked': userId != null && likes.any((l) => l['user_id'] == userId),
      };
    }).toList();
  }

  /// Toggle like on a comment
  static Future<bool> toggleCommentLike(String commentId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      // Check if already liked
      final existing = await _client
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        // Unlike
        await _client
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', userId);
        return false; // Now unliked
      } else {
        // Like
        await _client.from('comment_likes').insert({
          'comment_id': commentId,
          'user_id': userId,
        });
        return true; // Now liked
      }
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
      return false;
    }
  }

  /// Get comment count for a post
  static Future<int> getCommentCount(String postId) async {
    final response = await _client
        .from('comments')
        .select('id')
        .eq('post_id', postId);
    
    return (response as List).length;
  }

  // ============================================================================
  // NOTIFICATION OPERATIONS
  // ============================================================================

  /// Get count of unread notifications for the current user.
  static Future<int> getUnreadNotificationCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false)
          .count(CountOption.exact);
      return response.count;
    } catch (e) {
      debugPrint('getUnreadNotificationCount error: $e');
      return 0;
    }
  }

  /// Get notifications for the current user
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select('''
          *,
          actor:profiles!actor_id (
            full_name,
            avatar_url
          )
        ''')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final notifications = List<Map<String, dynamic>>.from(response);
    return notifications.map((notif) {
      final actor = notif['actor'];
      return {
        ...notif,
        'actor_name': actor?['full_name'],
        'actor_avatar': actor?['avatar_url'],
      };
    }).toList();
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  // Inflight guard — prevents concurrent callers from stacking up identical
  // SELECT + UPDATE round-trips when the user opens the notifications tab quickly.
  static bool _isMarkingAllRead = false;

  /// Mark all notifications for the current user as read
  static Future<void> markAllNotificationsAsRead() async {
    if (_isMarkingAllRead) return; // ← debounce: drop concurrent calls
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _isMarkingAllRead = true;
    try {
      // 1. Get IDs of all unread notifications first
      final unreadResponse = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .neq('is_read', true);

      final unreadList = unreadResponse as List;
      if (unreadList.isEmpty) return; // nothing to do — no log needed

      final ids = unreadList.map((n) => n['id'] as String).toList();

      // 2. Update them specifically by ID (more reliable with RLS)
      await _client
          .from('notifications')
          .update({'is_read': true})
          .filter('id', 'in', ids);
    } catch (e) {
      debugPrint('CRITICAL ERROR in markAllNotificationsAsRead: $e');
    } finally {
      _isMarkingAllRead = false;
    }
  }

  /// Delete a specific notification (Nuclear option for stuck badges)
  static Future<void> deleteNotification(String id) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    
    try {
      final response = await _client
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', userId)
          .select();
          
      if (response.isEmpty) {
        debugPrint('WARNING: No notification was deleted. Check IDs or RLS policies.');
      } else {
        debugPrint('DATABASE: Successfully deleted notification $id');
      }
    } catch (e) {
      debugPrint('ERROR deleting notification: $e');
      rethrow; // So UI can catch it
    }
  }

  /// Get real-time notifications stream.
  /// WebSocket / Realtime errors (e.g. on Chrome) are swallowed so
  /// the app does not crash — REST features continue to work normally.
  static Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    // Use a combined approach: Realtime for fast updates, but error handling for reliability
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .handleError((e) {
          print('Suppressing non-fatal notification stream error: $e');
        })
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // ============================================================================
  // SIDEBAR — TRENDING TAGS
  // Scan the last 100 posts in [domain], regex-extract #hashtags, return top [limit].
  // ============================================================================
  static Future<List<String>> getTrendingTags({
    required String domain,
    int scanLimit = 100,
    int limit = 5,
  }) async {
    final rows = await _client
        .from('posts')
        .select('content')
        .eq('domain_id', domain)
        .order('created_at', ascending: false)
        .limit(scanLimit);

    final tagCount = <String, int>{};
    final hashtagRe = RegExp(r'#(\w+)', caseSensitive: false);

    for (final row in rows) {
      final content = (row['content'] as String?) ?? '';
      for (final m in hashtagRe.allMatches(content)) {
        final match = m.group(1);
        if (match != null) {
          final tag = '#${match.toLowerCase()}';
          tagCount[tag] = (tagCount[tag] ?? 0) + 1;
        }
      }
    }

    if (tagCount.isEmpty) return [];

    final sorted = tagCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  // ============================================================================
  // SIDEBAR — SUGGESTED DISCUSSIONS
  // Top [limit] posts by comment_count from [domain].
  // Requires posts_with_stats view (which includes comment_count).
  // ============================================================================
  static Future<List<Map<String, dynamic>>> getSuggestedDiscussions({
    required String domain,
    int limit = 3,
  }) async {
    try {
      final rows = await _client
          .from('posts_with_stats')
          .select('id, content, comment_count, created_at, domain_id')
          .eq('domain_id', domain)
          .order('comment_count', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      // Fallback: query posts directly if view unavailable
      final rows = await _client
          .from('posts')
          .select('id, content, created_at')
          .eq('domain_id', domain)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    }
  }

  // ============================================================================
  // SIDEBAR — UPCOMING EVENTS  (date >= today)
  // ============================================================================
  static Future<List<Map<String, dynamic>>> getUpcomingEvents({int limit = 5}) async {
    try {
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      final rows = await _client
          .from('events')
          .select('id, title, date, location')
          .gte('date', today)
          .order('date', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      // Return empty list if events table doesn't exist or has schema issues
      return [];
    }
  }

  // ============================================================================
  // SIDEBAR — MY RECENT ACTIVITY  (current user only, auth.uid()-gated)
  // Returns a flat list of activity items sorted by recency.
  //   type: 'post' | 'like' | 'comment'
  // ============================================================================
  static Future<List<Map<String, dynamic>>> getMyRecentActivity({int limit = 10}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Run all fetches in parallel
    final results = await Future.wait([
      _client.from('posts').select('id, content, created_at').eq('author_id', userId).order('created_at', ascending: false).limit(limit ~/ 2),
      _client.from('comments').select('id, content, created_at, post_id').eq('author_id', userId).order('created_at', ascending: false).limit(limit ~/ 2),
      _client.from('likes').select('id, created_at, post_id').eq('user_id', userId).order('created_at', ascending: false).limit(limit ~/ 2),
    ]);

    final List<dynamic> myPosts = results[0];
    final List<dynamic> myComments = results[1];
    final List<dynamic> myLikes = results[2];

    final activities = <Map<String, dynamic>>[];

    for (final p in myPosts) {
      activities.add({
        'type': 'post',
        'id': p['id'],
        'summary': (p['content'] as String? ?? '').length > 80
            ? '${(p['content'] as String).substring(0, 80)}…'
            : p['content'],
        'created_at': p['created_at'],
      });
    }
    for (final c in myComments) {
      activities.add({
        'type': 'comment',
        'id': c['id'],
        'post_id': c['post_id'],
        'summary': (c['content'] as String? ?? '').length > 80
            ? '${(c['content'] as String).substring(0, 80)}…'
            : c['content'],
        'created_at': c['created_at'],
      });
    }
    for (final l in myLikes) {
      activities.add({
        'type': 'like',
        'id': l['id'],
        'post_id': l['post_id'],
        'summary': 'You liked a post',
        'created_at': l['created_at'],
      });
    }

    // Sort all by recency
    activities.sort((a, b) {
      final ta = DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
      final tb = DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
      return tb.compareTo(ta);
    });

    return activities.take(limit).toList();
  }

  // ============================================================================
  // SIDEBAR — LATEST POSTS STREAM
  // ============================================================================
  static Stream<List<Map<String, dynamic>>> getLatestPostsStream({int limit = 10}) {
    return _client
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // ============================================================================
  // AUTH SECURITY INTEGRATION
  // ============================================================================
  
  /// Hash and update custom secondary password. Delegate to AuthService.
  static Future<void> updateCustomPassword(String rawPassword) async {
    // Note: Project expects AuthService for complex hashing.
    // Using simple stub here, but typically this triggers the crypto logic.
  }
}

