import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'member_profile_screen.dart';
import '../widgets/clay_container.dart';

class NetworkScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  const NetworkScreen({Key? key, this.onBack, this.onSearch}) : super(key: key);

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  List<Map<String, dynamic>> _profiles = [];
  Set<String> _followingIds = {};
  Map<String, String> _connectStatuses = {}; // userId -> 'none'|'pending_sent'|'pending_received'|'connected'
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
      
      final myId = SupabaseService.getCurrentUserId();
      
      // Filter out self and collect other IDs
      final others = profiles.where((p) => p['id'] != myId).toList();
      final otherIds = others.map((p) => p['id'] as String).toList();

      if (otherIds.isEmpty) {
        setState(() {
          _profiles = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Batch check follow statuses and connection statuses
      // We do these in parallel for speed
      final results = await Future.wait([
        SupabaseService.getFollowStatuses(otherIds),
        SupabaseService.getConnectionStatuses(otherIds),
      ]);

      setState(() {
        _profiles = others;
        _followingIds = results[0] as Set<String>;
        _connectStatuses = results[1] as Map<String, String>;
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

  Future<void> _handleConnect(String targetUserId) async {
    final status = _connectStatuses[targetUserId] ?? 'none';
    try {
      if (status == 'none') {
        await SupabaseService.sendConnectRequest(targetUserId);
        setState(() => _connectStatuses[targetUserId] = 'pending_sent');
      } else if (status == 'pending_sent') {
        await SupabaseService.withdrawConnectRequest(targetUserId);
        setState(() => _connectStatuses[targetUserId] = 'none');
      } else if (status == 'pending_received') {
        await SupabaseService.acceptConnectRequest(targetUserId);
        setState(() => _connectStatuses[targetUserId] = 'connected');
      } else if (status == 'connected') {
        await SupabaseService.removeConnection(targetUserId);
        setState(() => _connectStatuses[targetUserId] = 'none');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text('My Network'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue),
            onPressed: widget.onSearch,
          ),
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
                    final connectStatus = _connectStatuses[targetId] ?? 'none';

                    // Determine Connect button appearance
                    final connectLabel = switch (connectStatus) {
                      'pending_sent' => 'Pending',
                      'pending_received' => 'Accept',
                      'connected' => 'Connected',
                      _ => 'Connect',
                    };
                    final connectIcon = switch (connectStatus) {
                      'pending_sent' => Icons.hourglass_top_rounded,
                      'pending_received' => Icons.check_circle_outline,
                      'connected' => Icons.people_alt_rounded,
                      _ => Icons.person_add_outlined,
                    };

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MemberProfileScreen(userId: targetId),
                          ),
                        );
                      },
                      child: ClayContainer(
                        color: Theme.of(context).cardTheme.color ?? const Color(0xFFB4DAFF),
                        borderRadius: 50,
                        depth: 10,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar + Name row
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.blue[50],
                                    backgroundImage: profile['avatar_url'] != null
                                        ? NetworkImage(profile['avatar_url'])
                                        : null,
                                    child: profile['avatar_url'] == null
                                        ? Text(profile['full_name'][0].toUpperCase(), style: const TextStyle(color: Colors.blue))
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile['full_name'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        Text(
                                          profile['domain_id'].toString().toUpperCase(),
                                          style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        if (profile['bio'] != null)
                                          Text(
                                            profile['bio'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Action buttons row
                              Row(
                                children: [
                                  // Connect button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _handleConnect(targetId),
                                      icon: Icon(connectIcon, size: 15),
                                      label: Text(connectLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: connectStatus == 'none'
                                            ? Colors.blue
                                            : connectStatus == 'pending_received'
                                                ? Colors.green
                                                : Colors.transparent,
                                        foregroundColor: (connectStatus == 'none' || connectStatus == 'pending_received')
                                            ? Colors.white
                                            : Colors.blue,
                                        side: BorderSide(
                                          color: connectStatus == 'pending_sent'
                                              ? Colors.grey
                                              : connectStatus == 'pending_received'
                                                  ? Colors.green
                                                  : Colors.blue,
                                          width: 1.5,
                                        ),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Follow button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _toggleFollow(targetId),
                                      icon: Icon(isFollowing ? Icons.notifications_active_outlined : Icons.add, size: 15),
                                      label: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: isFollowing ? Colors.blue.withOpacity(0.08) : Colors.transparent,
                                        foregroundColor: Colors.blue,
                                        side: const BorderSide(color: Colors.blue, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
