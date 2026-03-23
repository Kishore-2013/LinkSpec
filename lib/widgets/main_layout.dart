import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      showDialog(
        context: context,
        builder: (context) => CreatePostDialog(
          onPostCreated: () {
            // Success logic handled in dialog
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

  void _navigateTo(String route) {
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 700;
    final bool isTablet = screenWidth >= 700 && screenWidth < 1200;
    final bool isDesktop = screenWidth >= 1200;
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
      backgroundColor: Colors.white,
      drawer: isMobile ? Drawer(child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildLeftSideBar()))) : null,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isMobile, activeDomain),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 1400 ? screenWidth * 0.05 : 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1: Left Nav (Desktop/Tablet)
                      if (!isMobile)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: SingleChildScrollView(child: _buildLeftSideBar()),
                        ),

                      if (!isMobile) const SizedBox(width: 12),

                      // Column 2: Center Content
                      Expanded(
                        flex: 2,
                        child: widget.child,
                      ),

                      if (isDesktop) const SizedBox(width: 12),

                      // Column 3: Right Nav (Desktop only)
                      if (isDesktop)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: SingleChildScrollView(child: _buildRightSideBar(activeDomain)),
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
            InkWell(
              onTap: () => _showDomainSwitcher(context, ref, activeDomain),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activeDomain,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_drop_down, color: Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            _buildHeaderIcon(Icons.notifications_none_rounded, badge: _unreadNotifications, onTap: () => _navigateTo('/notifications')),
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

  void _showDomainSwitcher(BuildContext context, WidgetRef ref, String currentDomain) {
    final List<String> domains = [
      'Software Development',
      'AI, Data & Analytics',
      'Healthcare & Life Sciences',
      'Finance, Risk & Compliance',
      'Design & Creative',
      'Core Engineering',
      'Cybersecurity & Risk',
      'Networking & IT Support',
      'Cloud, DevOps & Infrastructure',
      'Data Engineering & Databases',
      'Business, Product & Management',
      'Agriculture & Environmental',
      'Sales, Marketing & CRM',
      'ERP & Enterprise Systems',
      'HR, Operations & Support',
      'Global',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Switch Domain',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'See posts from a different professional domain',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: domains.map((domain) {
                    final isSelected = domain == currentDomain;
                    return InkWell(
                      onTap: () {
                        ref.read(currentDomainProvider.notifier).state = domain;
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0066CC) : const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0066CC) : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_circle, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              domain,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
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

  Widget _buildLeftSideBar() {
    return Column(
      children: [
        // Profile Card
        GestureDetector(
          onTap: () => _navigateTo('/profile/${_currentUserProfile?.id ?? "unknown"}'),
          child: Card(
            elevation: 0.5,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.8),
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 100),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: _currentUserProfile != null && _currentUserProfile!.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: _currentUserProfile!.coverUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _buildCoverGradient(),
                                  errorWidget: (_, __, ___) => _buildCoverGradient(),
                                )
                              : _buildCoverGradient(),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        child: Column(
                          children: [
                            Text(
                              _currentUserProfile?.fullName ?? 'You',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
                  Positioned(
                    top: 120 - 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: _currentUserProfile != null
                            ? CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.blue[50],
                                backgroundImage: _currentUserProfile!.avatarUrl != null ? CachedNetworkImageProvider(_currentUserProfile!.avatarUrl!) : null,
                                child: _currentUserProfile!.avatarUrl == null
                                    ? Text((_currentUserProfile!.fullName ?? 'U')[0].toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.blue))
                                    : null,
                              )
                            : const CircleAvatar(radius: 40, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildSidebarGroup([
          _buildSidebarItem(Icons.bookmark, 'Saved items', onTap: () => _navigateTo('/saved-items')),
          _buildSidebarItem(Icons.settings, 'Settings', onTap: () => _navigateTo('/settings')),
        ]),
        const SizedBox(height: 12),
        _buildSidebarGroup([
          _buildSidebarItem(Icons.trending_up, 'Recent activity', showPlus: true, onTap: () => _navigateTo('/home')),
          _buildSidebarItem(Icons.article_outlined, 'Latest posts', onTap: () => _navigateTo('/home')),
          _buildSidebarItem(Icons.bar_chart_rounded, 'Top weekly', onTap: () => _navigateTo('/home')),
          _buildSidebarItem(Icons.event_note_outlined, 'Upcoming events', onTap: () => _navigateTo('/events')),
        ]),
        const SizedBox(height: 12),
        _buildSidebarGroup([
          _buildSidebarItem(Icons.group, 'Groups', isAction: true, onTap: () => _navigateTo('/groups')),
          _buildSidebarItem(Icons.event, 'Events', isAction: true, onTap: () => _navigateTo('/events')),
        ]),
      ],
    );
  }

  Widget _buildRightSideBar(String activeDomain) {
    final tags = _sidebarSvc.trendingTags;
    final discussions = _sidebarSvc.suggestedDiscussions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0.5,
          color: Colors.white,
          margin: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.8),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(activeDomain, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (_sidebarSvc.isLoadingTags) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Trending tags', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                const SizedBox(height: 10),
                tags.isEmpty
                    ? Text('No tags yet', style: TextStyle(color: Colors.grey[400], fontSize: 12))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) => _buildClickableTag(tag)).toList(),
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0.5,
          color: Colors.white,
          margin: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.8),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Suggested Discussions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (_sidebarSvc.isLoadingDiscussions) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 14),
                if (discussions.isEmpty)
                  Text('No discussions yet', style: TextStyle(color: Colors.grey[400], fontSize: 12))
                else
                  ...discussions.asMap().entries.map((e) {
                    final idx = e.key;
                    final disc = e.value;
                    final content = (disc['content'] as String? ?? '');
                    final title = content.length > 90 ? '${content.substring(0, 90)}…' : content;
                    final count = disc['comment_count'] ?? 0;
                    return Column(
                      children: [
                        if (idx > 0) const SizedBox(height: 10),
                        _buildDiscussionItem(title, '$count comments'),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarGroup(List<Widget> items) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.8),
      ),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: items)),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, {bool showPlus = false, bool isAction = false, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isAction ? Colors.blue : Colors.grey[600]),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isAction ? Colors.blue : Colors.black87, fontSize: 14), overflow: TextOverflow.ellipsis)),
              if (showPlus) Icon(Icons.add, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFFB4DA), Color(0xFFB4DAFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
    );
  }

  Widget _buildClickableTag(String label) {
    return GestureDetector(
      onTap: () => _navigateTo('/search'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withOpacity(0.25), width: 0.5),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.blue)),
      ),
    );
  }

  Widget _buildDiscussionItem(String title, String stats) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.1), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), softWrap: true),
            const SizedBox(height: 4),
            Row(children: [const Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(stats, style: const TextStyle(color: Colors.grey, fontSize: 11))]),
          ],
        ),
      ),
    );
  }
}