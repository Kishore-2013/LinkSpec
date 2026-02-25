import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
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
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();
  List<Post> _posts = [];
  UserProfile? _currentUserProfile;
  bool _isLoading = true;

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

  // Track when we last cleared notifications to prevent race conditions
  DateTime? _lastNotificationClear;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadPosts();
    _loadGroups();
    _loadBadgeCounts();
    // Refresh badges every 30 seconds
    _badgeTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadBadgeCounts();
    });
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBadgeCounts() async {
    try {
      final msgCount = await SupabaseService.getUnreadMessageCount();
      final notifCount = await SupabaseService.getUnreadNotificationCount();
      if (mounted) {
        setState(() {
          _unreadMessages = msgCount;
          
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

  Future<void> _loadPosts({String? domain}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Use the passed domain or fall back to what's currently selected in the UI
      final targetDomain = domain ?? _selectedDomain;
      final postsData = await SupabaseService.getPosts(
        limit: 20,
        offset: 0,
        domain: targetDomain,
      );
      if (mounted) {
        setState(() {
          _posts = postsData.map((data) => Post.fromJson(data)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) setState(() => _isLoading = false);
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
    await _loadPosts();
    await _loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 900;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile
          ? Drawer(
              backgroundColor: const Color(0xFFD9E9FF),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildLeftSideBar(),
                ),
              ),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFD9E9FF),
              Color(0xFFB4DAFF),
              Color(0xFFD9E9FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(isMobile),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Sidebar (Desktop/Wide)
                      if (MediaQuery.of(context).size.width > 900)
                        SizedBox(
                          width: 320,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 8, 8, 100),
                            child: _buildLeftSideBar(),
                          ),
                        ),
                      
                      // Main Content
                      Expanded(
                        child: IndexedStack(
                          index: _currentIndex,
                          children: [
                            _buildHomeFeed(),      // 0
                            SearchScreen(          // 1
                              onBack: () => setState(() => _currentIndex = 0),
                            ),
                            NetworkScreen(         // 2
                              onBack: () => setState(() => _currentIndex = 0),
                              onSearch: () => setState(() => _currentIndex = 1),
                            ),
                            MessagesListScreen(    // 3
                              onBack: () => setState(() => _currentIndex = 0),
                              onSearch: () => setState(() => _currentIndex = 1),
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
                      
                      // Right Sidebar (Desktop/Wide)
                      if (MediaQuery.of(context).size.width > 1200)
                        SizedBox(
                          width: 340,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(8, 8, 24, 100),
                            child: _buildRightSideBar(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Floating Bottom Nav Pill
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: _buildBottomNavPill()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (isMobile)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF003366)),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            const AWLogo(size: 36),
            if (!isMobile) ...[
              const SizedBox(width: 12),
              const Text(
                'LinkSpec',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF003366),
                  letterSpacing: -0.5,
                ),
              ),
            ],
            const Spacer(),
            // Domain Switch Pill
            GestureDetector(
              onTap: _isSwitchingDomain ? null : _showDomainSwitcher,
              child: ClayContainer(
                borderRadius: 20,
                depth: 6,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSwitchingDomain)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                      )
                    else
                      const Icon(Icons.swap_horiz, size: 18, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      _selectedDomain,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Notifications Bell (top bar)
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildRoundIcon(Icons.notifications_none, onTap: () async {
                  setState(() {
                    _currentIndex = 5;  // Notifications is index 5
                    _unreadNotifications = 0;
                    _lastNotificationClear = DateTime.now();
                  });
                  try {
                    await SupabaseService.markAllNotificationsAsRead();
                    debugPrint('Successfully marked notifications as read');
                    // Force refresh badge counts immediately to ensure the '0' is reflected
                    await _loadBadgeCounts();
                  } catch (e) {
                    debugPrint('Failed to mark notifications as read: $e');
                  }
                }),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(_unreadNotifications.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildRoundIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClayContainer(
        borderRadius: 100,
        depth: 6,
        child: Container(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width <= 900 ? 8 : 12),
          child: Icon(
            icon,
            color: Colors.blue[800],
            size: MediaQuery.of(context).size.width <= 900 ? 20 : 24,
          ),
        ),
      ),
    );
  }

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
                const SizedBox(height: 24),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: Text('No posts yet in this domain.')),
                  ),
              ],
            ),
          ),
        ),

        // Posts — lazy builder: only builds what is actually scrolled into view
        // so _recordImpression() in PostCard.initState fires only for visible cards.
        if (!_isLoading && _posts.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
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
      ],
    );
  }

  Widget _buildStartPostBox() {
    return ClayContainer(
      borderRadius: 40,
      depth: 10,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white,
                backgroundImage: _currentUserProfile?.avatarUrl != null ? NetworkImage(_currentUserProfile!.avatarUrl!) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _showCreatePostDialog(),
                  child: ClayContainer(
                    borderRadius: 30,
                    depth: -6, // Inset feel
                    emboss: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text('Start a post', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPostTypeBtn(Icons.image, 'Media', Colors.blue),
              _buildPostTypeBtn(Icons.calendar_month, 'Event', Colors.orange),
              _buildPostTypeBtn(Icons.article, 'Write article', Colors.orange[800]!),
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
    return InkWell(
      onTap: () => _showCreatePostDialog(),
      child: ClayContainer(
        borderRadius: 15,
        depth: 4,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
          onTap: () => setState(() => _currentIndex = 4),
          child: ClayContainer(
            borderRadius: 30,
            depth: 8,
            // Use a Stack so the avatar overlaps the cover INSIDE the container bounds
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Full card body (cover + padding for avatar + name) ──
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cover gradient — clipped to top rounded corners only
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      child: Container(
                        height: 72,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFB4DA), Color(0xFFB4DAFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
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
                  top: 72 - 40, // cover height minus half the avatar = 32
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
            onTap: () => setState(() => _currentIndex = 7),
          ),
          _buildSidebarItem(
            Icons.settings, 'Settings',
            onTap: () => setState(() => _currentIndex = 8),
          ),
        ]),
        const SizedBox(height: 12),
        _buildSidebarGroup([
          _buildSidebarItem(
            Icons.trending_up, 'Recent activity',
            showPlus: true,
            onTap: () => setState(() => _currentIndex = 6),
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
            onTap: () => setState(() => _currentIndex = 6),
          ),
          _buildSidebarItem(
            Icons.event_note_outlined, 'Upcoming events',
            onTap: () => setState(() => _currentIndex = 6),
          ),
          // Dynamic group channels
          ..._sidebarGroups.take(2).map((group) => _buildSidebarItem(
            Icons.tag,
            '# ${group.name}',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
              );
            },
          )),
        ]),
        const SizedBox(height: 12),
        // Groups & Events — combined container
        _buildSidebarGroup([
          _buildSidebarItem(
            Icons.group, 'Groups',
            isAction: true,
            onTap: () => setState(() => _currentIndex = 9),
          ),
          _buildSidebarItem(
            Icons.event, 'Events',
            isAction: true,
            onTap: () => setState(() => _currentIndex = 10),
          ),
        ]),
      ],
    );
  }

  Widget _buildSidebarGroup(List<Widget> items) {
    return ClayContainer(
      borderRadius: 25,
      depth: 6,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.blue.withOpacity(0.08),
        highlightColor: Colors.blue.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isAction ? Colors.blue[600] : Colors.blue[400]),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAction ? Colors.blue[600] : const Color(0xFF1A2740),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showPlus)
                GestureDetector(
                  onTap: onPlusTap ?? onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.add, size: 18, color: Colors.blue[400]),
                  ),
                ),
              if (showArrow) Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightSideBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClayContainer(
          borderRadius: 30,
          depth: 8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Medical', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  Row(children: [const Icon(Icons.menu, size: 20), const SizedBox(width: 8), const Icon(Icons.edit_note, size: 20)]),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Trending tags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
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
        const SizedBox(height: 20),
        // Suggested Discussions
        ClayContainer(
          borderRadius: 30,
          depth: 8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Suggested Discussions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 16),
              _buildDiscussionItem('The future of digital health in 2024', '150 comments'),
              const SizedBox(height: 12),
              _buildDiscussionItem('Healthy lifestyle tips for IT professionals', '36 comments'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label) {
    return ClayContainer(
      borderRadius: 15,
      depth: 4,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildDiscussionItem(String title, String stats) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClayContainer(
        borderRadius: 20,
        depth: -4, // Inset
        emboss: true,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(stats, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.favorite_border, size: 18, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  void _showDomainSwitcher() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: const Color(0xFFDCEDFF),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.blue[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Switch Domain',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF003366)),
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
                      // Reload feed and groups with new domain
                      await _loadPosts();
                      await _loadGroups();
                      if (mounted) setState(() => _isSwitchingDomain = false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFBFD0EE),
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
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
                              color: isSelected ? Colors.white : const Color(0xFF4A6FA5),
                              fontWeight: FontWeight.w700,
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
        color: Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ClayContainer(
            borderRadius: 100,
            depth: 10,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 12,
              vertical: isMobile ? 6 : 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavIcon(Icons.home, 0),
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
                      color: Colors.blue[400],
                      size: isMobile ? 22 : 26,
                    ),
                  ),
                ),
                _buildNavIcon(Icons.mail_outline, 3, badge: _unreadMessages),
                _buildNavIcon(Icons.person_pin, 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {int badge = 0}) {
    final bool isSelected = _currentIndex == index;
    final bool isMobile = MediaQuery.of(context).size.width <= 900;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          if (index == 3) _unreadMessages = 0;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 16,
          vertical: 8,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue[900] : Colors.blue[400],
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
