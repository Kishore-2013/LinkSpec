import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Service to handle persistent storage of saved posts.
class SavedPostsService {
  static final _client = Supabase.instance.client;

  /// Toggle saving a post for the current user.
  /// Returns true if saved, false if removed.
  static Future<bool> toggleSavePost(String postId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // 1. Check if already saved
    final existing = await _client
        .from('saved_posts')
        .select()
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();

    if (existing != null) {
      // 2. Remove if exists
      await _client
          .from('saved_posts')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
      return false;
    } else {
      // 3. Add if not exists
      await _client.from('saved_posts').insert({
        'user_id': userId,
        'post_id': postId,
      });
      return true;
    }
  }

  /// Fetch all saved post IDs for the current user.
  /// Used for synchronizing the local state/badges.
  static Future<Set<String>> fetchAllSavedIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    try {
      final response = await _client
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', userId);

      final list = response as List;
      final savedIds = list.map((row) => row['post_id'] as String).toSet();
      return savedIds;
    } catch (e) {
      print('SAVED_SERVICE ERROR (fetchAllSavedIds): $e');
      return {};
    }
  }

  /// Fetch paginated saved posts (full objects).
  static Future<List<Map<String, dynamic>>> fetchSavedPosts({int page = 0, int pageSize = 10}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // 1. Get the IDs for this page
      final savedResponse = await _client
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      final savedIds = (savedResponse as List).map((r) => r['post_id'] as String).toList();
      if (savedIds.isEmpty) return [];

      // Hydrate the post objects
      final hydrated = await SupabaseService.getPostsByIds(savedIds);

      // Sort hydrated posts to match savedIds (recency of save)
      final idMap = {for (var i = 0; i < savedIds.length; i++) savedIds[i]: i};
      hydrated.sort((a, b) {
        final idxA = idMap[a['id']] ?? 999;
        final idxB = idMap[b['id']] ?? 999;
        return idxA.compareTo(idxB);
      });

      return hydrated;
    } catch (e) {
      print('SAVED_SERVICE ERROR (fetchSavedPosts): $e');
      return [];
    }
  }
}
