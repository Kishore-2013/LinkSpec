
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';

class MemberProfileScreen extends StatefulWidget {
  final String userId;

  const MemberProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _profile;
  bool _isLoading = true;
  int _postCount = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  List<Post> _userPosts = [];
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profileData = await SupabaseService.getUserProfile(widget.userId);
      if (profileData != null) {
        _profile = UserProfile.fromJson(profileData);
        final stats = await SupabaseService.getConnectionCounts(widget.userId);
        _followerCount = stats['followers'] ?? 0;
        _followingCount = stats['following'] ?? 0;
        _postCount = await SupabaseService.getUserPostCount(widget.userId);
        final postsData =
            await SupabaseService.getPostsByUser(userId: widget.userId);
        _userPosts = postsData.map((d) => Post.fromJson(d)).toList();
        _isFollowing = await SupabaseService.isFollowing(widget.userId);
      }
    } catch (e) {
      print('Error loading member profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _isFollowLoading = true);
    try {
      if (_isFollowing) {
        await SupabaseService.unfollowUser(widget.userId);
        _isFollowing = false;
        _followerCount--;
      } else {
        await SupabaseService.followUser(widget.userId);
        _isFollowing = true;
        _followerCount++;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_profile == null) {
      return const Scaffold(
          body: Center(child: Text('User not found')));
    }

    final latestSchool = _profile!.education.isNotEmpty
        ? (_profile!.education.last['school'] ??
            _profile!.education.last['institution'])
        : null;
    final currentCompany = _profile!.experience.isNotEmpty
        ? (_profile!.experience.last['company'] ??
            _profile!.experience.last['title'])
        : null;
    final isOwnProfile =
        widget.userId == SupabaseService.getCurrentUserId();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              // ── Cover photo ──────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: const BackButton(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    'https://images.unsplash.com/photo-1506744038136-46273834b3fb'
                    '?q=80&w=2070&auto=format&fit=crop',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // ── White profile card ────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ── Content below avatar ──────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 56, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + Connect button row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _profile!.fullName,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _profile!.bio ??
                                            _profile!.domainId,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$_followerCount connections',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Right-side badges (company / school)
                                if (currentCompany != null ||
                                    latestSchool != null)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (currentCompany != null)
                                        _buildBadge(
                                            currentCompany, Icons.business),
                                      if (latestSchool != null) ...[
                                        const SizedBox(height: 10),
                                        _buildBadge(
                                            latestSchool, Icons.school),
                                      ],
                                    ],
                                  ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Connect / Following button
                            if (!isOwnProfile)
                              ElevatedButton.icon(
                                onPressed: _isFollowLoading
                                    ? null
                                    : _toggleFollow,
                                icon: Icon(
                                  _isFollowing
                                      ? Icons.check
                                      : Icons.person_add_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  _isFollowing ? 'Following' : 'Connect',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? Colors.white
                                      : Colors.blue,
                                  foregroundColor: _isFollowing
                                      ? Colors.blue
                                      : Colors.white,
                                  side: const BorderSide(color: Colors.blue),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(24)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // ── Overlapping avatar ────────────────────────────
                      Positioned(
                        top: -60,
                        left: 20,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundImage: _profile!.avatarUrl != null
                                ? NetworkImage(_profile!.avatarUrl!)
                                : null,
                            child: _profile!.avatarUrl == null
                                ? Text(
                                    _profile!.fullName[0].toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Divider ───────────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Divider(height: 1, thickness: 1),
              ),

              // ── Tab bar ───────────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Activity'),
                      Tab(text: 'About'),
                    ],
                  ),
                ),
              ),
            ];
          },

          // ── Tab content ────────────────────────────────────────────────
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildActivityTab(),
              _buildAboutTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 130),
          child: Text(
            text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab() {
    if (_userPosts.isEmpty) {
      return const Center(
          child: Text('No recent activity',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) => PostCard(post: _userPosts[index]),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_profile!.bio != null && _profile!.bio!.isNotEmpty) ...[
            const Text('Bio',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(_profile!.bio!,
                style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 24),
          ],
          if (_profile!.skills.isNotEmpty) ...[
            const Text('Skills',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _profile!.skills
                  .map((s) => Chip(
                        label: Text(s),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey[200]!),
                      ))
                  .toList(),
            ),
          ],
          if (_profile!.education.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Education',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            ..._profile!.education.map((edu) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              edu['school'] ??
                                  edu['institution'] ??
                                  'Institution',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            Text(
                              '${edu['degree'] ?? ''} • ${edu['field'] ?? ''}',
                              style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ── Sliver delegate for pinned tab bar ────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}
