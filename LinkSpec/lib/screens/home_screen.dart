import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
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
  final _scrollController = ScrollController();
  List<Post> _posts = [];
  UserProfile? _currentUserProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadPosts();
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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final postsData = await SupabaseService.getPosts(limit: 20, offset: 0);
      if (mounted) {
        setState(() {
          _posts = postsData.map((data) => Post.fromJson(data)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPosts() async {
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                _buildHeader(),
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
                            _buildHomeFeed(),
                            const SearchScreen(),
                            const NetworkScreen(),
                            const MessagesListScreen(),
                            const NotificationsScreen(),
                            const ProfileScreen(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const AWLogo(size: 36),
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
            const Spacer(),
            // Domain Pill
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 1),
              child: ClayContainer(
                borderRadius: 20,
                depth: 6,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _currentUserProfile?.domainId ?? 'Medical',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.search, size: 20, color: Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // User Icon Button
            _buildRoundIcon(Icons.notifications_none, onTap: () => setState(() => _currentIndex = 4)),
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
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.blue[800]),
        ),
      ),
    );
  }

  Widget _buildHomeFeed() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildStartPostBox(),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_posts.isEmpty)
                const Center(child: Text('No posts yet.'))
              else
                ..._posts.map((post) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: PostCard(post: post),
                )).toList(),
            ]),
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
          onTap: () => setState(() => _currentIndex = 5),
          child: ClayContainer(
            borderRadius: 30,
            depth: 8,
            child: Column(
              children: [
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFB4DA), Color(0xFFB4DAFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundImage: _currentUserProfile?.avatarUrl != null ? NetworkImage(_currentUserProfile!.avatarUrl!) : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_currentUserProfile?.fullName ?? 'Kishore Chinthala', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('@${_currentUserProfile?.fullName.replaceAll(' ', '').toLowerCase() ?? 'kishorewrites'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Menu Groups
        _buildSidebarGroup([
          _buildSidebarItem(Icons.bookmark, 'Saved items'),
          _buildSidebarItem(Icons.settings, 'Settings'),
        ]),
        const SizedBox(height: 12),
        _buildSidebarGroup([
          _buildSidebarItem(Icons.trending_up, 'Recent', showPlus: true),
          _buildSidebarItem(Icons.tag, '# Medical'),
          _buildSidebarItem(Icons.play_circle_outline, '# We\'re Hiring in IT!'),
          _buildSidebarItem(Icons.add, 'Groups', isAction: true),
        ]),
        const SizedBox(height: 12),
        _buildSidebarGroup([
          _buildSidebarItem(Icons.explore, 'Medical', showArrow: true),
          _buildSidebarItem(Icons.chat_bubble_outline, '# We\'re Hiring in IT!'),
          _buildSidebarItem(Icons.add, 'Events', isAction: true),
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

  Widget _buildSidebarItem(IconData icon, String label, {bool showPlus = false, bool isAction = false, bool showArrow = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isAction ? Colors.blue : Colors.blue[300]),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isAction ? Colors.blue : Colors.grey[800], fontSize: 14))),
          if (showPlus) const Icon(Icons.add, size: 16, color: Colors.grey),
          if (showArrow) const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
        ],
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

  Widget _buildBottomNavPill() {
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavIcon(Icons.home, 0),
                _buildNavIcon(Icons.search, 1),
                _buildNavIcon(Icons.groups_outlined, 2),
                _buildNavIcon(Icons.mail_outline, 3, badge: 2),
                _buildNavIcon(Icons.notifications_none, 4, badge: 1),
                _buildNavIcon(Icons.person_pin, 5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, int index, {int badge = 0}) {
    final bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: isSelected ? Colors.blue[900] : Colors.blue[400], size: 26),
            if (badge > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(badge.toString(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
