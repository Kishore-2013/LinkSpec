import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import 'chat_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/follow_provider.dart';
import '../providers/unite_provider.dart';


class MemberProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const MemberProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  ConsumerState<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends ConsumerState<MemberProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _profile;
  bool _isLoading = true;
  int _postCount = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  int _connectionsCount = 0;
  List<Post> _userPosts = [];
  bool _isUniteLoading = false;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfileData();
  }

  Future<void> _loadProfileData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    try {
      final profileData = await SupabaseService.getUserProfile(widget.userId);
      if (profileData != null) {
        _profile = UserProfile.fromJson(profileData);
        final stats = await SupabaseService.getConnectionCounts(widget.userId);
        if (mounted) {
          setState(() {
            _followerCount = stats['followers'] ?? 0;
            _followingCount = stats['following'] ?? 0;
          });
        }
        
        _postCount = await SupabaseService.getUserPostCount(widget.userId);
        final postsData =
            await SupabaseService.getPostsByUser(userId: widget.userId);
        if (mounted) {
          setState(() {
            _userPosts = postsData.map((d) => Post.fromJson(d)).toList();
          });
        }
        
        // Sync with providers
        final isFollowing = await SupabaseService.isFollowing(widget.userId);
        ref.read(followProvider.notifier).setFollowStatus(widget.userId, isFollowing);
        
        await ref.read(uniteProvider.notifier).loadStatus(widget.userId);
        final uCount = await SupabaseService.getUniteCount(widget.userId);
        if (mounted) {
          setState(() {
            _connectionsCount = uCount;
          });
        }
      }

    } catch (e) {
      debugPrint('Error loading member profile: $e');
    } finally {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final currentlyFollowing = ref.read(followProvider)[widget.userId] ?? false;
    try {
      await ref.read(followProvider.notifier).toggleFollow(widget.userId);
      // Update local count for UI immediate feedback
      setState(() {
        if (currentlyFollowing) {
          _followerCount--;
        } else {
          _followerCount++;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleUnite() async {
    final status = ref.read(uniteProvider)[widget.userId] ?? 'none';
    setState(() => _isUniteLoading = true);
    try {
      if (status == 'none') {
        await ref.read(uniteProvider.notifier).sendRequest(widget.userId);
      } else if (status == 'pending_sent') {
        await ref.read(uniteProvider.notifier).withdrawRequest(widget.userId);
      } else if (status == 'pending_received') {
        await ref.read(uniteProvider.notifier).acceptRequest(widget.userId);
        setState(() {
          _connectionsCount++;
        });
      } else if (status == 'connected') {
        if (_profile != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(otherUser: _profile!.toJson()),
            ),
          );
          // Refresh ALL profile state on return (silent background refresh)
          if (mounted) {
            await _loadProfileData(silent: true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUniteLoading = false);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Cover + Content Column
                    Column(
                      children: [
                        // Cover Photo
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            image: const DecorationImage(
                              image: NetworkImage(
                                'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=2070&auto=format&fit=crop',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // White Profile Card
                        Container(
                          color: Theme.of(context).cardTheme.color,
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                          _profile!.bio ?? 'Professional in ${_profile!.domainId.toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Theme.of(context).textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.business, size: 16, color: Colors.blue),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Industry: ${_profile!.domainId.toUpperCase()}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue[900],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            _buildStat(_connectionsCount, 'Unites', onTap: _showConnectionsDialog),
                                            const SizedBox(width: 24),
                                            _buildStat(_followerCount, 'Followers'),
                                            const SizedBox(width: 24),
                                            _buildStat(_followingCount, 'Following'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Right-side badges
                                  if (currentCompany != null || latestSchool != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (currentCompany != null)
                                          _buildBadge(currentCompany, Icons.business),
                                        if (latestSchool != null) ...[
                                          const SizedBox(height: 10),
                                          _buildBadge(latestSchool, Icons.school),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (!isOwnProfile)
                                Row(
                                  children: [
                                    _buildUniteButton(),
                                    const SizedBox(width: 10),
                                    _buildFollowButton(),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 2. Avatar (Layered over Cover and Card)
                    Positioned(
                      top: 140, // 200 cover height - 60 offset
                      left: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).cardTheme.color ?? Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 55,
                          backgroundColor: Colors.blue[50],
                          backgroundImage: _profile!.avatarUrl != null
                              ? NetworkImage(_profile!.avatarUrl!)
                              : null,
                          child: _profile!.avatarUrl == null
                              ? Text(
                                  _profile!.fullName[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                    ),
                    // 3. Floating Back Button
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.3),
                        child: const BackButton(color: Colors.white),
                      ),
                    ),
                  ],
                ),
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
                color: const Color(0xFF1A2740)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Unite button with four states:
  /// none → "Unite" (blue filled)
  /// pending_sent → "Pending" (grey outlined, tap to withdraw)
  /// pending_received → "Accept" (green filled)
  /// connected → "United ✓" (outlined blue)
  Widget _buildUniteButton() {
    final status = ref.watch(uniteProvider)[widget.userId] ?? 'none';
    final label = switch (status) {
      'pending_sent' => 'Pending',
      'pending_received' => 'Accept',
      'connected' => 'Message',
      _ => 'Unite',
    };
    final icon = switch (status) {
      'pending_sent' => Icons.hourglass_top_rounded,
      'pending_received' => Icons.check_circle_outline,
      'connected' => Icons.message_outlined,
      _ => Icons.person_add_outlined,
    };
    final bool isFilled = status == 'none' || status == 'pending_received';
    final Color bgColor = status == 'pending_received'
        ? Colors.green
        : status == 'none'
            ? Colors.blue
            : Colors.transparent;
    final Color fgColor = isFilled ? Colors.white : Colors.blue;

    if (_isUniteLoading) {
      return SizedBox(
        width: 100,
        height: 36,
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))),
      );
    }

    return OutlinedButton.icon(
      onPressed: _handleUnite,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        side: BorderSide(color: status == 'pending_sent' ? Colors.grey : Colors.blue, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }


  /// Follow button: one-way follow toggle
  Widget _buildFollowButton() {
    final isFollowing = ref.watch(followProvider)[widget.userId] ?? false;

    return OutlinedButton.icon(
      onPressed: _toggleFollow,
      icon: Icon(isFollowing ? Icons.notifications_active_outlined : Icons.add, size: 16),
      label: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        backgroundColor: isFollowing ? Colors.blue.withOpacity(0.08) : Colors.transparent,
        foregroundColor: Colors.blue,
        side: const BorderSide(color: Colors.blue, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
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

  Widget _buildStat(int count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w600)),
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
      color: Theme.of(context).cardTheme.color,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

extension on _MemberProfileScreenState {
  void _showConnectionsDialog() async {
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final connections = await SupabaseService.getAcceptedConnections(widget.userId);
    
    if (mounted) Navigator.pop(context); // Close loading

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('United'),
          content: connections.isEmpty
              ? const Text('No united people yet.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: connections.length,
                    itemBuilder: (context, index) {
                      final conn = connections[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: conn['avatar_url'] != null ? NetworkImage(conn['avatar_url']) : null,
                          child: conn['avatar_url'] == null ? Text(conn['full_name'][0].toUpperCase()) : null,
                        ),
                        title: Text(conn['full_name'] ?? 'Unknown'),
                        subtitle: Text(conn['domain_id'] ?? ''),
                        onTap: () {
                          if (conn['id'] == widget.userId) {
                             Navigator.pop(context);
                             return;
                          }
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MemberProfileScreen(userId: conn['id'])),
                          );
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    }
  }
}
