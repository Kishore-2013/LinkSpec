import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// A provider that tracks follow status by User ID.
/// This ensures that if you follow a user in one place (e.g. one PostCard),
/// all other UI elements for that same user update dynamically.
final followProvider = StateNotifierProvider<FollowNotifier, Map<String, bool>>((ref) {
  return FollowNotifier();
});

class FollowNotifier extends StateNotifier<Map<String, bool>> {
  FollowNotifier() : super({});

  void setFollowStatus(String userId, bool isFollowing) {
    state = {...state, userId: isFollowing};
  }

  Future<void> toggleFollow(String userId) async {
    final currentlyFollowing = state[userId] ?? false;
    final newStatus = !currentlyFollowing;
    
    // Optimistic update
    setFollowStatus(userId, newStatus);

    try {
      if (newStatus) {
        await SupabaseService.followUser(userId);
      } else {
        await SupabaseService.unfollowUser(userId);
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505' && newStatus) {
        // 23505 is duplicate key, which means the connection already exists.
        // We can safely ignore this and keep the state as following.
        return;
      }
      setFollowStatus(userId, currentlyFollowing);
      rethrow;
    } catch (e) {
      // Revert on error
      setFollowStatus(userId, currentlyFollowing);
      rethrow;
    }
  }
}
