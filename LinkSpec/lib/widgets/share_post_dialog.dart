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
  final _commentController = TextEditingController(); // Added comment field
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  String? _selectedUserId;

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
    setState(() => _isLoading = true);
    try {
      final users = await SupabaseService.getProfilesInSameDomain(
        searchQuery: query,
        limit: 10,
      );
      
      final myProfile = await SupabaseService.getCurrentUserProfile();
      final myId = myProfile?['id'];

      setState(() {
        _users = users.where((u) => u['id'] != myId).toList();
      });
    } catch (e) {
      print('Error fetching users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareWithUser(String receiverId) async {
    setState(() => _selectedUserId = receiverId);
    try {
      await SupabaseService.sendMessage(
        receiverId: receiverId,
        postId: widget.postId,
        content: _commentController.text.trim().isNotEmpty 
          ? _commentController.text.trim() 
          : 'Shared a post with you',
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared successfully via Chat!'),
            backgroundColor: Colors.blue[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _selectedUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share with a Colleague',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? const Center(child: Text('No users found in your domain'))
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final isSharing = _selectedUserId == user['id'];
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[50],
                                backgroundImage: user['avatar_url'] != null
                                    ? NetworkImage(user['avatar_url'])
                                    : null,
                                child: user['avatar_url'] == null
                                    ? Text(user['full_name'][0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                              title: Text(user['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(user['domain_id'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                              trailing: isSharing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _shareWithUser(user['id']),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        minimumSize: const Size(60, 30),
                                        elevation: 0,
                                      ),
                                      child: const Text('Share'),
                                    ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
