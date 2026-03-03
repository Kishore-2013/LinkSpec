import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track saved post IDs throughout the session.
class SavedPostsNotifier extends StateNotifier<Set<String>> {
  SavedPostsNotifier() : super({});

  void toggle(String postId) {
    if (state.contains(postId)) {
      state = {...state}..remove(postId);
    } else {
      state = {...state, postId};
    }
  }

  bool isSaved(String postId) => state.contains(postId);

  void clear() => state = {};
}

final savedPostsProvider = StateNotifierProvider<SavedPostsNotifier, Set<String>>((ref) {
  return SavedPostsNotifier();
});
