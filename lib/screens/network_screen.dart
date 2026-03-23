import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/supabase_service.dart';
import '../services/linkspec_notify.dart';
import 'member_profile_screen.dart';
import 'chat_screen.dart';
import '../widgets/clay_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/follow_provider.dart';
import '../providers/unite_provider.dart';
import '../providers/domain_provider.dart';
import '../providers/scroll_provider.dart';
import 'package:go_router/go_router.dart';

class NetworkScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final ScrollController? scrollController;
  const NetworkScreen({Key? key, this.onBack, this.onSearch, this.scrollController}) : super(key: key);

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String? _lastDomain; 
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ref.read(globalScrollControllerProvider);
    _loadNetwork();
  }

  Future<void> _loadNetwork() async {
    final activeDomain = ref.read(currentDomainProvider);
    if (mounted) {
      setState(() {
        _isLoading = true;
        _profiles = [];
      });
    }
    try {
      final profiles = await SupabaseService.getProfilesInSameDomain(
        limit: 50,
        domain: activeDomain,
      );
      
      final myId = SupabaseService.getCurrentUserId();
      final others = profiles.where((p) => p['id'] != myId).toList();
      final otherIds = others.map((p) => p['id'] as String).toList();

      if (otherIds.isEmpty) {
        if (mounted) setState(() { _profiles = []; _isLoading = false; });
        return;
      }

      final results = await Future.wait([
        SupabaseService.getFollowStatuses(otherIds),
        SupabaseService.getConnectionStatuses(otherIds),
      ]);

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
        setState(() { _profiles = others; });
      }
    } catch (e) {
      debugPrint('Error loading network: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    try {
      await ref.read(followProvider.notifier).toggleFollow(targetUserId);
    } catch (e) {
      if (mounted) LinkSpecNotify.show(context, 'Action failed: $e', LinkSpecNotifyType.error);
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
        context.push('/messages'); // Simplified for now
      }
    } catch (e) {
      if (mounted) LinkSpecNotify.show(context, 'Action failed: $e', LinkSpecNotifyType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeDomain = ref.watch(currentDomainProvider);

    if (_lastDomain != activeDomain) {
      final oldDomain = _lastDomain;
      _lastDomain = activeDomain;
      if (oldDomain != null) {
        Future.microtask(() => _loadNetwork());
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
                onPressed: widget.onBack ?? () => context.go('/home'),
              ),
              const Text('My Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh, color: Colors.blue), onPressed: _loadNetwork),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Opacity(
                        opacity: 0.1,
                        child: SvgPicture.asset('assets/svg/undraw_followers_m4z4.svg', width: 400),
                      ),
                    ),
                  ),
                ),
              ),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _profiles.isEmpty
                      ? const Center(child: Text('No other professionals found in your domain yet.'))
                      : GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 2 : 1,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: _profiles.length,
                          itemBuilder: (context, index) {
                            final profile = _profiles[index];
                            final targetId = profile['id'];
                            final isFollowing = ref.watch(followProvider)[targetId] ?? false;
                            final connectStatus = ref.watch(uniteProvider)[targetId] ?? 'none';

                            final connectLabel = switch (connectStatus) {
                              'pending_sent' => 'Pending',
                              'pending_received' => 'Accept',
                              'connected' => 'Message',
                              _ => 'Unite',
                            };

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                                        child: profile['avatar_url'] == null ? Text(profile['full_name'][0].toUpperCase()) : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(profile['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            Text(profile['domain_id'].toString().toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _handleUnite(profile),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: connectStatus == 'none' ? Colors.blue : Colors.blue.withOpacity(0.1),
                                            foregroundColor: connectStatus == 'none' ? Colors.white : Colors.blue,
                                            elevation: 0,
                                          ),
                                          child: Text(connectLabel),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => _toggleFollow(targetId),
                                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.blue)),
                                          child: Text(isFollowing ? 'Following' : 'Follow'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ],
    );
  }
}
