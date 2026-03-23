import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'chat_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/scroll_provider.dart';
import 'package:go_router/go_router.dart';

class MessagesListScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  final ScrollController? scrollController;
  const MessagesListScreen({Key? key, this.onBack, this.onSearch, this.scrollController})
      : super(key: key);

  @override
  ConsumerState<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
  List<Map<String, dynamic>> _allUsers = [];
  Set<String> _existingConversationIds = {};
  Set<String> _hasUnreadFrom = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _setupSubscription();
  }

  void _setupSubscription() {
    _subscription = SupabaseService.subscribeToMessages(
      onNewMessage: (msg) {
        if (mounted) _loadData();
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getAllProfiles(limit: 200),
        SupabaseService.getConversations(),
        SupabaseService.getUnreadSenderIds(),
      ]);

      if (mounted) {
        setState(() {
          _allUsers = results[0] as List<Map<String, dynamic>>;
          _existingConversationIds = (results[1] as List<Map<String, dynamic>>).map((u) => u['id'] as String).toSet();
          _hasUnreadFrom = results[2] as Set<String>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _allUsers;
    return _allUsers.where((u) {
      final name = (u['full_name'] as String? ?? '').toLowerCase();
      final domain = (u['domain_id'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery) || domain.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    filtered.sort((a, b) {
      final aId = a['id'] as String? ?? '';
      final bId = b['id'] as String? ?? '';
      final aHas = _existingConversationIds.contains(aId) ? 0 : 1;
      final bHas = _existingConversationIds.contains(bId) ? 0 : 1;
      if (aHas != bHas) return aHas.compareTo(bHas);
      return (a['full_name'] ?? '').toString().toLowerCase().compareTo((b['full_name'] ?? '').toString().toLowerCase());
    });

    return Container(
      color: Colors.white,
      child: Column(
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
              const Text('Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.blue), onPressed: _loadData),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey[200]!)),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search people...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue, size: 20),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchController.clear()) : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.separated(
                        controller: widget.scrollController ?? ref.read(globalScrollControllerProvider),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _buildUserTile(filtered[index]),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final hasUnread = _hasUnreadFrom.contains(userId);
    final name = user['full_name'] as String? ?? 'User';
    final domain = user['domain_id'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasUnread ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.1), width: hasUnread ? 1.5 : 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
          child: (avatarUrl == null || avatarUrl.isEmpty) ? Text(name[0].toUpperCase()) : null,
        ),
        title: Text(name, style: TextStyle(fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700, fontSize: 15)),
        subtitle: Text(domain.toUpperCase(), style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
        trailing: hasUnread 
            ? Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 12))
            : const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: () {
          if (hasUnread) {
            setState(() => _hasUnreadFrom.remove(userId));
            SupabaseService.markMessagesAsRead(userId);
          }
          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(otherUser: user))).then((_) => _loadData());
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: Colors.blue[100]),
          const SizedBox(height: 16),
          Text(_searchQuery.isNotEmpty ? 'No users match "$_searchQuery"' : 'No users found', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
