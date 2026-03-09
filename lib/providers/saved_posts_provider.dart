import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/saved_posts_service.dart';
import '../api/web_cache_manager.dart';

/// Provider to track saved post IDs throughout the session, 
/// synced with the backend database for permanence and locally cached for speed.
class SavedPostsNotifier extends StateNotifier<Set<String>> {
  SavedPostsNotifier() : super({});

  bool _initStarted = false; // guard against double-init

  /// Initialize: 
  /// 1. Load from local cache (instant response on Web refresh).
  /// 2. Load from Supabase (server-side source of truth).
  /// Safe to call multiple times — only executes once.
  Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;

    // Stage 1: Fast local recovery
    final cachedIds = await WebCacheManager.getSavedIds();
    if (cachedIds.isNotEmpty && state.isEmpty) {
      state = cachedIds;
    }

    // Stage 2: Database sync
    try {
      final dbIds = await SavedPostsService.fetchAllSavedIds();
      state = dbIds;
      // Sync cache to match DB
      await WebCacheManager.saveSavedIds(dbIds);
    } catch (_) {}
  }

  /// Toggle saving a post: updates local state, cache, and remote database.
  Future<void> toggle(String postId) async {
    // 1. Optimistic Update (Immediate UI response)
    final isCurrentlySaved = state.contains(postId);
    if (isCurrentlySaved) {
      state = {...state}..remove(postId);
    } else {
      state = {...state, postId};
    }
    
    // Save current state to local cache immediately
    await WebCacheManager.saveSavedIds(state);

    try {
      // 2. Sync to Database
      final syncedStatus = await SavedPostsService.toggleSavePost(postId);
      
      // 3. Final Reconciliation (only if the server side disagreed)
      if (syncedStatus != !isCurrentlySaved) {
        if (syncedStatus) {
          state = {...state, postId};
        } else {
          state = {...state}..remove(postId);
        }
        await WebCacheManager.saveSavedIds(state);
      }
    } catch (e) {
      // Revert if database sync fails completely
      if (isCurrentlySaved) {
        state = {...state, postId};
      } else {
        state = {...state}..remove(postId);
      }
      await WebCacheManager.saveSavedIds(state);
    }
  }

  bool isSaved(String postId) => state.contains(postId);

  void clear() => state = {};
}

final savedPostsProvider = StateNotifierProvider<SavedPostsNotifier, Set<String>>((ref) {
  final notifier = SavedPostsNotifier();
  // Kick off init lazily once, without needing any consumer to remember to call it.
  notifier.init();
  return notifier;
});
