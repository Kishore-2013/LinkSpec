import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';
import '../providers/domain_provider.dart';
import '../providers/scroll_provider.dart';
import 'chat_screen.dart';

class MessagesListScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final ScrollController? scrollController;
  const MessagesListScreen({Key? key, this.onBack, this.scrollController}) : super(key: key);

  @override
  ConsumerState<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _existingConversationUserIds = {};
  final Set<String> _hasUnreadFrom = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final activeDomain = ref.read(currentDomainProvider);
      
      final results = await Future.wait([
        SupabaseService.getAllProfiles(limit: 100),
        SupabaseService.getConversations(),
        SupabaseService.getUnreadSenderIds(),
      ]);

      if (mounted) {
        setState(() {
          _profiles = results[0] as List<Map<String, dynamic>>;
          
          final existingChats = results[1] as List<Map<String, dynamic>>;
          _existingConversationUserIds.clear();
          for (var chat in existingChats) {
            if (chat['id'] != null) _existingConversationUserIds.add(chat['id'] as String);
          }
          
          _hasUnreadFrom.clear();
          _hasUnreadFrom.addAll(results[2] as Set<String>);
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('MessagesListScreen: Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _profiles;
    return _profiles.where((u) {
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      final domain = (u['domain_id'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || 
             domain.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;
    
    filtered.sort((a, b) {
      final aId = a['id'] as String? ?? '';
      final bId = b['id'] as String? ?? '';
      
      final aHas = _existingConversationUserIds.contains(aId) ? 0 : 1;
      final bHas = _existingConversationUserIds.contains(bId) ? 0 : 1;
      
      if (aHas != bHas) return aHas.compareTo(bHas);
      
      return (a['full_name'] ?? '').toString().toLowerCase().compareTo(
        (b['full_name'] ?? '').toString().toLowerCase()
      );
    });

    // ✅ CLEAN SCAFFOLD - NO GREY OVERLAY
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => context.go('/home'),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 20,
            color: Colors.black, // Fully visible, no opacity
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.blue), 
            onPressed: _loadData,
          ),
        ],
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search Bar - Clean with no overlay
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50, 
                borderRadius: BorderRadius.circular(14), 
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search people...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, color: Colors.blue, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Colors.grey), 
                          onPressed: () => _searchController.clear(),
                        ) 
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          // User List - NO OVERLAY, FULLY VISIBLE
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? _buildEmpty()
                      : ListView.separated(
                          controller: widget.scrollController ?? ref.read(globalScrollControllerProvider),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), // Reduced bottom padding
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildUserTile(filtered[index]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    final hasUnread = _hasUnreadFrom.contains(userId);
    final name = user['full_name'] as String? ?? 'User';
    final domain = user['domain_id'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;

    // ✅ CLEAN TILE - NO OVERLAY, FULL OPACITY
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Clean white background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05), // Very subtle shadow, not overlay
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: hasUnread ? Colors.blue.withOpacity(0.5) : Colors.grey.withOpacity(0.1), 
          width: hasUnread ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.blue.shade50,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) 
              ? NetworkImage(avatarUrl) 
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty) 
              ? Text(
                  name[0].toUpperCase(), 
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ) 
              : null,
        ),
        title: Text(
          name, 
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600, 
            fontSize: 15,
            color: Colors.black, // ✅ Fully opaque, fully visible
            letterSpacing: -0.2,
          ),
        ),
        subtitle: Text(
          domain.toUpperCase(), 
          style: const TextStyle(
            color: Colors.blue, 
            fontSize: 11, 
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        trailing: hasUnread 
            ? Container(
                padding: const EdgeInsets.all(5), 
                decoration: const BoxDecoration(
                  color: Colors.blue, 
                  shape: BoxShape.circle,
                ), 
                child: const Icon(
                  Icons.mark_chat_unread_rounded, 
                  color: Colors.white, 
                  size: 12,
                ),
              )
            : Icon(
                Icons.chevron_right, 
                color: Colors.grey.shade400, 
                size: 20,
              ),
        onTap: () {
          if (hasUnread) {
            setState(() => _hasUnreadFrom.remove(userId));
            SupabaseService.markMessagesAsRead(userId);
          }
          Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => ChatScreen(otherUser: user))
          ).then((_) => _loadData());
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded, 
            size: 64, 
            color: Colors.blue.shade100,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No users match "$_searchQuery"' : 'No users found', 
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              'Start a conversation by tapping on any user',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }
}