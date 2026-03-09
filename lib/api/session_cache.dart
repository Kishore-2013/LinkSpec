import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SessionCache — Fetch-Once, Cache-Always
/// ─────────────────────────────────────────────────────────────────────────────
///
/// A pure in-memory singleton that survives tab switches and widget rebuilds
/// for the lifetime of the current browser session / app process.
///
/// - No disk writes. No SharedPreferences. Nothing persists across page reloads
///   or app restarts.
/// - Thread-safe: concurrent callers for the same key coalesce on the same
///   in-flight Future instead of launching duplicate network requests.
/// - Clear on close: call [SessionCache.clearAll] from an AppLifecycleListener
///   or a JS `beforeunload` handler.
///
/// Usage:
/// ```dart
/// final posts = await SessionCache.getOrFetch(
///   key: 'feed:popularity:MedTech:p0',
///   fetch: () => PostService.getPostsByMode(...),
/// );
/// ```
class SessionCache {
  SessionCache._();

  // ── Storage ──────────────────────────────────────────────────────────────
  static final Map<String, dynamic> _store = {};

  // ── In-flight deduplication ───────────────────────────────────────────────
  // If two callers request the same key simultaneously, the second one awaits
  // the first's Future rather than launching a second network call.
  static final Map<String, Future<dynamic>> _inflight = {};

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns the cached value for [key], or calls [fetch] exactly once and
  /// caches the result. Concurrent calls with the same key share one Future.
  static Future<T> getOrFetch<T>({
    required String key,
    required Future<T> Function() fetch,
  }) async {
    // Fast path: already in cache
    if (_store.containsKey(key)) {
      return _store[key] as T;
    }

    // Dedup: if a fetch is already in-flight for this key, await it
    if (_inflight.containsKey(key)) {
      return (await _inflight[key]) as T;
    }

    // Slow path: launch fetch, register in-flight, then store result
    final future = fetch().then((result) {
      _store[key] = result;
      _inflight.remove(key);
      return result;
    }).catchError((e) {
      _inflight.remove(key); // allow retry on error — don't cache failures
      throw e;
    });

    _inflight[key] = future;
    return await future;
  }

  /// Removes a specific key (e.g., after a mutation like a new post).
  static void invalidate(String key) {
    _store.remove(key);
    _inflight.remove(key);
  }

  /// Removes all keys that start with [prefix].
  /// e.g., invalidatePrefix('feed:') clears all feed pages at once.
  static void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Puts a value directly into the cache (for optimistic updates).
  static void put<T>(String key, T value) {
    _store[key] = value;
    _inflight.remove(key);
  }

  /// Clears the entire session cache.
  /// Call this on browser tab close or app detach to ensure the next session
  /// starts clean.
  static void clearAll() {
    _store.clear();
    _inflight.clear();
    if (kDebugMode) debugPrint('SessionCache: cleared.');
  }

  /// Returns true if the key has a cached value (useful for preload checks).
  static bool has(String key) => _store.containsKey(key);

  /// Number of entries currently cached (for diagnostics).
  static int get size => _store.length;
}
