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
      body: Column(
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
      bottomNavigationBar: isMobile ? _buildBottomNav(location) : null,
    );
  }

  Widget _buildHeader(bool isMobile, String activeDomain) {
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                activeDomain,
                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0066CC), fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            _buildHeaderIcon(Icons.notifications_none_rounded, badge: _unreadNotifications, onTap: () => context.go('/home')), 
            const SizedBox(width: 8),
            _buildHeaderIcon(Icons.mail_outline_rounded, badge: _unreadMessages, onTap: () => context.go('/home')),
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
          Icon(icon, color: const Color(0xFF1C1C1E)),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
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
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.1), width: 0.5)),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: child,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('© 2026 linkspec', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
        _buildSidebarItem(Icons.home_outlined, 'Home', path: '/home'),
        _buildSidebarItem(Icons.search_rounded, 'Search', path: '/search'),
        _buildSidebarItem(Icons.work_outline_rounded, 'Jobs', path: '/jobs'),
        _buildSidebarItem(Icons.bookmark_outline_rounded, 'Saved items', path: '/saved-items'),
        _buildSidebarItem(Icons.settings_outlined, 'Settings', path: '/settings'),
      ],
    );
  }

  Widget _buildRightSideBar(String activeDomain) {
    final tags = _sidebarSvc.trendingTags;
    final discussions = _sidebarSvc.suggestedDiscussions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trending for $activeDomain', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        if (_sidebarSvc.isLoadingTags)
          const LinearProgressIndicator(),
        if (tags.isEmpty && !_sidebarSvc.isLoadingTags)
           const Text('No tags yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags.map((t) => _buildTag(t)).toList(),
        ),
        const SizedBox(height: 24),
        const Text('Suggested Discussions', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        if (discussions.isEmpty)
           const Text('No discussions yet.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ...discussions.map((d) => _buildDiscussionItem(d)),
      ],
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
      child: Text('#$tag', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildDiscussionItem(Map<String, dynamic> disc) {
    final content = disc['content'] as String? ?? '';
    final count = disc['comment_count'] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          Text('$count comments', style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: _currentUserProfile?.avatarUrl != null ? NetworkImage(_currentUserProfile!.avatarUrl!) : null,
              child: _currentUserProfile?.avatarUrl == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(height: 12),
            Text(_currentUserProfile?.fullName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('@${(_currentUserProfile?.fullName ?? 'user').replaceAll(' ', '').toLowerCase()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, {required String path}) {
    final curPath = GoRouterState.of(context).uri.path;
    final bool isActive = curPath == path;
    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.blue : Colors.grey),
      title: Text(label, style: TextStyle(color: isActive ? Colors.blue : Colors.black87, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      onTap: () {
        if (MediaQuery.of(context).size.width < 900) Navigator.pop(context);
        context.go(path);
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildBottomNav(String currentLocation) {
    return BottomNavigationBar(
      currentIndex: _getBottomNavIndex(currentLocation),
      onTap: (index) {
        switch (index) {
          case 0: context.go('/home'); break;
          case 1: context.go('/home'); break; // Network
          case 2: context.go('/home'); break; // Post
          case 3: context.go('/home'); break; // Message
          case 4: context.go('/jobs'); break; 
        }
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Network'),
        BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Post'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
        BottomNavigationBarItem(icon: Icon(Icons.work_outline), label: 'Jobs'),
      ],
    );
  }

  int _getBottomNavIndex(String path) {
    if (path == '/home') return 0;
    if (path == '/jobs') return 4;
    return 0;
  }
}
