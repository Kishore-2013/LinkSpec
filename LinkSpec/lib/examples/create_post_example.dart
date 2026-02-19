import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================================
/// CREATE POST - AUTOMATIC DOMAIN ASSIGNMENT EXAMPLE
/// ============================================================================
/// 
/// This file demonstrates how posts are created with automatic domain_id
/// assignment. The domain_id is fetched and attached by a PostgreSQL trigger,
/// so the Flutter code doesn't need to handle it manually.
/// 
/// ============================================================================

class CreatePostExample {
  static final SupabaseClient _client = Supabase.instance.client;

  /// ========================================================================
  /// THE ACTUAL IMPLEMENTATION (from lib/services/supabase_service.dart)
  /// ========================================================================
  /// 
  /// This is the REAL function used in your app. Notice:
  /// 1. We only provide 'author_id' and 'content'
  /// 2. We do NOT fetch or set 'domain_id'
  /// 3. The database trigger automatically sets it
  /// 
  static Future<Map<String, dynamic>> createPost({
    required String content,
  }) async {
    // Step 1: Get current user's ID from Supabase Auth
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Step 2: Insert post with ONLY author_id and content
    // The domain_id will be automatically set by the database trigger!
    final response = await _client
        .from('posts')
        .insert({
          'author_id': userId,  // ← Current user's ID
          'content': content,   // ← Post content
          // domain_id is NOT provided here! ✨
          // The database trigger will:
          // 1. Look up the author's profile
          // 2. Get their domain_id
          // 3. Set it on this post
        })
        .select()  // Return the created post
        .single(); // Get single object (not array)

    // Step 3: Return the created post
    // The response will include the auto-set domain_id!
    return response;
    
    // Example response:
    // {
    //   "id": "550e8400-e29b-41d4-a716-446655440000",
    //   "author_id": "123e4567-e89b-12d3-a456-426614174000",
    //   "content": "Hello, Medical professionals!",
    //   "domain_id": "Medical",  ← Auto-set by trigger!
    //   "created_at": "2026-02-17T21:00:00.000Z",
    //   "updated_at": "2026-02-17T21:00:00.000Z"
    // }
  }

  /// ========================================================================
  /// ALTERNATIVE: MANUAL APPROACH (NOT RECOMMENDED)
  /// ========================================================================
  /// 
  /// This shows how you COULD manually fetch the domain_id, but we DON'T
  /// do this because:
  /// - It requires 2 database queries instead of 1
  /// - It's slower
  /// - It's more code to maintain
  /// - The trigger approach is more reliable
  /// 
  static Future<Map<String, dynamic>> createPostManualApproach({
    required String content,
  }) async {
    final userId = _client.auth.currentUser?.id;
    
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // ❌ EXTRA QUERY: Fetch user's profile to get domain_id
    final profile = await _client
        .from('profiles')
        .select('domain_id')
        .eq('id', userId)
        .single();
    
    final domainId = profile['domain_id'];

    // Insert post with manually fetched domain_id
    final response = await _client
        .from('posts')
        .insert({
          'author_id': userId,
          'content': content,
          'domain_id': domainId,  // ← Manually set
        })
        .select()
        .single();

    return response;
  }

  /// ========================================================================
  /// THE DATABASE TRIGGER (from supabase_schema.sql)
  /// ========================================================================
  /// 
  /// This is the PostgreSQL trigger that automatically sets domain_id.
  /// It runs BEFORE INSERT on the posts table.
  /// 
  /// ```sql
  /// CREATE OR REPLACE FUNCTION set_post_domain()
  /// RETURNS TRIGGER AS $$
  /// BEGIN
  ///   -- Fetch the author's domain_id from their profile
  ///   NEW.domain_id := (SELECT domain_id FROM profiles WHERE id = NEW.author_id);
  ///   RETURN NEW;
  /// END;
  /// $$ LANGUAGE plpgsql SECURITY DEFINER;
  /// 
  /// CREATE TRIGGER trigger_set_post_domain
  ///   BEFORE INSERT ON posts
  ///   FOR EACH ROW
  ///   EXECUTE FUNCTION set_post_domain();
  /// ```
  /// 
  /// How it works:
  /// 1. You insert a post with only author_id and content
  /// 2. BEFORE the INSERT completes, the trigger fires
  /// 3. The trigger looks up the author's profile
  /// 4. It gets their domain_id
  /// 5. It sets NEW.domain_id to that value
  /// 6. The INSERT completes with domain_id populated
  /// 

  /// ========================================================================
  /// USAGE EXAMPLE IN UI
  /// ========================================================================
  /// 
  static Future<void> exampleUsage(BuildContext context) async {
    try {
      // User types "Looking for cardiology advice" in the UI
      final content = "Looking for cardiology advice";

      // Call createPost - domain_id is auto-attached!
      final createdPost = await createPost(content: content);

      // The returned post has domain_id automatically set
      print('Created post ID: ${createdPost['id']}');
      print('Content: ${createdPost['content']}');
      print('Domain ID: ${createdPost['domain_id']}');  // ← Auto-set!
      print('Author ID: ${createdPost['author_id']}');

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Handle errors
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ========================================================================
  /// TESTING THE AUTOMATIC DOMAIN ASSIGNMENT
  /// ========================================================================
  /// 
  static Future<void> testDomainAssignment() async {
    // Scenario: User is in "Medical" domain
    
    // 1. Create a post
    final post = await createPost(
      content: "Test post for domain assignment",
    );

    // 2. Verify domain_id was set correctly
    assert(post['domain_id'] != null, 'domain_id should be set');
    print('✅ domain_id was automatically set: ${post['domain_id']}');

    // 3. Verify it matches the user's profile domain
    final userId = _client.auth.currentUser?.id;
    final profile = await _client
        .from('profiles')
        .select('domain_id')
        .eq('id', userId!)
        .single();
    
    assert(
      post['domain_id'] == profile['domain_id'],
      'Post domain_id should match user profile domain_id',
    );
    print('✅ domain_id matches user profile: ${profile['domain_id']}');

    // 4. Verify RLS allows the insert
    // (If RLS blocked it, we would have gotten an error above)
    print('✅ RLS policy allowed the insert');

    print('\n🎉 All tests passed! Automatic domain assignment works!');
  }

  /// ========================================================================
  /// DATA FLOW VISUALIZATION
  /// ========================================================================
  /// 
  /// User clicks "Post" button
  ///     ↓
  /// Flutter: createPost(content: "Hello!")
  ///     ↓
  /// Supabase Client: INSERT INTO posts (author_id, content)
  ///     ↓
  /// PostgreSQL: BEFORE INSERT trigger fires
  ///     ↓
  /// Trigger: SELECT domain_id FROM profiles WHERE id = author_id
  ///     ↓
  /// Trigger: SET NEW.domain_id = fetched_domain_id
  ///     ↓
  /// PostgreSQL: RLS validates domain_id matches user's domain
  ///     ↓
  /// PostgreSQL: INSERT completes with domain_id populated
  ///     ↓
  /// Supabase: Returns created post to Flutter
  ///     ↓
  /// Flutter: Shows success message, refreshes feed
  /// 
}

/// ============================================================================
/// COMPLETE WIDGET EXAMPLE
/// ============================================================================

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// This is the function that creates the post
  /// Notice: We only pass the content, domain_id is auto-attached!
  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call createPost - domain_id is automatically fetched and attached!
      final createdPost = await CreatePostExample.createPost(
        content: _contentController.text.trim(),
      );

      if (mounted) {
        // Success! The post was created with domain_id auto-set
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Post created in ${createdPost['domain_id']} domain!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Clear the form and go back
        _contentController.clear();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info banner explaining automatic domain assignment
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your post will be visible only to users in your domain',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Content input
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'What\'s on your mind?',
                  hintText: 'Share your thoughts...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                maxLength: 500,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter some content';
                  }
                  if (value.trim().length < 3) {
                    return 'Post must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Post',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// KEY TAKEAWAYS
/// ============================================================================
/// 
/// 1. ✅ You DON'T need to manually fetch the user's domain_id
/// 2. ✅ The database trigger automatically sets it
/// 3. ✅ This is faster (1 query instead of 2)
/// 4. ✅ This is safer (impossible to set wrong domain)
/// 5. ✅ This is simpler (less code to maintain)
/// 6. ✅ The RLS policy validates the trigger's output
/// 7. ✅ Even if someone bypasses the app, the trigger still works
/// 
/// The function you asked for is:
/// 
/// ```dart
/// static Future<Map<String, dynamic>> createPost({
///   required String content,
/// }) async {
///   final userId = _client.auth.currentUser?.id;
///   
///   if (userId == null) {
///     throw Exception('User not authenticated');
///   }
/// 
///   final response = await _client
///       .from('posts')
///       .insert({
///         'author_id': userId,
///         'content': content,
///         // domain_id is automatically fetched and attached by trigger!
///       })
///       .select()
///       .single();
/// 
///   return response;
/// }
/// ```
/// 
/// ============================================================================
