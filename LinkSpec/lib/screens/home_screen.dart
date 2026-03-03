import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../models/group.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_dialog.dart';
import 'messages_list_screen.dart';
import 'network_screen.dart';
import 'member_profile_screen.dart';
import '../widgets/clay_container.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'jobs_screen.dart';
import 'post_create_screen.dart';
import 'search_screen.dart';
import 'group_detail_screen.dart';
import 'recent_activity_screen.dart';
import 'saved_items_screen.dart';
import 'settings_screen.dart';
import 'groups_screen.dart';
import 'events_screen.dart';
import '../widgets/aw_logo.dart';
import '../widgets/skeleton_loader.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';
import '../providers/saved_posts_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _isSearchMessageContext = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();
  // ── Pagination ─────────────────────────────────────────────────────────────
  static const int _pageSize = 10;   // posts shown per page
  int _currentPage = 0;              // current page index (0-based)
  bool _hasNextPage = false;         // true when there might be more posts
  // Only _pageSize posts are kept at a time (no accumulation)
  List<Post> _posts = [];
  UserProfile? _currentUserProfile;
  bool _isLoading = true;
  bool _isLoadingMore = false;       // true while fetching next/prev page

  // Sidebar groups — loaded dynamically
  List<Group> _sidebarGroups = [];

  // Badge counts — loaded dynamically from Supabase
  int _unreadMessages = 0;
  int _unreadNotifications = 0;
  Timer? _badgeTimer;

  // Domain options — must match the domain_id values stored in Supabase profiles
  static const _domains = [
    'Medical',
    'IT/Software',
    'Civil Engineering',
    'Law',
    'Business',
    'Global',
  ];
  String _selectedDomain = 'Medical';
  bool _isSwitchingDomain = false;

  // Track when we last cleared notifications / messages to prevent race conditions
  DateTime? _lastNotificationClear;
  DateTime? _lastMessageClear;

  // Scroll-aware bottom nav
  bool _navVisible = true;
  double _lastScrollOffset = 0;

  // Realtime channels — stored so they can be unsubscribed in dispose()
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _notificationsChannel;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadPosts();
    _loadGroups();
    _loadBadgeCounts();
    // Refresh badges every 30 seconds as a non-realtime fallback
    _badgeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadBadgeCounts();
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;

    // ── Messages Realtime (badge update only) ────────────────────────────────
    _messagesChannel = Supabase.instance.client
        .channel('home:messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => _loadBadgeCounts(),
        )
        .subscribe();

    // ── Notifications Realtime (badge + overlay SnackBar) ────────────────────
    if (userId != null) {
      _notificationsChannel = Supabase.instance.client
          .channel('home:notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,   // only fire on new rows
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) => _onNewNotification(payload),
          )
          .subscribe();
    }

    // Scroll-aware nav bar
    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      if (offset > _lastScrollOffset + 10 && _navVisible) {
        setState(() => _navVisible = false);
      } else if (offset < _lastScrollOffset - 10 && !_navVisible) {
        setState(() => _navVisible = true);
      }
      _lastScrollOffset = offset;
    });
  }

  /// Called by the Realtime channel whenever a new notification row is inserted.
  Future<void> _onNewNotification(PostgresChangePayload payload) async {
    // 1. Update the badge count immediately
    if (mounted) {
      setState(() => _unreadNotifications++);
    }

    // 2. Fetch actor name for the banner (the raw row has actor_id but no joined name)
    final newRow = payload.newRecord;
    final type    = newRow['type'] as String? ?? 'notification';
    final actorId = newRow['actor_id'] as String?;

    String actorName = 'Someone';
    if (actorId != null) {
      try {
        final profile = await SupabaseService.getUserProfile(actorId);
        actorName = profile?['full_name'] as String? ?? 'Someone';
      } catch (_) {}
    }

    final message = switch (type) {
      'like'         => '$actorName liked your post',
      'comment'      => '$actorName commented on your post',
      'like_comment' => '$actorName liked your comment',
      'connection'   => '$actorName united with you',
      _              => '$actorName sent you a notification',
    };

    // 3. Show the overlay banner (safe even if on a different tab)
    if (mounted) {
      _showNotificationBanner(message, type);
    }
  }

  /// Displays a rich SnackBar overlay visible from any tab.
  void _showNotificationBanner(String message, String type) {
    final iconData = switch (type) {
      'like'         => Icons.favorite_rounded,
      'comment'      => Icons.chat_bubble_rounded,
      'like_comment' => Icons.favorite_border_rounded,
      'connection'   => Icons.people_rounded,
      _              => Icons.notifications_rounded,
    };
    final iconColor = switch (type) {
      'like'         => Colors.red,
      'like_comment' => Colors.pink,
      'connection'   => Colors.blue,
      _              => const Color(0xFF0066CC),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2E)
            : Colors.white,
        elevation: 6,
        content: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1C1C1E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Tap to jump to notifications tab
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _navigateTo(5);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'View',
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Switch page and close the mobile drawer if it is open.
  void _navigateTo(int index) {
    // Close the drawer first (safe to call even if drawer is not open)
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
    setState(() {
      _currentIndex = index;
      if (index == 1) {
        _isSearchMessageContext = false;
      }
      if (index == 3) {
        _unreadMessages = 0; // Clear locally when entering messages tab
        _lastMessageClear = DateTime.now(); // Race condition guard
        SupabaseService.markAllMessagesAsRead(); // Mark them in the database too
      }
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _scrollController.dispose();
    // Unsubscribe Realtime channels to prevent memory leaks
    _messagesChannel?.unsubscribe();
    _notificationsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadBadgeCounts() async {
    try {
      final msgCount = await SupabaseService.getUnreadMessageCount();
      final notifCount = await SupabaseService.getUnreadNotificationCount();
      if (mounted) {
        setState(() {
          // Guard: If we cleared messages in the last 3 seconds,
          // suppress the old count to give the DB time to catch up.
          // Keep the window short (3s) so any new message that arrives
          // after that still updates the badge correctly.
          final isMessageRecentlyCleared = _lastMessageClear != null &&
              DateTime.now().difference(_lastMessageClear!).inSeconds < 3;

          // Force 0 if on messages tab OR if we cleared recently.
          if (_currentIndex != 3 && !isMessageRecentlyCleared) {
            _unreadMessages = msgCount;
          } else {
            _unreadMessages = 0;
          }
          
          // Guard: If we cleared notifications in the last 5 seconds, 
          // ignore any non-zero count from the server to prevent race conditions.
          final isRecentlyCleared = _lastNotificationClear != null && 
              DateTime.now().difference(_lastNotificationClear!).inSeconds < 5;

          // Only update notification count if we're NOT currently viewing the notifications screen
          // AND we didn't just clear them seconds ago.
          if (_currentIndex != 5 && !isRecentlyCleared) {
            _unreadNotifications = notifCount;
          } else {
            _unreadNotifications = 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading badge counts: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profileData = await SupabaseService.getCurrentUserProfile();
      if (profileData != null && mounted) {
        setState(() {
          _currentUserProfile = UserProfile.fromJson(profileData);
          // Sync domain pill with what the user's profile says
          final profileDomain = profileData['domain_id'] as String?;
          if (profileDomain != null && _domains.contains(profileDomain)) {
            _selectedDomain = profileDomain;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  /// Loads posts for [page] (0-based). Keeps only [_pageSize] in memory.
  Future<void> _loadPosts({String? domain, int page = 0}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = page == 0;
      _isLoadingMore = page != 0;
    });
    try {
      final targetDomain = domain ?? _selectedDomain;
      // Fetch one extra post so we know whether a next page exists
      final postsData = await SupabaseService.getPosts(
        limit: _pageSize + 1,
        offset: page * _pageSize,
        domain: targetDomain,
      );
      if (mounted) {
        final hasMore = postsData.length > _pageSize;
        final pagePosts = hasMore ? postsData.take(_pageSize).toList() : postsData;
        setState(() {
          _currentPage = page;
          _hasNextPage = hasMore;
          // Replace the cache — only current page lives in memory
          _posts = pagePosts.map((data) => Post.fromJson(data)).toList();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Go to the next page of posts.
  Future<void> _loadNextPage() async {
    await _loadPosts(page: _currentPage + 1);
    // Scroll back to top of feed
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  /// Go to the previous page of posts.
  Future<void> _loadPrevPage() async {
    if (_currentPage == 0) return;
    await _loadPosts(page: _currentPage - 1);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadGroups() async {
    try {
      final groupsData = await SupabaseService.getGroups();
      if (mounted) {
        setState(() {
          _sidebarGroups = groupsData.map((d) => Group.fromJson(d)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
    }
  }

  Future<void> _refreshPosts() async {
    // Always refresh from page 0
    await _loadPosts(page: 0);
    await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F7),
      drawer: isMobile
          ? Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildLeftSideBar(),
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isMobile),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Desktop Navigation Rail / Sidebar
                    if (!isMobile)
                      _buildDesktopNavRail(),
                    
                    // Main Content / Post Feed
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 0 : 20,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column (Home Feed / Profile info)
                            Expanded(
                              flex: 3,
                              child: IndexedStack(
                                index: _currentIndex,
                                children: [
                                  _buildHomeFeed(),      // 0
                                  SearchScreen(          // 1
                                    onBack: () => setState(() => _currentIndex = 0),
                                    autofocusSearch: _currentIndex == 1,
                                    searchOnlyConnections: _isSearchMessageContext,
                                  ),
                                  NetworkScreen(         // 2
                                    onBack: () => setState(() => _currentIndex = 0),
                                    onSearch: () => setState(() => _currentIndex = 1),
                                  ),
                                  MessagesListScreen(    // 3
                                    onBack: () => setState(() => _currentIndex = 0),
                                    onSearch: () => setState(() {
                                      _currentIndex = 1;
                                      _isSearchMessageContext = true;
                                    }),
                                  ),
                                  ProfileScreen(         // 4
                                    onBack: () => setState(() => _currentIndex = 0),
                                  ),
                                  NotificationsScreen(   // 5
                                    onBack: () => setState(() => _currentIndex = 0),
                                    onRefreshBadges: _loadBadgeCounts,
                                  ),
                                  RecentActivityScreen(  // 6
                                    onBack: () => setState(() => _currentIndex = 0),
                                  ),
                                  SavedItemsScreen(      // 7
                                    onBack: () => setState(() => _currentIndex = 0),
                                  ),
                                  SettingsScreen(        // 8
                                    onBack: () => setState(() => _currentIndex = 0),
                                  ),
                                  GroupsScreen(          // 9
                                    onBack: () => setState(() => _currentIndex = 0),
                                  ),
                                  EventsScreen(          // 10
                                    onBack: () => setState(() => _currentIndex = 0),
                                  ),
                                ],
                              ),
                            ),
                            // Right Sidebar (Only on wide screens)
                            if (MediaQuery.of(context).size.width > 1200 && _currentIndex == 0)
                              SizedBox(
                                width: 360,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(left: 20, top: 8),
                                  child: _buildRightSideBar(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
          // Floating Bottom Nav Pill — hides when scrolling up, shows on scroll down
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            bottom: _navVisible ? 20 : -90,
            left: 0,
            right: 0,
            child: Center(child: _buildBottomNavPill()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 10 : 12,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (isMobile)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF1C1C1E)),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            const AWLogo(size: 30),
            if (!isMobile) ...[
              const SizedBox(width: 10),
              const Text(
                'LinkSpec',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C1C1E),
                  letterSpacing: -0.5,
                ),
              ),
            ],
            const Spacer(),
            // Domain Switch Pill
            GestureDetector(
              onTap: _isSwitchingDomain ? null : _showDomainSwitcher,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSwitchingDomain)
                      const SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0066CC)),
                      )
                    else
                      const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF0066CC)),
                    const SizedBox(width: 5),
                    Text(
                      _selectedDomain,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0066CC),
                        fontSize: isMobile ? 12 : 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Notifications Bell
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildHeaderIcon(Icons.notifications_none_rounded, onTap: () async {
                  setState(() {
                    _currentIndex = 5;
                    _unreadNotifications = 0;
                    _lastNotificationClear = DateTime.now();
                  });
                  try {
                    await SupabaseService.markAllNotificationsAsRead();
                    await _loadBadgeCounts();
                  } catch (e) {
                    debugPrint('Failed to mark notifications as read: $e');
                  }
                }),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            // Logout Button
            _buildHeaderIcon(Icons.logout_rounded, onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w700)),
                  content: const Text('Are you sure you want to log out of LinkSpec?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                try {
                  SupabaseService.clearCache();
                  ref.read(savedPostsProvider.notifier).clear();
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                } catch (e) {
                  debugPrint('Logout error: $e');
                }
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: const Color(0xFF1C1C1E), size: 22),
      ),
    );
  }

  // Keep old name as alias so nothing breaks
  Widget _buildRoundIcon(IconData icon, {VoidCallback? onTap}) => _buildHeaderIcon(icon, onTap: onTap);

  Widget _buildHomeFeed() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // "Start a post" box — always at the top
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _buildStartPostBox(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Skeleton shown while initial loading
        if (_isLoading)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverToBoxAdapter(
              child: HomeSkeletonLoader(),
            ),
          )
        else if (_posts.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No posts yet in this domain.'),
                  if (_currentPage > 0) ...[
                    const SizedBox(height: 16),
                    _buildPaginationBar(),
                  ],
                ],
              ),
            ),
          )
        else ...[
          // ── Post list ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: PostCard(post: _posts[index]),
                ),
                childCount: _posts.length,
              ),
            ),
          ),

          // ── Pagination bar ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverToBoxAdapter(
              child: _buildPaginationBar(),
            ),
          ),
        ],
      ],
    );
  }

  /// Builds the Previous / page-info / Load More row.
  Widget _buildPaginationBar() {
    final isMobile = MediaQuery.of(context).size.width <= 600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: _currentPage > 0 ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: _isLoadingMore
                ? const SizedBox.shrink()
                : TextButton.icon(
                    onPressed: _currentPage > 0 ? _loadPrevPage : null,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
                    label: isMobile ? const SizedBox.shrink() : const Text('Previous'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0066CC),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
            child: _isLoadingMore
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Page ${_currentPage + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1C1C1E)),
                    ),
                  ),
          ),
          AnimatedOpacity(
            opacity: _hasNextPage ? 1.0 : 0.3,
            duration: const Duration(milliseconds: 200),
            child: _isLoadingMore
                ? const SizedBox.shrink()
                : TextButton.icon(
                    onPressed: _hasNextPage ? _loadNextPage : null,
                    icon: isMobile ? const SizedBox.shrink() : const Text('Next'),
                    label: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0066CC),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartPostBox() {
    final isMobile = MediaQuery.of(context).size.width < 480;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: isMobile ? 20 : 22,
                backgroundColor: const Color(0xFFE5E5EA),
                backgroundImage: _currentUserProfile?.avatarUrl != null
                    ? NetworkImage(_currentUserProfile!.avatarUrl!)
                    : null,
                child: _currentUserProfile?.avatarUrl == null
                    ? Text(
                        (_currentUserProfile?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1C1C1E)),
                      )
                    : null,
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showCreatePostDialog(),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14 : 16,
                      vertical: isMobile ? 10 : 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: Text(
                      'Start a post...',
                      style: TextStyle(color: Colors.grey[500], fontSize: isMobile ? 13 : 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE5E5EA)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPostTypeBtn(Icons.image_outlined, 'Media', const Color(0xFF0066CC)),
              _buildPostTypeBtn(Icons.calendar_month_outlined, 'Event', const Color(0xFFFF9500)),
              _buildPostTypeBtn(Icons.article_outlined, 'Article', const Color(0xFFFF6B00)),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog({PostType postType = PostType.general}) {
    showDialog(
      context: context,
      builder: (context) => CreatePostDialog(
        postType: postType,
        onPostCreated: _refreshPosts,
      ),
    );
  }

  Widget _buildPostTypeBtn(IconData icon, String label, Color color) {
    final isMobile = MediaQuery.of(context).size.width < 480;
    // Map label to PostType
    PostType postType = PostType.general;
    if (label == 'Event') postType = PostType.event;
    if (label == 'Article') postType = PostType.article;
    return InkWell(
      onTap: () => _showCreatePostDialog(postType: postType),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isMobile ? 16 : 18),
            SizedBox(width: isMobile ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 12 : 13,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSideBar() {
    return Column(
      children: [
        // Profile Card
        GestureDetector(
          onTap: () => _navigateTo(4),
          child: ClayContainer(
            borderRadius: 16,
            depth: 3,
            // Use a Stack so the avatar overlaps the cover INSIDE the container bounds
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Full card body (cover + padding for avatar + name) ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cover photo — real image or gradient fallback
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: _currentUserProfile?.coverUrl != null
                            ? Image.network(
                                _currentUserProfile!.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildCoverGradient(),
                              )
                            : _buildCoverGradient(),
                      ),
                    ),
                    // Space for avatar (radius 40 = 80px, half overlapping = 40px below cover)
                    const SizedBox(height: 48),
                    // Name + handle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      child: Column(
                        children: [
                          Text(
                            _currentUserProfile?.fullName ?? 'You',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2740),
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${(_currentUserProfile?.fullName ?? 'user').replaceAll(' ', '').toLowerCase()}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Avatar — Positioned to overlap the cover/body boundary ──
                Positioned(
                  top: 120 - 40, // cover height minus half the avatar radius = 80
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1A2740).withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue[50],
                        backgroundImage: _currentUserProfile?.avatarUrl != null
                            ? NetworkImage(_currentUserProfile!.avatarUrl!)
                            : null,
                        child: _currentUserProfile?.avatarUrl == null
                            ? Text(
                                (_currentUserProfile?.fullName ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Menu Groups
        _buildSidebarGroup([
          _buildSidebarItem(
            Icons.bookmark, 'Saved items',
            onTap: () => _navigateTo(7),
          ),
          _buildSidebarItem(
            Icons.settings, 'Settings',
            onTap: () => _navigateTo(8),
          ),
        ]),
        const SizedBox(height: 12),
        _buildSidebarGroup([
          _buildSidebarItem(
            Icons.trending_up, 'Recent activity',
            showPlus: true,
            onTap: () => _navigateTo(6),
            onPlusTap: () {
              showDialog(
                context: context,
                builder: (_) => CreatePostDialog(
                  onPostCreated: () => _loadPosts(),
                ),
              );
            },
          ),
          // Mixed recent content
          _buildSidebarItem(
            Icons.article_outlined, 'Latest posts',
            onTap: () => _navigateTo(6),
          ),
          _buildSidebarItem(
            Icons.event_note_outlined, 'Upcoming events',
            onTap: () => _navigateTo(6),
          ),
          /* Removed dynamic group tags */
        ]),
        const SizedBox(height: 12),
        // Groups & Events — combined container
        _buildSidebarGroup([
          _buildSidebarItem(
            Icons.group, 'Groups',
            isAction: true,
            onTap: () => _navigateTo(9),
          ),
          _buildSidebarItem(
            Icons.event, 'Events',
            isAction: true,
            onTap: () => _navigateTo(10),
          ),
        ]),
      ],
    );
  }

  /// Fallback gradient shown when no cover photo is uploaded.
  Widget _buildCoverGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFB4DA), Color(0xFFB4DAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildDesktopNavRail() {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE5E5EA), width: 0.5)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: _buildLeftSideBar(),
            ),
          ),
          // Sidebar Footer (optional)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '© 2026 LinkSpec',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarGroup(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: items),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, {
    bool showPlus = false,
    bool isAction = false,
    bool showArrow = false,
    VoidCallback? onTap,
    VoidCallback? onPlusTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isAction ? const Color(0xFF0066CC) : const Color(0xFF1C1C1E),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isAction ? const Color(0xFF0066CC) : const Color(0xFF1C1C1E),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showPlus)
                  GestureDetector(
                    onTap: onPlusTap ?? onTap,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Color(0xFF1C1C1E)),
                    ),
                  ),
                if (showArrow) 
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFF8E8E93)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClayContainer(
          borderRadius: 14,
          depth: 5,
          margin: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedDomain,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1C1C1E)),
                  ),
                  Row(children: [
                    Icon(Icons.menu, size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Icon(Icons.edit_note, size: 18, color: Colors.grey[500]),
                  ]),
                ],
              ),
              const SizedBox(height: 18),
              Text('Trending tags', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag('#PreventiveCare'),
                  _buildTag('#DigitalHealth'),
                  _buildTag('#PatientAwareness'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Suggested Discussions
        ClayContainer(
          borderRadius: 14,
          depth: 5,
          margin: const EdgeInsets.fromLTRB(8, 0, 4, 8),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Suggested Discussions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1C1C1E))),
              const SizedBox(height: 14),
              _buildDiscussionItem('The future of digital health in 2024', '150 comments'),
              const SizedBox(height: 10),
              _buildDiscussionItem('Healthy lifestyle tips for IT professionals', '36 comments'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAED), width: 0.5),
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[700])),
    );
  }

  Widget _buildDiscussionItem(String title, String stats) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EAED), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1C1C1E),
                    ),
                    softWrap: true,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(stats, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.favorite_border, size: 18, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  void _showDomainSwitcher() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Switch Domain',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)),
              ),
              const SizedBox(height: 4),
              const Text(
                'See posts from a different professional domain',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _domains.map((d) {
                  final isSelected = d == _selectedDomain;
                  return GestureDetector(
                    onTap: () async {
                      if (d == _selectedDomain) {
                        Navigator.pop(ctx);
                        return;
                      }
                      // Close sheet first
                      Navigator.pop(ctx);
                      // Show loading on pill
                      setState(() {
                        _selectedDomain = d;
                        _isSwitchingDomain = true;
                      });
                      try {
                        // Update Supabase cache so getPosts fetches correct domain
                        await SupabaseService.switchDomain(d);
                      } catch (_) {
                        // Ignore DB write failure — cache is still updated
                      }
                      // Reload feed from page 0 with new domain
                      await _loadPosts(page: 0);
                      await _loadGroups();
                      if (mounted) setState(() => _isSwitchingDomain = false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? 
                        const Color(0xFF0066CC) : const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0066CC) : const Color(0xFFE5E5EA),
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: const Color(0xFF0066CC).withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[  
                            const Icon(Icons.check_circle, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            d,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavPill() {
    final bool isMobile = MediaQuery.of(context).size.width <= 900;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFE8EAED), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 6 : 12,
          vertical: isMobile ? 6 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNavIcon(Icons.home_filled, 0),
            _buildNavIcon(Icons.search, 1),
            _buildNavIcon(Icons.groups_outlined, 2),
            // Create Post Button
            GestureDetector(
              onTap: () => _showCreatePostDialog(),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 14,
                  vertical: 8,
                ),
                child: Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.grey[400],
                  size: isMobile ? 22 : 26,
                ),
              ),
            ),
            _buildNavIcon(Icons.mail_outline, 3, badge: _unreadMessages),
            _buildNavIcon(Icons.person_pin, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData? icon, int index, {int badge = 0, String? assetPath}) {
    final bool isSelected = _currentIndex == index;
    final bool isMobile = MediaQuery.of(context).size.width <= 900;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          if (index == 3) {
            _unreadMessages = 0;
            _lastMessageClear = DateTime.now();
            SupabaseService.markAllMessagesAsRead();
          }
        });
        // Close drawer if open (bottom nav tapped while sidebar was open)
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          Navigator.of(context).pop();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: 8,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            assetPath != null
                ? Container(
                    width: isMobile ? 22 : 26,
                    height: isMobile ? 22 : 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0066CC) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    icon,
                    color: isSelected ? const Color(0xFF0066CC) : Colors.grey[400],
                    size: isMobile ? 22 : 26,
                  ),
            if (badge > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
