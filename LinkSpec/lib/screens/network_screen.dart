import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'member_profile_screen.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({Key? key}) : super(key: key);

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  List<Map<String, dynamic>> _profiles = [];
  Set<String> _followingIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNetwork();
  }

  Future<void> _loadNetwork() async {
    setState(() => _isLoading = true);
    try {
      // 1. Get other profiles in the same domain
      final profiles = await SupabaseService.getProfilesInSameDomain(limit: 50);
      
      // 2. Identify who we are already following
      final myProfile = await SupabaseService.getCurrentUserProfile();
      final myId = myProfile?['id'];
      
      // Filter out self
      final others = profiles.where((p) => p['id'] != myId).toList();

      // 3. Check follow status for each (could be optimized, but ok for now)
      final followingSet = <String>{};
      for (var p in others) {
        final isFollowing = await SupabaseService.isFollowing(p['id']);
        if (isFollowing) followingSet.add(p['id']);
      }

      setState(() {
        _profiles = others;
        _followingIds = followingSet;
      });
    } catch (e) {
      print('Error loading network: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final isFollowing = _followingIds.contains(targetUserId);
    try {
      if (isFollowing) {
        await SupabaseService.unfollowUser(targetUserId);
        setState(() => _followingIds.remove(targetUserId));
      } else {
        await SupabaseService.followUser(targetUserId);
        setState(() => _followingIds.add(targetUserId));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Network', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadNetwork,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(
                  child: Text('No other professionals found in your domain yet.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _profiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    final targetId = profile['id'];
                    final isFollowing = _followingIds.contains(targetId);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MemberProfileScreen(userId: targetId),
                          ),
                        );
                      },
                      child: Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.blue[50],
                            backgroundImage: profile['avatar_url'] != null
                                ? NetworkImage(profile['avatar_url'])
                                : null,
                            child: profile['avatar_url'] == null
                                ? Text(profile['full_name'][0].toUpperCase(), style: const TextStyle(color: Colors.blue))
                                : null,
                          ),
                          title: Text(
                            profile['full_name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile['domain_id'].toString().toUpperCase(),
                                  style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                              if (profile['bio'] != null)
                                Text(
                                  profile['bio'],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _toggleFollow(targetId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? Colors.grey[200] : Colors.blue,
                              foregroundColor: isFollowing ? Colors.black87 : Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text(isFollowing ? 'Following' : 'Connect'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
