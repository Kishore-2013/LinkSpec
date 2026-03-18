import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/post.dart';
import '../services/supabase_service.dart';
import '../widgets/post_card.dart';
import '../api/saved_posts_service.dart';
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
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSavedPosts(reset: true);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore && _selectedSection == 0) {
        _loadSavedPosts();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPosts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMore = true;
        _allPosts = [];
      });
    } else {
      if (!_hasMore || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final data = await SavedPostsService.fetchSavedPosts(
        page: _currentPage,
        pageSize: 10,
      );

      final newPosts = data.map((d) => Post.fromJson(d)).toList();

      if (mounted) {
        setState(() {
          if (reset) {
            _allPosts = newPosts;
            _isLoading = false;
          } else {
            _allPosts.addAll(newPosts);
            _isLoadingMore = false;
          }
          _hasMore = newPosts.length == 10;
          _currentPage++;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 700;
    
    ref.listen(savedPostsProvider, (previous, next) {
      if (previous?.length != next.length) {
        if (next.length < (previous?.length ?? 0)) {
          final removedIds = (previous ?? {}).difference(next);
          setState(() {
            _allPosts.removeWhere((p) => removedIds.contains(p.id));
          });
        } else {
          _loadSavedPosts(reset: true);
        }
      }
    });

    return Column(
      children: [
        // Internal Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
                onPressed: widget.onBack ?? () => context.pop(),
              ),
              Expanded(
                child: Text(
                  'Saved items',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 16 : 18,
                  ),
                ),
              ),
              if (isMobile)
                PopupMenuButton<int>(
                  icon: const Icon(Icons.filter_list, color: Colors.blue),
                  onSelected: (val) => setState(() => _selectedSection = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 0, child: Text("My items")),
                    const PopupMenuItem(value: 1, child: Text("Job tracker")),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMobile)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: 200,
                          child: Column(
                            children: [
                              _buildNavTile(icon: Icons.bookmark, label: 'My items', index: 0),
                              const Divider(height: 1),
                              _buildNavTile(icon: Icons.work_outline, label: 'Job tracker', index: 1),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(isMobile ? 8 : 0, 16, isMobile ? 8 : 16, 16),
                        child: _selectedSection == 0 ? _buildMyItems() : _buildJobTracker(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavTile({required IconData icon, required String label, required int index}) {
    final bool selected = _selectedSection == index;
    return InkWell(
      onTap: () => setState(() => _selectedSection = index),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? Colors.blue : Colors.grey),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: selected ? Colors.blue : Colors.black87)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                const Text('Saved Posts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (!_isLoading)
                  TextButton.icon(
                    onPressed: () => _loadSavedPosts(reset: true),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF0066CC), borderRadius: BorderRadius.circular(20)),
              child: const Text('All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
          else if (_allPosts.isEmpty)
            _buildEmptyState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _allPosts.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == _allPosts.length) {
                  return const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator()));
                }
                return Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: PostCard(post: _allPosts[i]));
              },
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
          Icon(Icons.bookmark_border_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 24),
          const Text('Start saving posts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Saved posts will show up here', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: widget.onBack ?? () => context.pop(),
            child: const Text('Go to Feed'),
          ),
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
          const Text('Job Tracker', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Track jobs you\'ve applied to or saved.', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                Icon(Icons.work_outline, size: 72, color: Colors.grey[200]),
                const SizedBox(height: 16),
                const Text('No tracked jobs yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
