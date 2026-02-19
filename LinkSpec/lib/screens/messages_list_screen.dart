import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'chat_screen.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({Key? key}) : super(key: key);

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    try {
      final convos = await SupabaseService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = convos;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching conversations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Messages', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue),
            onPressed: () {
              // TODO: Search for new people to message within domain
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchConversations,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _conversations.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message_outlined, size: 64, color: Colors.blue[100]),
                        const SizedBox(height: 16),
                        const Text('No messages yet',
                            style: TextStyle(color: Colors.black54, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Shared posts with colleagues will appear here',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = _conversations[index];
                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            backgroundImage: user['avatar_url'] != null
                                ? NetworkImage(user['avatar_url'])
                                : null,
                            child: user['avatar_url'] == null
                                ? Text(
                                    user['full_name'][0].toUpperCase(),
                                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          title: Text(user['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(user['domain_id'] ?? 'Team Member', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(otherUser: user),
                              ),
                            ).then((_) => _fetchConversations());
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
