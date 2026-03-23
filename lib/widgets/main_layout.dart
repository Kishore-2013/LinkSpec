import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../providers/domain_provider.dart';
import '../widgets/aw_logo.dart';
import '../api/sidebar_data_service.dart';
import '../widgets/create_post_dialog.dart';
import '../widgets/bottom_nav_bar.dart';

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

  @override
  void initState() {
    super.initState();
    final initialDomain = ref.read(currentDomainProvider);
    _sidebarSvc = SidebarDataService(domain: initialDomain);
    _loadInitialData();
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

  void _onBottomNavTap(int index, String currentLocation) {
    if (index == 3) {
      // Show Post Dialog
      showDialog(
        context: context,
        builder: (context) => CreatePostDialog(
          onPostCreated: () {
            // Success logic already handled inside dialog
          },
        ),
      );
      return;
    }

    final String targetRoute = switch (index) {
      0 => '/home',
      1 => '/search',
      2 => '/network',
      4 => '/messages',
      5 => '/jobs',
      _ => '/home',
    };

    if (!currentLocation.startsWith(targetRoute)) {
      context.go(targetRoute);
    }
  }

  int _getCurrentIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/network')) return 2;
    if (location.startsWith('/messages')) return 4;
    if (location.startsWith('/jobs')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final activeDomain = ref.watch(currentDomainProvider);
    final String location = GoRouterState.of(context).uri.path;

    final bool showNavbar =
        !location.contains('/login') &&
        !location.contains('/signup');

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
              _buildHeader(isMobile, activeDomain),
              Expanded(
                child: Padding(
                  // Add bottom padding to prevent overlapping with the floating nav bar
                  padding: EdgeInsets.only(bottom: showNavbar ? 100 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Note: sidebars are currently handled by individual screens
                      // like HomeScreen to maintain visual and functional parity.
                      Expanded(
                        child: widget.child,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (showNavbar)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: BottomNavBar(
                  currentIndex: _getCurrentIndex(location),
                  onTap: (index) => _onBottomNavTap(index, location),
                  unreadMessages: _unreadMessages,
                  unreadNotifications: _unreadNotifications,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile, String activeDomain) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 10),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(activeDomain),
            ),
            const SizedBox(width: 16),
            _buildHeaderIcon(Icons.notifications_none_rounded, badge: _unreadNotifications),
            const SizedBox(width: 12),
            _buildHeaderIcon(Icons.mail_outline_rounded, badge: _unreadMessages),
            const SizedBox(width: 8),
            _buildHeaderIcon(Icons.logout_rounded, onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w700)),
                  content: const Text('Are you sure you want to log out of linkspec?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                await SupabaseService.signOut();
                if (mounted) context.go('/login');
              }
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
        children: [
          Icon(icon, size: 26),
          if (badge > 0)
            Positioned(
              right: 0,
              top: 0,
              child: CircleAvatar(radius: 6, backgroundColor: Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildLeftSideBar() => Column(children: []);
}