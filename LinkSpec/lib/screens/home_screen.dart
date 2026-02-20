import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_dialog.dart';
import 'messages_list_screen.dart';
import 'network_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'jobs_screen.dart';
import 'post_create_screen.dart';
import 'saved_items_screen.dart';
import '../widgets/aw_logo.dart';
import 'dart:async';

/// Home Screen with Feed and Messages
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final _scrollController = ScrollController();
  List<Post> _posts = [];
  UserProfile? _currentUserProfile;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _offset = 0;
  final int _limit = 20;
  StreamSubscription? _notifSubscription;
  String? _lastNotifId;
  bool _hasNewNotification = false;
  final DateTime _startTime = DateTime.now();
  final Set<int> _visitedTabs = {0};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadPosts();
    _scrollController.addListener(_onScroll);
    _setupGlobalNotifications();
  }

  void _setupGlobalNotifications() {
    _notifSubscription = SupabaseService.getNotificationsStream().listen((data) {
      if (data.isNotEmpty) {
        final newNotif = data.first;
        final notifId = newNotif['id'];
        // Parse as UTC explicitly for comparison
        final createdAt = DateTime.parse(newNotif['created_at']).toUtc();
        
        // Show if new post-restart (with 5-second buffer for safety)
        if (notifId != _lastNotifId && 
            createdAt.isAfter(_startTime.toUtc().subtract(const Duration(seconds: 5))) && 
            _currentIndex != 3) {
          _lastNotifId = notifId;
          _hasNewNotification = true;
          _showNotificationToast(newNotif);
        }
      }
    });
  }

  void _showNotificationToast(Map<String, dynamic> notif) {
    String message = 'New interaction on your post!';
    if (notif['type'] == 'like') message = 'Someone liked your post';
    if (notif['type'] == 'comment') message = 'Someone commented on your post';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton(
              onPressed: () {
                setState(() => _currentIndex = 3);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: const Text('VIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _notifSubscription?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      _loadMorePosts();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profileData = await SupabaseService.getCurrentUserProfile();
      if (profileData != null && mounted) {
        setState(() {
          _currentUserProfile = UserProfile.fromJson(profileData);
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final postsData = await SupabaseService.getPosts(limit: _limit, offset: 0);
      if (mounted) {
        setState(() {
          _posts = postsData.map((data) => Post.fromJson(data)).toList();
          _offset = _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error loading posts: $e');
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final postsData = await SupabaseService.getPosts(limit: _limit, offset: _offset);
      if (mounted && postsData.isNotEmpty) {
        setState(() {
          _posts.addAll(postsData.map((data) => Post.fromJson(data)));
          _offset += _limit;
        });
      }
    } catch (e) {
      print('Error loading more posts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      _offset = 0;
    });
    await _loadPosts();
  }

  void _showCreatePostDialog({PostType postType = PostType.general}) {
    showDialog(
      context: context,
      builder: (context) => CreatePostDialog(
        postType: postType,
        onPostCreated: () {
          _refreshPosts();
        },
      ),
    );
  }

  Future<void> _handleSignOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      _showErrorSnackBar('Error signing out: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE), // LinkedIn Background Color
      drawer: isWideScreen ? null : Drawer(
        width: MediaQuery.of(context).size.width * 0.8,
        backgroundColor: const Color(0xFFF4F2EE),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildLeftSideBar(),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: _handleSignOut,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 64,
        leading: Padding(
          padding: const EdgeInsets.only(left: 14.0, top: 10.0, bottom: 10.0),
          child: Builder(
            builder: (context) => GestureDetector(
              onTap: () {
                if (isWideScreen) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                } else {
                  Scaffold.of(context).openDrawer();
                }
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage: _currentUserProfile?.avatarUrl != null && _currentUserProfile!.avatarUrl!.isNotEmpty
                    ? NetworkImage(_currentUserProfile!.avatarUrl!)
                    : null,
                child: _currentUserProfile?.avatarUrl == null || _currentUserProfile!.avatarUrl!.isEmpty
                    ? Text(
                        _currentUserProfile?.fullName.isNotEmpty == true ? _currentUserProfile!.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                      )
                    : null,
              ),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!, width: 0.8),
          ),
          child: TextField(
            readOnly: true,
            onTap: () {
              // Future: Open search screen
            },
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w400),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.black54, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessagesListScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1128), // LinkedIn's standard container width
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. LEFT SIDEBAR (Hide on mobile)
              if (isWideScreen)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, left: 16),
                    child: _buildLeftSideBar(),
                  ),
                ),

              // 2. MAIN FEED
              Expanded(
                flex: 7,
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    // Home Feed Tab
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : RefreshIndicator(
                            onRefresh: _refreshPosts,
                            child: CustomScrollView(
                              controller: _scrollController,
                              slivers: [
                                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                                // Start a Post Box
                                SliverToBoxAdapter(child: _buildStartPostBox()),
                                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                                
                                _posts.isEmpty
                                    ? SliverFillRemaining(child: _buildEmptyState())
                                    : SliverPadding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        sliver: SliverList(
                                          delegate: SliverChildBuilderDelegate(
                                            (context, index) {
                                              if (index == _posts.length) {
                                                return const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(16.0),
                                                    child: CircularProgressIndicator(),
                                                  ),
                                                );
                                              }
                                              return PostCard(
                                                post: _posts[index],
                                                onPostDeleted: _refreshPosts,
                                              );
                                            },
                                            childCount: _posts.length + (_isLoadingMore ? 1 : 0),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                    // 2. Network Tab
                    _visitedTabs.contains(1) ? const NetworkScreen() : const SizedBox.shrink(),
                    // 3. Post Tab
                    _visitedTabs.contains(2) ? PostCreateScreen(onPostCreated: _refreshPosts) : const SizedBox.shrink(),
                    // 4. Notifications Tab
                    _visitedTabs.contains(3) ? const NotificationsScreen() : const SizedBox.shrink(),
                    // 5. Jobs Tab
                    _visitedTabs.contains(4) ? const JobsScreen() : const SizedBox.shrink(),
                  ],
                ),
              ),

              // 3. RIGHT SIDEBAR (Hide on mobile)
              if (isWideScreen)
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16, right: 16, left: 16),
                    child: _buildRightSideBar(),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _visitedTabs.add(index);
            if (index == 3) _hasNewNotification = false;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Network',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _hasNewNotification,
              child: const Icon(Icons.notifications_none),
            ),
            activeIcon: const Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.work_outline),
            activeIcon: Icon(Icons.work),
            label: 'Jobs',
          ),
        ],
      ),
    );
  }

  Widget _buildStartPostBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _currentUserProfile?.avatarUrl != null && _currentUserProfile!.avatarUrl!.isNotEmpty
                      ? NetworkImage(_currentUserProfile!.avatarUrl!)
                      : null,
                  child: _currentUserProfile?.avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.blue)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _showCreatePostDialog,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Start a post',
                      style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPostActionButton(Icons.image, 'Media', Colors.blue, type: PostType.general),
              _buildPostActionButton(Icons.calendar_month, 'Event', Colors.orange, type: PostType.event),
              _buildPostActionButton(Icons.article, 'Write article', Colors.orange[800]!, type: PostType.article),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPostActionButton(IconData icon, String label, Color color, {PostType type = PostType.general}) {
    return InkWell(
      onTap: () => _showCreatePostDialog(postType: type),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftSideBar() {
    if (_currentUserProfile == null) return const SizedBox.shrink();
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          children: [
                            Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                                image: const DecorationImage(
                                  image: NetworkImage('https://images.unsplash.com/photo-1579546929518-9e396f3cc809?q=80&w=2070&auto=format&fit=crop'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 38),
                          ],
                        ),
                        Positioned(
                          top: 24,
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 34,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _currentUserProfile?.avatarUrl != null
                                  ? NetworkImage(_currentUserProfile!.avatarUrl!)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          Text(
                            _currentUserProfile!.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentUserProfile!.bio ?? "Add a bio to your profile",
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Divider(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Profile viewers/impressions removed as requested
              const Divider(height: 1),
              _buildSidebarItem(Icons.bookmark, 'Saved items', onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SavedItemsScreen(),
                  ),
                );
              }),
              const Divider(height: 1),
              _buildSidebarItem(Icons.settings_outlined, 'Settings', onTap: () {
                Navigator.pushNamed(context, '/settings');
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Recent', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_posts.isEmpty) ...[
                _buildRecentItem('${_currentUserProfile?.domainId.toUpperCase() ?? 'Domain'} Experts'),
                _buildRecentItem('Hiring Trends 2026'),
              ] else ...[
                _buildRecentItem('# ${_currentUserProfile?.domainId ?? 'Professional'}'),
                ..._posts.take(2).map((p) => _buildRecentItem(p.content.split('\n').first, isPost: true)),
              ],
              const SizedBox(height: 12),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/groups'),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Groups', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Events feature coming soon!'))),
                    child: const Text('Events', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 16, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showCreatePostDialog(postType: PostType.event),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItem(String text, {bool isPost = false}) {
    return InkWell(
      onTap: () {
        if (isPost) {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(isPost ? Icons.article_outlined : Icons.groups_outlined, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text, 
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightSideBar() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add to your feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                ],
              ),
              const SizedBox(height: 16),
              _buildRecommendationItem('ApplyWizz', 'Official • Talent Solutions', 'https://logo.clearbit.com/google.com'),
              _buildRecommendationItem('Top Recruiter', 'Hiring for Tech Roles', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=1974&auto=format&fit=crop'),
              _buildRecommendationItem('Industry Lead', 'Insights into AI & Dev', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=1974&auto=format&fit=crop'),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 1; // Switch to Network tab
                    _visitedTabs.add(1);
                  });
                },
                child: const Row(
                  children: [
                    Text('View all recommendations', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                    Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _buildFooterLink('About'),
              _buildFooterLink('Accessibility'),
              _buildFooterLink('Help Center'),
              _buildFooterLink('Privacy & Terms'),
              _buildFooterLink('Ad Choices'),
              _buildFooterLink('Advertising'),
              _buildFooterLink('Business Services'),
              _buildFooterLink('Get the LinkedIn app'),
              _buildFooterLink('More'),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AWLogo(size: 18),
            const SizedBox(width: 6),
            Text('LinkSpec Corporation © 2026', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendationItem(String name, String bio, String img) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(img),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(bio, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Following $name')),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Follow'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[700]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600]));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showCreatePostDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
