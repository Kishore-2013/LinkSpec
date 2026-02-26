import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Diagnostic: Force filesystem update. Corrected unread counts.
/// Supabase Service for LinkSpec
/// Handles all database operations with domain-gated logic
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  
  // Cache for current user data to avoid redundant network calls
  static Map<String, dynamic>? _currentUserProfile;
  static String? _myDomain;

  static String? getCurrentUserId() => _client.auth.currentUser?.id;

  /// Send a password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    // Simplify redirectTo to the root origin on Web. 
    // The SplashScreen master-interceptor will catch the code and move the user to Reset.
    final String? redirectTo = kIsWeb ? Uri.base.origin : null;
        
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
    String? industry,
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
    if (industry != null) updates['industry'] = industry;

    if (updates.isNotEmpty) {
      await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      
      // Update local cache if avatar or fullName changed
      if (_currentUserProfile != null) {
        if (fullName != null) _currentUserProfile!['full_name'] = fullName;
        if (avatarUrl != null) _currentUserProfile!['avatar_url'] = avatarUrl;
        if (bio != null) _currentUserProfile!['bio'] = bio;
      }
    }
  }

  /// Switch the current user's domain
  static Future<void> switchDomain(String newDomain) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('profiles')
        .update({'domain_id': newDomain})
        .eq('id', userId);
    
    // Clear local cache to force refresh with new domain content
    _myDomain = newDomain;
    if (_currentUserProfile != null) {
      _currentUserProfile!['domain_id'] = newDomain;
    }
  }

  /// Upload avatar image and return public URL
  static Future<String> uploadAvatar(Uint8List bytes, String fileName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final path = 'avatars/$userId/$fileName';
    await _client.storage.from('profiles').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    final url = _client.storage.from('profiles').getPublicUrl(path);
    // Save to profile
    await _client.from('profiles').update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  /// Upload cover photo and return public URL
  static Future<String> uploadCoverPhoto(Uint8List bytes, String fileName) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');
    final path = 'covers/$userId/$fileName';
    await _client.storage.from('profiles').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    final url = _client.storage.from('profiles').getPublicUrl(path);
    // Save to profile
    await _client.from('profiles').update({'cover_url': url}).eq('id', userId);
    return url;
  }

  /// Get current user's profile with in-memory caching
  static Future<Map<String, dynamic>?> getCurrentUserProfile({bool forceRefresh = false}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    // Return cached profile if available and not forcing refresh
    if (_currentUserProfile != null && !forceRefresh) {
      return _currentUserProfile;
    }

    final profile = await getUserProfile(userId);
    if (profile != null) {
      _currentUserProfile = profile;
      _myDomain = profile['domain_id'] as String?;
    }
    return profile;
  }

  /// Get a specific user's profile by ID
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    return response;
  }

  /// Get total post count for a user
  static Future<int> getUserPostCount(String userId) async {
    final response = await _client
        .from('posts')
        .select('id')
        .eq('author_id', userId);
    
    return (response as List).length;
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
    
    if (_myDomain == null) return [];

    var query = _client
        .from('profiles')
        .select()
        .eq('domain_id', _myDomain!);
        
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.ilike('full_name', '%$searchQuery%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Check if user has completed domain selection
  static Future<bool> hasCompletedDomainSelection() async {
    final profile = await getCurrentUserProfile();
    return profile != null && profile['domain_id'] != null;
  }

  /// Global search for posts across all domains
  static Future<List<Map<String, dynamic>>> searchPosts(String query) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

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
        .ilike('content', '%$query%')
        .order('created_at', ascending: false)
        .limit(20);

    final posts = List<Map<String, dynamic>>.from(response);
    
    // Process results similarly to getPosts to include counts and basic author info
    return posts.map((post) {
      final profile = post['profiles'];
      final likes = post['likes'] as List?;
      final likeCount = likes != null && likes.isNotEmpty ? (likes[0]['count'] ?? 0) : 0;
      final comments = post['comments'] as List?;
      final commentCount = comments != null && comments.isNotEmpty ? (comments[0]['count'] ?? 0) : 0;

      return {
        ...post,
        'author_name': profile?['full_name'],
        'author_avatar': profile?['avatar_url'],
        'author_domain': profile?['domain_id'],
        'like_count': likeCount,
        'comment_count': commentCount,
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

  // ============================================================================
  // POST OPERATIONS
  // ============================================================================

  /// Upload an image to post-images bucket
  static Future<String> uploadPostImage({
    required String name,
    required dynamic file, // Can be File (mobile) or Uint8List (web)
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$name';
    
    await _client.storage.from('post-images').uploadBinary(path, file);
    
    return _client.storage.from('post-images').getPublicUrl(path);
  }

  /// Create a new post
  /// [targetDomainId] — if provided, the post appears in THAT domain's feed
  /// instead of the author's own domain (useful for cross-domain job posts, etc.).
  static Future<Map<String, dynamic>> createPost({
    required String content,
    String? imageUrl,
    String? targetDomainId, // Optional: override target domain
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

    final response = await _client
        .from('posts')
        .insert({
          'author_id': userId,
          'content': content,
          'image_url': imageUrl,
          if (domainId != null) 'domain_id': domainId,
        })
        .select()
        .single();

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

    final posts = List<Map<String, dynamic>>.from(response as List);

    if (posts.isEmpty) return [];

    // Batch-fetch isFollowing / isLiked for the current user
    final authorIds = posts.map((p) => p['author_id'] as String).toSet().toList();
    final followingSet = await getFollowStatuses(authorIds);

    final postIds = posts.map((p) => p['id'] as String).toList();
    final likedSet = await getLikeStatuses(postIds);

    return posts.map((post) {
      final postId   = post['id']        as String;
      final authorId = post['author_id'] as String;
      return {
        ...post,
        // RPC already returns flat author_name / author_avatar / author_domain
        'like_count':    (post['like_count']    as num?)?.toInt() ?? 0,
        'comment_count': (post['comment_count'] as num?)?.toInt() ?? 0,
        'is_liked':      likedSet.contains(postId),
        'is_following':  followingSet.contains(authorId),
      };
    }).toList();
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

    final posts = List<Map<String, dynamic>>.from(response);
    
    // Batch fetch follow/like statuses
    final authorIds = posts.map((p) => p['author_id'] as String).toSet().toList();
    final followingSet = await getFollowStatuses(authorIds);
    final postIds = posts.map((p) => p['id'] as String).toList();
    final likedSet = await getLikeStatuses(postIds);

    return posts.map((post) {
      final profile = post['profiles'];
      final postId = post['id'] as String;
      final authorId = post['author_id'] as String;

      final likes = post['likes'] as List?;
      final likeCount = likes != null && likes.isNotEmpty ? (likes[0]['count'] ?? 0) : 0;

      final comments = post['comments'] as List?;
      final commentCount = comments != null && comments.isNotEmpty ? (comments[0]['count'] ?? 0) : 0;

      return {
        ...post,
        'author_name': profile?['full_name'],
        'author_avatar': profile?['avatar_url'],
        'author_domain': profile?['domain_id'],
        'like_count': likeCount,
        'comment_count': commentCount,
        'is_liked': likedSet.contains(postId),
        'is_following': followingSet.contains(authorId),
        'views_count': post['views_count'] ?? 0,
        'shares_count': post['shares_count'] ?? 0,
      };
    }).toList();
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
        .inFilter('id', postIds);

    final posts = List<Map<String, dynamic>>.from(response);
    
    // Batch fetch follow statuses
    final authorIds = posts.map((p) => p['author_id'] as String).toSet().toList();
    final followingSet = await getFollowStatuses(authorIds);

    // Batch fetch like statuses
    final likedSet = await getLikeStatuses(postIds);

    return posts.map((post) {
      final profile = post['profiles'];
      final postId = post['id'] as String;
      final authorId = post['author_id'] as String;

      final likes = post['likes'] as List?;
      final likeCount = likes != null && likes.isNotEmpty ? (likes[0]['count'] ?? 0) : 0;

      final comments = post['comments'] as List?;
      final commentCount = comments != null && comments.isNotEmpty ? (comments[0]['count'] ?? 0) : 0;

      return {
        ...post,
        'author_name': profile?['full_name'],
        'author_avatar': profile?['avatar_url'],
        'author_domain': profile?['domain_id'],
        'like_count': likeCount,
        'comment_count': commentCount,
        'is_liked': likedSet.contains(postId),
        'is_following': followingSet.contains(authorId),
      };
    }).toList();
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

  /// Send a message (optionally sharing a post)
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

  /// Get messages between current user and another user
  static Future<List<Map<String, dynamic>>> getMessages(String otherUserId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _client
        .from('messages')
        .select('''
          *,
          posts:post_id (*)
        ''')
        .or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)')
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Get count of unread messages for current user
  static Future<int> getUnreadMessageCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final response = await _client
          .from('messages')
          .select('id')
          .eq('receiver_id', userId)
          .eq('is_read', false);
      return (response as List).length;
    } catch (_) {
      // Fallback: if is_read column doesn't exist, return 0
      return 0;
    }
  }

  /// Mark all messages from a specific user as read
  static Future<void> markMessagesAsRead(String otherUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('receiver_id', userId)
          .eq('sender_id', otherUserId)
          .eq('is_read', false);
    } catch (_) {}
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
        .subscribe();
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
  // CONNECT OPERATIONS (mutual connection requests)
  // ============================================================================

  /// Send a connection request to another user
  /// Status flow: pending → accepted
  static Future<void> sendConnectRequest(String targetUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('connection_requests').insert({
      'sender_id': userId,
      'receiver_id': targetUserId,
      'status': 'pending',
    });
  }

  /// Withdraw a pending connection request
  static Future<void> withdrawConnectRequest(String targetUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('connection_requests')
        .delete()
        .eq('sender_id', userId)
        .eq('receiver_id', targetUserId);
  }

  /// Accept a connection request from another user
  static Future<void> acceptConnectRequest(String senderUserId) async {
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

  /// Get connection (mutual) count for a user
  static Future<int> getConnectCount(String userId) async {
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
        .subscribe();
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
        .subscribe();
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
    if (_myDomain != null) {
      query = query.eq('domain_id', _myDomain!);
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
    
    if (_myDomain != null) {
      return List<Map<String, dynamic>>.from(
        await query.eq('domain_id', _myDomain!).order('created_at', ascending: false)
      );
    }
    
    return List<Map<String, dynamic>>.from(await query.order('created_at', ascending: false));
  }

  /// Get events for the user's domain
  static Future<List<Map<String, dynamic>>> getEvents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    if (_myDomain == null) {
      await getCurrentUserProfile();
    }

    final query = _client.from('events').select();
    
    if (_myDomain != null) {
      return List<Map<String, dynamic>>.from(
        await query.eq('domain_id', _myDomain!).order('date', ascending: true)
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

  /// Get count of unread notifications for current user
  static Future<int> getUnreadNotificationCount() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('SERVICE: No user session for count.');
      return 0;
    }
    
    try {
      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .neq('is_read', true);
      
      final data = response as List;
      debugPrint('DEBUG: getUnreadNotificationCount - Auth ID: $userId | Found: ${data.length}');
      if (data.isNotEmpty) {
        debugPrint('DEBUG: First unread ID: ${data[0]['id']} | User ID in DB: ${data[0]['user_id']}');
      }
      return data.length;
    } catch (e) {
      debugPrint('Error getting notification count: $e');
      return 0;
    }
  }

  // ============================================================================
  // NOTIFICATION OPERATIONS
  // ============================================================================

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

  /// Mark all notifications for the current user as read
  static Future<void> markAllNotificationsAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('ERROR: markAllNotificationsAsRead - No user logged in');
      return;
    }
    
    try {
      // 1. Get IDs of all unread notifications first
      final unreadResponse = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .neq('is_read', true);
      
      final unreadList = unreadResponse as List;
      if (unreadList.isEmpty) {
        debugPrint('SERVICE: No unread notifications found to clear.');
        return;
      }
      
      final ids = unreadList.map((n) => n['id'] as String).toList();
      debugPrint('SERVICE: Attempting to clear IDs: $ids');

      // 2. Update them specifically by ID (sometimes more reliable with RLS)
      await _client
          .from('notifications')
          .update({'is_read': true})
          .filter('id', 'in', ids);
          
      debugPrint('DATABASE: Successfully sent update for notifications read status.');
    } catch (e) {
      debugPrint('CRITICAL ERROR in markAllNotificationsAsRead: $e');
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
}
