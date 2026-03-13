import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/supabase_service.dart';
import 'member_profile_screen.dart';
import 'chat_screen.dart';
import '../widgets/clay_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/follow_provider.dart';
import '../providers/unite_provider.dart';


class NetworkScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  const NetworkScreen({Key? key, this.onBack, this.onSearch}) : super(key: key);

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadNetwork();
  }

  Future<void> _loadNetwork() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // 1. Get other profiles in the same domain
      final profiles = await SupabaseService.getProfilesInSameDomain(limit: 50);
      
      final myId = SupabaseService.getCurrentUserId();
      
      // Filter out self and collect other IDs
      final others = profiles.where((p) => p['id'] != myId).toList();
      final otherIds = others.map((p) => p['id'] as String).toList();

      if (otherIds.isEmpty) {
        if (mounted) {
          setState(() {
            _profiles = [];
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Batch check follow statuses and connection statuses
      final results = await Future.wait([
        SupabaseService.getFollowStatuses(otherIds),
        SupabaseService.getConnectionStatuses(otherIds),
      ]);

      // Update follow provider for all profiles shown
      final followResults = results[0] as Set<String>;
      final followNotifier = ref.read(followProvider.notifier);
      for (var id in otherIds) {
        followNotifier.setFollowStatus(id, followResults.contains(id));
      }

      if (mounted) {
        final uniteResults = results[1] as Map<String, String>;
        final uniteNotifier = ref.read(uniteProvider.notifier);
        uniteResults.forEach((id, status) {
          uniteNotifier.setUniteStatus(id, status);
        });

        setState(() {
          _profiles = others;
        });
      }

    } catch (e) {
      print('Error loading network: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    try {
      await ref.read(followProvider.notifier).toggleFollow(targetUserId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleUnite(Map<String, dynamic> profile) async {
    final targetUserId = profile['id'];
    final status = ref.read(uniteProvider)[targetUserId] ?? 'none';
    try {
      if (status == 'none') {
        await ref.read(uniteProvider.notifier).sendRequest(targetUserId);
      } else if (status == 'pending_sent') {
        await ref.read(uniteProvider.notifier).withdrawRequest(targetUserId);
      } else if (status == 'pending_received') {
        await ref.read(uniteProvider.notifier).acceptRequest(targetUserId);
      } else if (status == 'connected') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(otherUser: profile),
          ),
        );
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
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Opacity(
                    opacity: 0.4,
                    child: SvgPicture.asset(
                      'assets/svg/undraw_followers_m4z4.svg',
                      width: 550,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _isLoading
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
                    final followMap = ref.watch(followProvider);
                    final isFollowing = followMap[targetId] ?? false;
                    final connectStatus = ref.watch(uniteProvider)[targetId] ?? 'none';


                    // Determine Connect button appearance
                    final connectLabel = switch (connectStatus) {
                      'pending_sent' => 'Pending',
                      'pending_received' => 'Accept',
                      'connected' => 'Message',
                      _ => 'Unite',
                    };
                    final connectIcon = switch (connectStatus) {
                      'pending_sent' => Icons.hourglass_top_rounded,
                      'pending_received' => Icons.check_circle_outline,
                      'connected' => Icons.message_outlined,
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
                        borderRadius: 14,
                        depth: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                                        ? Text(
                                            (profile['full_name'] != null && profile['full_name'].toString().isNotEmpty)
                                                ? profile['full_name'][0].toUpperCase()
                                                : '?', 
                                            style: const TextStyle(color: Colors.blue)
                                          )
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
                                      onPressed: () => _handleUnite(profile),
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
        ],
      ),
    );
  }
}
