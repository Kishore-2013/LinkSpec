import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Service for LinkSpec
/// Handles all database operations with domain-gated logic
class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static String? getCurrentUserId() => _client.auth.currentUser?.id;

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

  /// Get current user's profile
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      return null;
    }

    return await getUserProfile(userId);
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

  /// Check if user has completed domain selection
  static Future<bool> hasCompletedDomainSelection() async {
    final profile = await getCurrentUserProfile();
    return profile != null && profile['domain_id'] != null;
  }

  /// Get profiles in the same domain (for connections/search)
  static Future<List<Map<String, dynamic>>> getProfilesInSameDomain({
    int limit = 20,
    int offset = 0,
    String? searchQuery,
  }) async {
    var response = await _client
        .from('profiles')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    var profiles = List<Map<String, dynamic>>.from(response);
    
    // Filter by search query client-side if provided
    if (searchQuery != null && searchQuery.isNotEmpty) {
      profiles = profiles.where((profile) {
        final fullName = (profile['full_name'] as String?)?.toLowerCase() ?? '';
        return fullName.contains(searchQuery.toLowerCase());
      }).toList();
    }

    return profiles;
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
  /// Domain ID is automatically set by database trigger
  static Future<Map<String, dynamic>> createPost({
    required String content,
    String? imageUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _client
        .from('posts')
        .insert({
          'author_id': userId,
          'content': content,
          'image_url': imageUrl,
        })
        .select()
        .single();

    return response;
  }

  /// Get posts in the same domain (feed)
  /// RLS policies automatically filter by domain
  static Future<List<Map<String, dynamic>>> getPosts({
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
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    // Transform the response to flatten the profile data
    final posts = List<Map<String, dynamic>>.from(response);
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

  /// Get posts by a specific user
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
          likes:likes(count)
        ''')
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final posts = List<Map<String, dynamic>>.from(response);
    return posts.map((post) {
      final profile = post['profiles'];
      final likes = post['likes'] as List?;
      final count = likes != null && likes.isNotEmpty ? (likes[0]['count'] ?? 0) : 0;
      
      return {
        ...post,
        'author_name': profile?['full_name'],
        'author_avatar': profile?['avatar_url'],
        'author_domain': profile?['domain_id'],
        'like_count': count,
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
          sender:sender_id (id, full_name, avatar_url, domain_id),
          receiver:receiver_id (id, full_name, avatar_url, domain_id)
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
  // CONNECTION OPERATIONS
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
    
    if (userId == null) {
      return false;
    }

    final response = await _client
        .from('connections')
        .select()
        .eq('follower_id', userId)
        .eq('following_id', followingId)
        .maybeSingle();

    return response != null;
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

  /// Get jobs for the user's domain
  static Future<List<Map<String, dynamic>>> getJobs() async {
    final response = await _client
        .from('jobs')
        .select('*, saved_jobs(id)')
        .order('posted_at', ascending: false);
    
    final data = List<Map<String, dynamic>>.from(response);
    return data.map((job) {
      final saved = job['saved_jobs'] as List?;
      return {
        ...job,
        'is_saved': saved != null && saved.isNotEmpty,
      };
    }).toList();
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

  /// Create a new comment
  static Future<void> createComment({
    required String postId,
    required String content,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('comments').insert({
      'post_id': postId,
      'author_id': userId,
      'content': content,
    });
  }

  /// Get comments for a specific post
  static Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final response = await _client
        .from('comments')
        .select('''
          *,
          profiles:author_id (
            full_name,
            avatar_url
          )
        ''')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    final comments = List<Map<String, dynamic>>.from(response);
    return comments.map((comment) {
      final profile = comment['profiles'];
      return {
        ...comment,
        'author_name': profile?['full_name'],
        'author_avatar': profile?['avatar_url'],
      };
    }).toList();
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

  /// Get notifications for the current user
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('notifications')
        .select('''
          *,
          actor:actor_id (
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

  /// Get real-time notifications stream
  static Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const Stream.empty();

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}
