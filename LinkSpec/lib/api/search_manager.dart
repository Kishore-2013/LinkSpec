import '../models/post.dart';
import '../services/supabase_service.dart';

/// Manages hashtag-aware search with an in-memory result cache.
/// Cache key = the normalised query string (always lower-case, leading '#' stripped).
class SearchManager {
  SearchManager._();

  // ── In-memory cache ───────────────────────────────────────────
  static final Map<String, List<Post>> _postCache = {};
  static final Map<String, List<Map<String, dynamic>>> _peopleCache = {};

  /// Minimum meaningful query length (reject '.', ',', single chars).
  static bool isValidQuery(String raw) {
    final q = raw.trim();
    if (q.length < 2) return false;
    // Must contain at least one letter or digit
    return q.contains(RegExp(r'[a-zA-Z0-9]'));
  }

  /// Normalise: strip leading '#', lower-case, trim.
  static String normalise(String raw) =>
      raw.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();

  // ── Post search ──────────────────────────────────────────────

  /// Returns cached posts if available, otherwise fetches from Supabase.
  static Future<List<Post>> searchPosts(String rawQuery) async {
    final key = normalise(rawQuery);
    if (_postCache.containsKey(key)) return _postCache[key]!;

    final results = await SupabaseService.searchPostsByHashtag(rawQuery);
    final posts = results.map((p) => Post.fromJson(p)).toList();
    _postCache[key] = posts;
    return posts;
  }

  // ── People search ─────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> searchPeople(String rawQuery) async {
    final key = 'people:${normalise(rawQuery)}';
    if (_peopleCache.containsKey(key)) return _peopleCache[key]!;

    final results = await SupabaseService.searchProfiles(rawQuery);
    _peopleCache[key] = results;
    return results;
  }

  // ── Trending tags ─────────────────────────────────────────────

  /// Extracts trending hashtags from a list of posts (no network call needed).
  static List<String> extractTrendingTags(List<Post> posts, {int topN = 10}) {
    final freq = <String, int>{};
    final tagPattern = RegExp(r'#([A-Za-z][A-Za-z0-9_]*)');
    for (final post in posts) {
      for (final match in tagPattern.allMatches(post.content)) {
        final tag = '#${match.group(1)!}';
        freq[tag] = (freq[tag] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(topN).map((e) => e.key).toList();
  }

  // ── Cache management ─────────────────────────────────────────

  static void invalidate(String rawQuery) {
    final key = normalise(rawQuery);
    _postCache.remove(key);
    _peopleCache.remove('people:$key');
  }

  static void clearAll() {
    _postCache.clear();
    _peopleCache.clear();
  }
}
