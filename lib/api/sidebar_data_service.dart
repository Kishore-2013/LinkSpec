import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'session_cache.dart';

/// Cached, Realtime-aware data provider for the home screen sidebars.
///
/// - Trending tags    : scanned from last 100 posts, top 5 by frequency.
/// - Suggested discussions: top 3 posts by comment count in the user's domain.
/// - Primary cache: [SessionCache] — lives for the full browser session.
/// - Secondary TTL:  10 minutes (busted on Realtime events or domain change).
class SidebarDataService {
  SidebarDataService({required this.domain});

  final String domain;

  // ── Session-cache keys ──────────────────────────────────────────────────
  String get _tagsKey        => 'sidebar:tags:$domain';
  String get _discussionsKey => 'sidebar:discussions:$domain';

  // ── Local TTL guard (secondary, in case session data is old) ───────────
  DateTime? _tagsLoadedAt;
  DateTime? _discussionsLoadedAt;
  static const _ttl = Duration(minutes: 10);

  // ── State ───────────────────────────────────────────────────────────────
  bool isLoadingTags        = false;
  bool isLoadingDiscussions = false;

  // In-widget copies — kept in sync with SessionCache for synchronous reads
  List<String>               _localTags        = [];
  List<Map<String, dynamic>> _localDiscussions = [];

  List<String>               get trendingTags         => List.unmodifiable(_localTags);
  List<Map<String, dynamic>> get suggestedDiscussions => List.unmodifiable(_localDiscussions);

  // ── Realtime ────────────────────────────────────────────────────────────
  RealtimeChannel? _postsChannel;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Subscribe to Realtime post-insert events.
  /// On any new post/comment the cache is busted and [onUpdate] fires.
  void subscribeRealtime({required void Function() onUpdate}) {
    _postsChannel?.unsubscribe();
    _postsChannel = Supabase.instance.client
        .channel('sidebar:posts:$domain')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (_) {
            // Bust both caches so the next load fetches fresh data
            SessionCache.invalidate(_tagsKey);
            SessionCache.invalidate(_discussionsKey);
            _tagsLoadedAt = null;
            _discussionsLoadedAt = null;
            onUpdate();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          callback: (_) {
            SessionCache.invalidate(_discussionsKey);
            _discussionsLoadedAt = null;
            onUpdate();
          },
        )
        .subscribe((RealtimeSubscribeStatus status, Object? error) {
          if (error != null) {
            // Silently ignore WebSocket connection errors (Realtime is non-critical)
            // The sidebar will still show data from the initial REST load
          }
        });
  }

  void dispose() {
    _postsChannel?.unsubscribe();
    _postsChannel = null;
  }

  // ── Trending Tags ────────────────────────────────────────────────────────

  Future<void> loadTrendingTags({void Function()? onUpdate}) async {
    // Serve from SessionCache when fresh
    if (SessionCache.has(_tagsKey) &&
        _tagsLoadedAt != null &&
        DateTime.now().difference(_tagsLoadedAt!) < _ttl) {
      // Sync local copy from cache (in case this is a new SidebarDataService instance)
      final cached = await SessionCache.getOrFetch<List<String>>(
        key: _tagsKey, fetch: () async => _localTags,
      );
      _localTags = cached;
      return;
    }

    if (isLoadingTags) return;
    isLoadingTags = true;
    onUpdate?.call();
    try {
      final tags = await SupabaseService.getTrendingTags(domain: domain, limit: 5);
      _localTags    = tags;
      _tagsLoadedAt = DateTime.now();
      SessionCache.put(_tagsKey, List<String>.from(tags));
    } catch (_) {
      _localTags = [];
    } finally {
      isLoadingTags = false;
      onUpdate?.call();
    }
  }

  // ── Suggested Discussions ────────────────────────────────────────────────

  Future<void> loadSuggestedDiscussions({void Function()? onUpdate}) async {
    // Serve from SessionCache when fresh
    if (SessionCache.has(_discussionsKey) &&
        _discussionsLoadedAt != null &&
        DateTime.now().difference(_discussionsLoadedAt!) < _ttl) {
      final cached = await SessionCache.getOrFetch<List<Map<String, dynamic>>>(
        key: _discussionsKey, fetch: () async => _localDiscussions,
      );
      _localDiscussions = cached;
      return;
    }

    if (isLoadingDiscussions) return;
    isLoadingDiscussions = true;
    onUpdate?.call();
    try {
      final discussions =
          await SupabaseService.getSuggestedDiscussions(domain: domain, limit: 3);
      _localDiscussions    = discussions;
      _discussionsLoadedAt = DateTime.now();
      SessionCache.put(_discussionsKey, List<Map<String, dynamic>>.from(discussions));
    } catch (_) {
      _localDiscussions = [];
    } finally {
      isLoadingDiscussions = false;
      onUpdate?.call();
    }
  }

  /// Bust both caches (call when domain changes).
  void invalidate() {
    SessionCache.invalidate(_tagsKey);
    SessionCache.invalidate(_discussionsKey);
    _tagsLoadedAt        = null;
    _discussionsLoadedAt = null;
    _localTags           = [];
    _localDiscussions    = [];
  }
}
