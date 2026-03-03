import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../providers/saved_posts_provider.dart';

/// Saved Items Screen — LinkedIn-style saved posts view.
class SavedItemsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const SavedItemsScreen({Key? key, this.onBack}) : super(key: key);

  @override
  ConsumerState<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends ConsumerState<SavedItemsScreen> {
  int _selectedSection = 0; // 0 = My items, 1 = Job tracker

  List<Post> _allPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload when the screen becomes active/visible (e.g., navigated back to)
    if (!_isLoading) {
      _loadSavedPosts();
    }
  }

  Future<void> _loadSavedPosts() async {
    setState(() => _isLoading = true);
    try {
      final savedIds = ref.read(savedPostsProvider).toList();
      if (savedIds.isEmpty) {
        setState(() {
          _allPosts = [];
          _isLoading = false;
        });
        return;
      }

      // Load ONLY the posts we've saved — much faster
      final data = await SupabaseService.getPostsByIds(savedIds);
      final posts = data.map((d) => Post.fromJson(d)).toList();
      
      if (mounted) {
        setState(() {
          _allPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading saved posts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 700;
    
    // Listen for changes in saved posts set to reload the list dynamically
    ref.listen(savedPostsProvider, (previous, next) {
      if (previous?.length != next.length) {
        _loadSavedPosts();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Saved items',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 16 : 18,
          ),
        ),
        actions: isMobile
            ? [
                PopupMenuButton<int>(
                  icon: const Icon(Icons.filter_list, color: Colors.blue),
                  onSelected: (val) => setState(() => _selectedSection = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0, child: Text("My items")),
                    const PopupMenuItem(value: 1, child: Text("Job tracker")),
                  ],
                ),
              ]
            : null,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left nav panel (Desktop only) ──────────────────────────
              if (!isMobile)
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
                  padding: EdgeInsets.fromLTRB(isMobile ? 8 : 0, 16, isMobile ? 8 : 16, 16),
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
          color: selected ? Colors.blue.withOpacity(0.08) : Theme.of(context).cardTheme.color,
          borderRadius: index == 0
              ? const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                )
              : const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
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
                color: selected ? Colors.blue : const Color(0xFF1A2740),
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
            onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
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
