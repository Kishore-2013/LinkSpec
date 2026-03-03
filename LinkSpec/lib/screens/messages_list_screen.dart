import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/supabase_service.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onSearch;
  const MessagesListScreen({Key? key, this.onBack, this.onSearch})
      : super(key: key);

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  // All users fetched from the directory (no domain filter)
  List<Map<String, dynamic>> _allUsers = [];
  // IDs of users we already have a conversation thread with (green dot)
  Set<String> _existingConversationIds = {};
  // IDs of users who have sent us at least one unread message (blue bubble)
  Set<String> _hasUnreadFrom = {};

  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Don't blanket-mark-all-as-read here — that would clear bubbles before
    // the user actually opens each individual chat.
    _loadData();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
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
      // Fetch all three datasets in parallel
      final results = await Future.wait([
        SupabaseService.getAllProfiles(limit: 200),
        SupabaseService.getConversations(),
        SupabaseService.getUnreadSenderIds(),
      ]);

      final allUsers   = results[0] as List<Map<String, dynamic>>;
      final convos     = results[1] as List<Map<String, dynamic>>;
      final unreadFrom = results[2] as Set<String>;

      if (mounted) {
        setState(() {
          _allUsers = allUsers;
          _existingConversationIds = convos.map((u) => u['id'] as String).toSet();
          _hasUnreadFrom = unreadFrom;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading messaging directory: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Filtered list based on the search query
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
    // Sort: existing conversations first, then alphabetically
    filtered.sort((a, b) {
      final aHas = _existingConversationIds.contains(a['id']) ? 0 : 1;
      final bHas = _existingConversationIds.contains(b['id']) ? 0 : 1;
      if (aHas != bHas) return aHas.compareTo(bHas);
      return (a['full_name'] as String).compareTo(b['full_name'] as String);
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.blue),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Illustration
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Opacity(
                    opacity: 0.25,
                    child: SvgPicture.asset(
                      'assets/svg/undraw_text-messages_978a.svg',
                      width: 450,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Column(
            children: [
              // ── Search bar ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search people...',
                      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.blue, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              // ── User list ─────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? _buildEmpty()
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _buildUserTile(filtered[index]),
                            ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final userId         = user['id'] as String;
    final hasConversation = _existingConversationIds.contains(userId);
    final hasUnread      = _hasUnreadFrom.contains(userId);  // drives the blue bubble
    final name           = user['full_name'] as String? ?? 'Unknown';
    final domain         = user['domain_id'] as String? ?? '';
    final avatarUrl      = user['avatar_url'] as String?;

    return Card(
      color: (Theme.of(context).cardTheme.color ?? Colors.white).withOpacity(0.85),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          // Highlight card border only when there are actually unread messages
          color: hasUnread
              ? Colors.blue.withOpacity(0.35)
              : Colors.grey.withOpacity(0.1),
          width: hasUnread ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue[50],
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18),
                    )
                  : null,
            ),
            // Green dot = has prior conversation thread
            if (hasConversation)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          domain.isNotEmpty ? domain.toUpperCase() : 'Member',
          style: TextStyle(
            color: Colors.blue[700],
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        // Blue bubble = unread messages from this user.
        // Grey arrow   = prior conversation but all read, or no chat yet.
        trailing: hasUnread
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 14),
              )
            : const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        onTap: () {
          // Optimistically clear the bubble before navigating so the UI updates
          // instantly — no need to wait for the DB round-trip.
          if (hasUnread) {
            setState(() => _hasUnreadFrom.remove(userId));
            // Fire-and-forget — ChatScreen.initState() will also call this
            SupabaseService.markMessagesAsRead(userId);
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(otherUser: user),
            ),
          ).then((_) => _loadData()); // full refresh on return confirms the DB state
        },
      ),
    );
  }

  Widget _buildEmpty() {
    final hasQuery = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.people_outline_rounded,
              size: 64,
              color: Colors.blue[100],
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No users match "$_searchQuery"' : 'No users found',
              style: const TextStyle(
                  color: Color(0xFF1A2740),
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 8),
              const Text(
                'Registered users will appear here',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
