import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class SharePostDialog extends StatefulWidget {
  final String postId;

  const SharePostDialog({
    Key? key,
    required this.postId,
  }) : super(key: key);

  @override
  State<SharePostDialog> createState() => _SharePostDialogState();
}

class _SharePostDialogState extends State<SharePostDialog> {
  final _searchController = TextEditingController();
  final _commentController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _isSharing = false;
  // Multi-select: set of selected user IDs
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers([String? query]) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final users = await SupabaseService.getProfilesInSameDomain(
        searchQuery: query,
        limit: 20,
      );
      
      final myProfile = await SupabaseService.getCurrentUserProfile();
      final myId = myProfile?['id'];

      if (mounted) {
        setState(() {
          _users = users.where((u) => u['id'] != myId).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareWithSelected() async {
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one person to share with')),
      );
      return;
    }
    if (mounted) setState(() => _isSharing = true);
    int successCount = 0;
    final message = _commentController.text.trim().isNotEmpty
        ? _commentController.text.trim()
        : 'Shared a post with you';
    for (final userId in _selectedUserIds) {
      try {
        await SupabaseService.sendMessage(
          receiverId: userId,
          postId: widget.postId,
          content: message,
        );
        successCount++;
      } catch (e) {
        debugPrint('Failed to share with $userId: $e');
      }
    }
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successCount == _selectedUserIds.length
              ? 'Post shared with ${successCount} ${successCount == 1 ? "person" : "people"}!'
              : 'Shared with $successCount/${_selectedUserIds.length} people'),
          backgroundColor: Colors.blue[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Share Post',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a message (optional)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search colleagues...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _fetchUsers();
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) => _fetchUsers(value),
            ),
            if (_selectedUserIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_selectedUserIds.length} selected',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? const Center(child: Text('No users found in your domain'))
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final userId = user['id'] as String;
                            final isSelected = _selectedUserIds.contains(userId);
                            
                            return ListTile(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedUserIds.remove(userId);
                                  } else {
                                    _selectedUserIds.add(userId);
                                  }
                                });
                              },
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blue[50],
                                    backgroundImage: user['avatar_url'] != null
                                        ? NetworkImage(user['avatar_url'])
                                        : null,
                                    child: user['avatar_url'] == null
                                        ? Text(
                                            (user['full_name'] as String).isNotEmpty
                                                ? user['full_name'][0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                          )
                                        : null,
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 10),
                                      ),
                                    ),
                                ],
                              ),
                              title: Text(
                                user['full_name'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                user['domain_id'] ?? '',
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Colors.blue)
                                  : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSharing || _selectedUserIds.isEmpty ? null : _shareWithSelected,
                  icon: _isSharing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, size: 16),
                  label: Text(
                    _selectedUserIds.isEmpty
                        ? 'Share'
                        : 'Share with ${_selectedUserIds.length}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
