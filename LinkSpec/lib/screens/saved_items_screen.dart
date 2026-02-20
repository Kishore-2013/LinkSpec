import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';

/// In-memory store for saved post IDs (shared across the session).
/// Screens can call [SavedPostsStore.toggle] and [SavedPostsStore.isSaved].
class SavedPostsStore {
  SavedPostsStore._();
  static final Set<String> _savedIds = {};

  static bool isSaved(String postId) => _savedIds.contains(postId);

  static bool toggle(String postId) {
    if (_savedIds.contains(postId)) {
      _savedIds.remove(postId);
      return false; // now unsaved
    } else {
      _savedIds.add(postId);
      return true; // now saved
    }
  }

  static Set<String> get all => Set.unmodifiable(_savedIds);
}

/// Saved Items Screen — LinkedIn-style saved posts view.
class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({Key? key}) : super(key: key);

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  int _selectedSection = 0; // 0 = My items, 1 = Job tracker

  List<Post> _allPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    setState(() => _isLoading = true);
    try {
      // Load all domain posts, then filter to saved IDs
      final data = await SupabaseService.getPosts(limit: 100, offset: 0);
      final posts = data.map((d) => Post.fromJson(d)).toList();
      if (mounted) {
        setState(() {
          _allPosts =
              posts.where((p) => SavedPostsStore.isSaved(p.id)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Saved items',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left nav panel ──────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: 200,
                  child: Column(
                    children: [
                      _buildNavTile(
                        icon: Icons.bookmark,
                        label: 'My items',
                        index: 0,
                      ),
                      const Divider(height: 1),
                      _buildNavTile(
                        icon: Icons.work_outline,
                        label: 'Job tracker',
                        index: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Main content ─────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: _selectedSection == 0
                      ? _buildMyItems()
                      : _buildJobTracker(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool selected = _selectedSection == index;
    return InkWell(
      onTap: () => setState(() => _selectedSection = index),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withOpacity(0.08) : Colors.white,
          borderRadius: index == 0
              ? const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                )
              : const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.blue : Colors.grey[700],
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: selected ? Colors.blue : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyItems() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Text(
                  'Saved Posts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!_isLoading && _allPosts.isNotEmpty)
                  TextButton.icon(
                    onPressed: _loadSavedPosts,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
              ],
            ),
          ),

          // "All" filter pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0A66C2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'All',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_allPosts.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allPosts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PostCard(
                  post: _allPosts[i],
                  onPostDeleted: _loadSavedPosts,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          // Illustration
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFFF4F2EE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bookmark_border_rounded,
              size: 80,
              color: Color(0xFFB0BEC5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Start saving posts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved posts will show up here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0A66C2), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Go to Feed',
              style: TextStyle(
                color: Color(0xFF0A66C2),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildJobTracker() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Job Tracker',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Track jobs you\'ve applied to, saved, or are interested in.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.work_outline, size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  'No tracked jobs yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Jobs you save from the Jobs tab will appear here.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: Color(0xFF0A66C2), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Browse Jobs',
                    style: TextStyle(
                      color: Color(0xFF0A66C2),
                      fontWeight: FontWeight.bold,
                    ),
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
