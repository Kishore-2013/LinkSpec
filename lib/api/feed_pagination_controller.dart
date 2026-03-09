import '../models/post.dart';
import '../services/supabase_service.dart';

/// Clean pagination controller — separates all feed state from the UI.
///
/// Usage:
///   final ctrl = FeedPaginationController(domain: 'Medical');
///   await ctrl.loadFirstPage();
///   await ctrl.loadNextPage();   // appends; call from scroll listener
///   await ctrl.refresh();        // clears and reloads page 0
class FeedPaginationController {
  FeedPaginationController({
    required this.domain,
    this.pageSize = 10,
  });

  final String domain;
  final int pageSize;

  // ── State ────────────────────────────────────────────────────
  List<Post> posts = [];
  int  _currentPage  = 0;
  bool isLoading     = false;
  bool isLoadingMore = false;
  bool hasMore       = true;   // false once server returns < pageSize

  // ── In-memory page cache ─────────────────────────────────────
  // Maps: pageIndex → raw list, so we never re-fetch already-loaded pages.
  final Map<int, List<Post>> _pageCache = {};

  // ── Public API ────────────────────────────────────────────────

  /// Load page 0, clear accumulated list.
  Future<void> loadFirstPage({void Function()? onUpdate}) async {
    if (isLoading) return;
    isLoading = true;
    onUpdate?.call();
    try {
      final page = await _fetchPage(0);
      _pageCache.clear();
      _pageCache[0] = page;
      _currentPage = 0;
      posts = List.from(page);
      hasMore = page.length >= pageSize;
    } finally {
      isLoading = false;
      onUpdate?.call();
    }
  }

  /// Append the next page to [posts]. No-op if already at end.
  Future<void> loadNextPage({void Function()? onUpdate}) async {
    if (!hasMore || isLoadingMore || isLoading) return;
    isLoadingMore = true;
    onUpdate?.call();
    try {
      final nextPage = _currentPage + 1;
      // Use cache if already fetched
      final page = _pageCache[nextPage] ?? await _fetchPage(nextPage);
      _pageCache[nextPage] = page;
      _currentPage = nextPage;
      posts = [...posts, ...page];
      hasMore = page.length >= pageSize;
    } finally {
      isLoadingMore = false;
      onUpdate?.call();
    }
  }

  /// Full refresh: clears cache, resets to page 0.
  Future<void> refresh({void Function()? onUpdate}) async {
    _pageCache.clear();
    _currentPage = 0;
    hasMore = true;
    posts = [];
    await loadFirstPage(onUpdate: onUpdate);
  }

  // ── Private ───────────────────────────────────────────────────

  Future<List<Post>> _fetchPage(int page) async {
    final rawList = await SupabaseService.getPosts(
      limit:  pageSize,
      offset: page * pageSize,
      domain: domain,
    );
    return rawList.map((d) => Post.fromJson(d)).toList();
  }
}
