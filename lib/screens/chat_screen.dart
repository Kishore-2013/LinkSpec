import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    SupabaseService.markMessagesAsRead(widget.otherUser['id']);
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
          _fetchMessages();
          if (msg['sender_id'] == widget.otherUser['id']) {
            SupabaseService.markMessagesAsRead(widget.otherUser['id']);
          }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
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
            Text(
              widget.otherUser['full_name'],
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background Illustration
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 80),
                  child: Opacity(
                    opacity: 0.4,
                    child: SvgPicture.asset(
                      'assets/svg/undraw_chatting_5u5z.svg',
                      width: 400,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Column(
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
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1A2740).withOpacity(0.05),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: PostCard(
                                  post: Post.fromJson(postData),
                                  backgroundColor: Colors.white.withOpacity(0.3),
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
                                color: isMe 
                                    ? Colors.blue.withOpacity(0.3) 
                                    : (Theme.of(context).cardTheme.color ?? Colors.white).withOpacity(0.3),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 16),
                                ),
                                boxShadow: [
                                  if (!isMe)
                                    BoxShadow(
                                      color: const Color(0xFF1A2740).withOpacity(0.03),
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
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              timeago.format(DateTime.parse(msg['created_at'])),
                              style: TextStyle(fontSize: 10, color: Colors.black.withOpacity(0.6)),
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
              color: Theme.of(context).cardTheme.color,
              boxShadow: [
                BoxShadow(
                   color: const Color(0xFF1A2740).withOpacity(0.05),
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
                      fillColor: Colors.grey[50],
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
        ],
      ),
    );
  }
}
