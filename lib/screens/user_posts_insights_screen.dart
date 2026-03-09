import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/clay_container.dart';
import 'package:timeago/timeago.dart' as timeago;

class UserPostsInsightsScreen extends StatefulWidget {
  final String userId;
  const UserPostsInsightsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserPostsInsightsScreen> createState() => _UserPostsInsightsScreenState();
}

class _UserPostsInsightsScreenState extends State<UserPostsInsightsScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  int _totalViews = 0;
  int _totalEngagements = 0;
  int _totalShares = 0;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => _isLoading = true);
    try {
      final posts = await SupabaseService.getPostsByUser(userId: widget.userId, limit: 100);
      int views = 0;
      int engagements = 0;
      int shares = 0;

      for (var p in posts) {
        views += (p['views_count'] as int? ?? 0);
        shares += (p['shares_count'] as int? ?? 0);
        engagements += (p['like_count'] as int? ?? 0) + (p['comment_count'] as int? ?? 0);
      }

      setState(() {
        _posts = posts;
        _totalViews = views;
        _totalEngagements = engagements;
        _totalShares = shares;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading activity insights: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Post Activity & Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).cardTheme.color,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadActivity,
              child: CustomScrollView(
                slivers: [
                  // 1. Overview Analytics Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ClayContainer(
                        color: Theme.of(context).cardTheme.color ?? const Color(0xFFB4DAFF),
                        borderRadius: 50,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Analytics Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Past 100 posts performance', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMetric('Impressions', _totalViews, Icons.remove_red_eye_outlined, Colors.blue),
                                  _buildMetric('Engagements', _totalEngagements, Icons.touch_app_outlined, Colors.green),
                                  _buildMetric('Shares', _totalShares, Icons.share_outlined, Colors.purple),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('Individual Post Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // 2. Individual Posts with Insights
                  _posts.isEmpty
                      ? const SliverFillRemaining(child: Center(child: Text('No posts found')))
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final post = _posts[index];
                              return _buildPostInsightCard(post);
                            },
                            childCount: _posts.length,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }

  Widget _buildMetric(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildPostInsightCard(Map<String, dynamic> postData) {
    final views = postData['views_count'] ?? 0;
    final likes = postData['like_count'] ?? 0;
    final comments = postData['comment_count'] ?? 0;
    final shares = postData['shares_count'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClayContainer(
        color: Theme.of(context).cardTheme.color ?? const Color(0xFFB4DAFF),
        borderRadius: 50,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    timeago.format(DateTime.parse(postData['created_at'])),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const Spacer(),
                  const Icon(Icons.trending_up, size: 14, color: Colors.blue),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                postData['content'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSmallStat(views, 'Impressions'),
                  _buildSmallStat(likes + comments, 'Engagements'),
                  _buildSmallStat(shares, 'Shares'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallStat(int value, String label) {
    return Column(
      children: [
        Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
      ],
    );
  }
}
