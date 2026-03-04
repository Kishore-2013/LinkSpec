import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import 'post_service.dart';
import 'session_cache.dart';

/// Bidirectional virtual window over the post feed.
///
/// At most [maxWindowSize] posts are kept in the active [posts] list.
/// All other pages are held in an in-memory [_pageCache], keyed by page index.
/// The cache auto-evicts the farthest pages when it exceeds [maxCachedPosts].
///
///  ┌──────────────────────────────────────────────────────────┐
///  │ CACHE page 0 │ WINDOW [page 1 · page 2] │ CACHE page 3  │
///  └──────────────────────────────────────────────────────────┘
///
/// Scroll DOWN → [loadOlder] appends page, evicts top of window to cache.
/// Scroll UP   → [loadNewer] prepends cached page, evicts bottom of window.
/// Pull-to-refresh → [refresh] clears everything and reloads from page 0.
class PostWindowManager {
  PostWindowManager({
    required this.domain,
    this.mode           = FeedMode.popularity,
    this.pageSize     = 10,
    this.maxWindowSize  = 15,  
    this.maxCachedPosts = 200, 
  });

  final String domain;
  final FeedMode mode;
  final int pageSize;
  final int maxWindowSize;
  final int maxCachedPosts;

  // Metadata for the UI (e.g., current empty state message)
  String get emptyStateMessage => switch(mode) {
    FeedMode.chronological => "No new posts yet. Be the first to share something!",
    FeedMode.topWeekly     => "No trending posts found in the last 7 days.",
    _                      => "Nothing to show here.",
  };

  bool get isChronological => mode == FeedMode.chronological;

  // ── Active window ─────────────────────────────────────────────
  final List<Post> _window = [];
  List<Post> get posts => List.unmodifiable(_window);

  int _firstPage = 0;  // page-index of first post currently in window
  int _lastPage  = -1; // page-index of last  post currently in window

  // ── Page cache (off-window storage) ──────────────────────────
  final Map<int, List<Post>> _pageCache = {};

  // ── State flags ───────────────────────────────────────────────
  bool isLoading      = false; // initial load
  bool isLoadingOlder = false; // appending newer-older posts (scroll ↓)
  bool isLoadingNewer = false; // prepending older-newer posts (scroll ↑)
  bool _hasMoreOlder  = true;

  bool get hasMoreOlder => _hasMoreOlder;
  /// True when the user has scrolled down enough that there are evicted pages
  /// above the current window that can be pulled back.
  bool get hasMoreNewer => _firstPage > 0;

  // ── Public API ────────────────────────────────────────────────

  /// Load page 0 and initialise the window.
  Future<void> loadInitial({void Function()? onUpdate}) async {
    if (isLoading) return;
    isLoading = true;
    onUpdate?.call();
    try {
      final page = await _fetchPage(0);
      _window
        ..clear()
        ..addAll(page);
      _pageCache.clear();
      _firstPage     = 0;
      _lastPage      = 0;
      _hasMoreOlder  = page.length >= pageSize;
    } finally {
      isLoading = false;
      onUpdate?.call();
    }
  }

  /// Append the next page (user scrolled to the bottom).
  ///
  /// Returns [evictedFromTop] — the number of items removed from the top
  /// of the window. The caller should use this to keep the scroll position
  /// stable (jumpTo current − evictedHeight).
  Future<int> loadOlder({void Function()? onUpdate}) async {
    if (!_hasMoreOlder || isLoadingOlder || isLoading) return 0;
    isLoadingOlder = true;
    onUpdate?.call();
    int evictedFromTop = 0;
    try {
      final nextPage = _lastPage + 1;
      final page     = _pageCache[nextPage] ?? await _fetchPage(nextPage);
      _pageCache[nextPage] = page;

      _window.addAll(page);
      _lastPage     = nextPage;
      _hasMoreOlder = page.length >= pageSize;

      // Keep window bounded – evict the top page
      if (_window.length > maxWindowSize) {
        evictedFromTop = _evictTop();
      }
      _trimCache();
    } finally {
      isLoadingOlder = false;
      onUpdate?.call();
    }
    return evictedFromTop;
  }

  /// Prepend the previous page (user scrolled back to the top).
  ///
  /// Returns [prepended] — the number of items added at the top.
  /// The caller should jump the scroll offset forward by (prepended × avgHeight)
  /// to prevent visual jumping.
  Future<int> loadNewer({void Function()? onUpdate}) async {
    if (_firstPage <= 0 || isLoadingNewer || isLoading) return 0;
    isLoadingNewer = true;
    onUpdate?.call();
    int prepended = 0;
    try {
      final prevPage = _firstPage - 1;
      final page     = _pageCache[prevPage] ?? await _fetchPage(prevPage);
      _pageCache[prevPage] = page;

      _window.insertAll(0, page);
      _firstPage = prevPage;
      prepended  = page.length;

      // Keep window bounded – evict the bottom page
      if (_window.length > maxWindowSize) {
        _evictBottom();
        _hasMoreOlder = true; // we know more exists below
      }
      _trimCache();
    } finally {
      isLoadingNewer = false;
      onUpdate?.call();
    }
    return prepended;
  }

  /// Full refresh: clear everything and reload from page 0.
  /// Also busts the SessionCache entry so fresh data is fetched from Supabase.
  Future<void> refresh({void Function()? onUpdate}) async {
    // Bust the session-level cache so the next loadInitial hits Supabase
    SessionCache.invalidate('feed:${mode.name}:${domain}:p0');
    _pageCache.clear();
    _window.clear();
    _firstPage    = 0;
    _lastPage     = -1;
    _hasMoreOlder = true;
    await loadInitial(onUpdate: onUpdate);
  }

  // ── Private helpers ───────────────────────────────────────────

  /// Move the top [pageSize] posts out of the window into the cache.
  int _evictTop() {
    final evicted = _window.sublist(0, pageSize);
    _pageCache[_firstPage] = evicted;
    _window.removeRange(0, pageSize);
    _firstPage++;
    return evicted.length;
  }

  /// Move the bottom [pageSize] posts out of the window into the cache.
  void _evictBottom() {
    final start   = _window.length - pageSize;
    final evicted = _window.sublist(start);
    _pageCache[_lastPage] = evicted;
    _window.removeRange(start, _window.length);
    _lastPage--;
  }

  /// Auto-evict cached pages that are farthest from the current window
  /// when the cache grows beyond [maxCachedPosts].
  void _trimCache() {
    var total = _pageCache.values.fold(0, (s, l) => s + l.length);
    if (total <= maxCachedPosts) return;

    final mid = (_firstPage + _lastPage) / 2.0;
    final byDistance = _pageCache.keys.toList()
      ..sort((a, b) => (b - mid).abs().compareTo((a - mid).abs()));

    for (final key in byDistance) {
      if (total <= maxCachedPosts) break;
      total -= _pageCache[key]?.length ?? 0;
      _pageCache.remove(key);
    }
  }

  Future<List<Post>> _fetchPage(int page) async {
    final raw = await PostService.getPostsByMode(
      mode:   mode,
      limit:  pageSize,
      offset: page * pageSize,
      domain: domain,
    );
    return raw.map((d) => Post.fromJson(d)).toList();
  }
}
