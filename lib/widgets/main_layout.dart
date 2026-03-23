import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import '../providers/domain_provider.dart';
import '../widgets/aw_logo.dart';
import '../api/sidebar_data_service.dart';
import '../widgets/create_post_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;
    final bool isWide = MediaQuery.of(context).size.width > 1200;
    final activeDomain = ref.watch(currentDomainProvider);
    final String location = GoRouterState.of(context).uri.path;

    // ✅ ONLY ADDITION
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
            ],
          ),

          // ✅ ONLY MODIFIED PART
          if (showNavbar)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: _buildBottomNavPill(location),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, {int badge = 0}) {
    return Stack(
      children: [
        Icon(icon, size: 26),
        if (badge > 0)
          Positioned(
            right: 0,
            top: 0,
            child: CircleAvatar(radius: 6, backgroundColor: Colors.red),
          ),
      ],
    );
  }

  Widget _buildStickyPanel(Widget child) {
    return SingleChildScrollView(child: child);
  }

  Widget _buildLeftSideBar() => Column(children: []);
  Widget _buildRightSideBar(String domain) => Column(children: []);

  Widget _buildBottomNavPill(String currentLocation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home),
          SizedBox(width: 12),
          Icon(Icons.search),
          SizedBox(width: 12),
          Icon(Icons.add),
          SizedBox(width: 12),
          Icon(Icons.message),
          SizedBox(width: 12),
          Icon(Icons.work),
        ],
      ),
    );
  }
}