import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../providers/domain_provider.dart';
import '../widgets/aw_logo.dart';
import '../api/sidebar_data_service.dart';
import '../widgets/create_post_dialog.dart';
import '../providers/scroll_provider.dart';
import 'bottom_nav_bar.dart';


class MainLayout extends ConsumerStatefulWidget {
  final Widget child;
  const MainLayout({Key? key, required this.child}) : super(key: key);

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  UserProfile? _currentUserProfile;
  late SidebarDataService _sidebarSvc;
  int _unreadNotifications = 0;
  int _unreadMessages = 0;

  // Accumulate small deltas before acting — prevents rapid flicker on web
  // trackpad and inertial scroll (which sends many tiny events).
  // Increase threshold to prevent flickering/accidental hiding
  static const double _scrollThreshold = 20.0;
  double _pendingDelta = 0;

  @override
  void initState() {
    super.initState();
    final initialDomain = ref.read(currentDomainProvider);
    _sidebarSvc = SidebarDataService(domain: initialDomain);
    _loadInitialData();
    // NOTE: Scroll detection is now handled by NotificationListener in build()
    // so it works for all input types: touch, mouse wheel, trackpad, keyboard.
  }

  @override
  void dispose() {
    _sidebarSvc.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final profileData = await SupabaseService.getCurrentUserProfile();
    if (profileData != null && mounted) {
      setState(() {
        _currentUserProfile = UserProfile.fromJson(profileData);
      });
    }
    _loadBadgeCounts();
    _loadSidebarData();
  }

  Future<void> _loadSidebarData() async {
    await Future.wait([
      _sidebarSvc.loadTrendingTags(onUpdate: () { if (mounted) setState(() {}); }),
      _sidebarSvc.loadSuggestedDiscussions(onUpdate: () { if (mounted) setState(() {}); }),
    ]);
  }

  Future<void> _loadBadgeCounts() async {
    try {
      final results = await Future.wait([
        SupabaseService.getUnreadNotificationCount(),
        SupabaseService.getUnreadMessageCount(),
      ]);
      if (mounted) {
        setState(() {
          _unreadNotifications = results[0];
          _unreadMessages = results[1];
        });
      }
    } catch (e) {
      debugPrint('Shell: Error loading badges: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final bool isWide = MediaQuery.of(context).size.width > 1200;
    final activeDomain = ref.watch(currentDomainProvider);
    final String location = GoRouterState.of(context).uri.path;

    ref.listen(currentDomainProvider, (prev, next) {
      if (prev != next) {
        _sidebarSvc.dispose();
        setState(() {
          _sidebarSvc = SidebarDataService(domain: next);
        });
        _loadSidebarData();
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F7),
      drawer: isMobile ? Drawer(child: _buildLeftSideBar()) : null,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isMobile, activeDomain, location),
              Expanded(
                // NotificationListener captures ALL scroll events from any
                // descendant: touch drag, mouse wheel, trackpad, keyboard.
                // scrollDelta > 0 → content moving up (user scrolling into feed) → HIDE
                // scrollDelta < 0 → content moving back to top → SHOW
                child: NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    final delta = notification.scrollDelta ?? 0;
                    final metrics = notification.metrics;

                    // Always show when snapped to the very top
                    if (metrics.pixels <= 0) {
                      if (!ref.read(navVisibilityProvider)) {
                        ref.read(navVisibilityProvider.notifier).state = true;
                        _pendingDelta = 0;
                      }
                      return false;
                    }

                    _pendingDelta += delta;

                    if (_pendingDelta > _scrollThreshold) {
                      // Scrolling forward (into content) — HIDE navbar
                      if (ref.read(navVisibilityProvider)) {
                        ref.read(navVisibilityProvider.notifier).state = false;
                      }
                      _pendingDelta = 0;
                    } else if (_pendingDelta < -_scrollThreshold) {
                      // Scrolling backward (toward top) — SHOW navbar
                      if (!ref.read(navVisibilityProvider)) {
                        ref.read(navVisibilityProvider.notifier).state = true;
                      }
                      _pendingDelta = 0;
                    }

                    return false; // allow notification to keep bubbling
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMobile)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: _buildStickyPanel(_buildLeftSideBar()),
                        ),
                      Expanded(
                        child: widget.child,
                      ),
                      if (isWide)
                         ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: _buildStickyPanel(_buildRightSideBar(activeDomain)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Floating Bottom Nav Pill
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSlide(
                // Always visible on all screens as requested (centered bottom pill)
                offset: Offset.zero,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: BottomNavBar(
                  currentIndex: _getNavIndex(location),
                  unreadMessages: _unreadMessages,
                  unreadNotifications: _unreadNotifications,
                  onTap: (index) => _handleNavTap(index),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, String activeDomain, String location) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 10,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (isMobile)
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            const AWLogo(size: 30),
            if (!isMobile) ...[
              const SizedBox(width: 10),
              const Text(
                'linkspec',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
            ],
            const Spacer(),
            // Domain Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 14, color: Colors.blue[700]),
                  const SizedBox(width: 6),
                  Text(
                    activeDomain,
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue[700], fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildHeaderIcon(Icons.notifications_none_rounded, badge: _unreadNotifications, onTap: () => context.go('/notifications')), 
            const SizedBox(width: 16),
            _buildHeaderIcon(Icons.logout_rounded, onTap: () async {
              await SupabaseService.signOut();
              context.go('/login');
            }),
          ],
        ),
      ),
    );
  }


  Widget _buildHeaderIcon(IconData icon, {int badge = 0, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: const Color(0xFF1C1C1E), size: 26),
          if (badge > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.red[600], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStickyPanel(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.12), width: 1)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: child,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('© 2026 linkspec', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSideBar() {
    return Column(
      children: [
        _buildProfileCard(),
        const SizedBox(height: 16),
        _buildSidebarItem(Icons.bookmark_border_rounded, 'Saved items', path: '/saved-items'),
        _buildSidebarItem(Icons.settings_outlined, 'Settings', path: '/settings'),
        const SizedBox(height: 24),
        _buildRecentActivity(),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, size: 18, color: Colors.blue[600]),
              const SizedBox(width: 8),
              const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.add, size: 14, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivityItem(Icons.article_outlined, 'Latest posts'),
          _buildActivityItem(Icons.bar_chart_rounded, 'Top weekly'),
          _buildActivityItem(Icons.event_note_rounded, 'Upcoming events'),
        ],
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildRightSideBar(String activeDomain) {
    final tags = _sidebarSvc.trendingTags;
    final discussions = _sidebarSvc.suggestedDiscussions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trending for $activeDomain', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.3)),
        const SizedBox(height: 16),
        if (_sidebarSvc.isLoadingTags)
          const LinearProgressIndicator(),
        if (tags.isEmpty && !_sidebarSvc.isLoadingTags)
           const Text('No tags yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((t) => _buildTag(t)).toList(),
        ),
        const SizedBox(height: 32),
        const Text('Suggested Discussions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.3)),
        const SizedBox(height: 16),
        if (discussions.isEmpty)
           const Text('No discussions yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ...discussions.map((d) => _buildDiscussionItem(d)),
      ],
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Text('#$tag', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildDiscussionItem(Map<String, dynamic> disc) {
    final content = disc['content'] as String? ?? '';
    final count = disc['comment_count'] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4)),
          const SizedBox(height: 4),
          Text('$count comments', style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cover Image
          Container(
            height: 90,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1579546929518-9e396f3cc809?q=80&w=1000'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -35),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 34,
                    backgroundImage: _currentUserProfile?.avatarUrl != null ? NetworkImage(_currentUserProfile!.avatarUrl!) : null,
                    child: _currentUserProfile?.avatarUrl == null ? const Icon(Icons.person, size: 30) : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentUserProfile?.fullName ?? 'Kishore Chinthala', 
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2),
                ),
                Text(
                  '@${(_currentUserProfile?.fullName ?? 'kishorechinthala').replaceAll(' ', '').toLowerCase()}', 
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, {required String path}) {
    final curPath = GoRouterState.of(context).uri.path;
    final bool isActive = curPath == path;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.blue[700] : Colors.grey[700], size: 22),
        title: Text(label, style: TextStyle(color: isActive ? Colors.blue[700] : Colors.black87, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, fontSize: 14)),
        onTap: () {
          if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
          context.go(path);
        },
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  int _getNavIndex(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/network')) return 2;
    if (location.startsWith('/messages')) return 4;
    if (location.startsWith('/jobs')) return 5;
    return 0; // Default to Home
  }

  void _handleNavTap(int index) {
    switch (index) {
      case 0: context.go('/home'); break;
      case 1: context.go('/search'); break;
      case 2: context.go('/network'); break;
      case 3: 
        showDialog(context: context, builder: (context) => const CreatePostDialog());
        break;
      case 4: context.go('/messages'); break;
      case 5: context.go('/jobs'); break;
    }
  }
}
