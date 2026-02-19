import 'package:flutter/material.dart';
import '../widgets/create_post_dialog.dart';

class PostCreateScreen extends StatelessWidget {
  final VoidCallback onPostCreated;

  const PostCreateScreen({
    Key? key,
    required this.onPostCreated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // We can reuse the content of the dialog but without the dialog wrapper
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Post')),
      body: CreatePostDialog(
        onPostCreated: onPostCreated,
        isFullScreen: true, // I'll update the widget to handle this
      ),
    );
  }
}

