import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../models/post.dart';
import 'package:timeago/timeago.dart' as timeago;

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> otherUser;

  const ChatScreen({
    Key? key,
    required this.otherUser,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;
  final String _myId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _subscription?.unsubscribe();
    super.dispose();
  }

  void _setupSubscription() {
    _subscription = SupabaseService.subscribeToMessages(
      onNewMessage: (msg) {
        if ((msg['sender_id'] == widget.otherUser['id'] && msg['receiver_id'] == _myId) ||
            (msg['sender_id'] == _myId && msg['receiver_id'] == widget.otherUser['id'])) {
          _fetchMessages(); // Refresh for now, or just add the message if data is complete
        }
      },
    );
  }

  Future<void> _fetchMessages() async {
    try {
      final messages = await SupabaseService.getMessages(widget.otherUser['id']);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    try {
      await SupabaseService.sendMessage(
        receiverId: widget.otherUser['id'],
        content: text,
      );
      _fetchMessages();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
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
        iconTheme: const IconThemeData(color: Colors.black),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[50],
              backgroundImage: widget.otherUser['avatar_url'] != null
                  ? NetworkImage(widget.otherUser['avatar_url'])
                  : null,
              child: widget.otherUser['avatar_url'] == null
                  ? Text(widget.otherUser['full_name'][0].toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.otherUser['full_name'], style: const TextStyle(color: Colors.black, fontSize: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['sender_id'] == _myId;
                      final postData = msg['posts'];
                      
                      return Column(
                        crossAxisAlignment:
                            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (postData != null) ...[
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: PostCard(
                                  post: Post.fromJson(postData),
                                ),
                              ),
                            ),
                          ],
                          if (msg['content'] != null && msg['content'].toString().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 16),
                                ),
                                boxShadow: [
                                  if (!isMe)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Text(
                                msg['content'],
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              timeago.format(DateTime.parse(msg['created_at'])),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
