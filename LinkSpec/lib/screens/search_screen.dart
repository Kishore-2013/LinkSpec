import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/supabase_service.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/clay_container.dart';
import 'member_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const SearchScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _recentSearches = ['Cardiology Jobs', 'AI in Healthcare', 'Nursing Events', 'Top Recruiters'];
  
  List<Post> _postResults = [];
  List<Map<String, dynamic>> _peopleResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final postsData = await SupabaseService.searchPosts(query);
      final peopleData = await SupabaseService.searchProfiles(query);

      if (mounted) {
        setState(() {
          _postResults = postsData.map((p) => Post.fromJson(p)).toList();
          _peopleResults = peopleData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
        title: ClayContainer(
          borderRadius: 12,
          emboss: true,
          margin: const EdgeInsets.only(right: 16, top: 4, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search posts or people...',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
            ),
            onSubmitted: _performSearch,
          ),
        ),
        bottom: _hasSearched 
          ? TabBar(
              controller: _tabController,
              labelColor: Colors.blue[800],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue[800],
              tabs: const [
                Tab(text: 'Posts'),
                Tab(text: 'People'),
              ],
            )
          : null,
      ),
      body: Stack(
        children: [
          // Background Illustration
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Opacity(
                    opacity: 0.4,
                    child: SvgPicture.asset(
                      'assets/svg/undraw_searching_no1g.svg',
                      width: 450,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _hasSearched ? _buildSearchResults() : _buildRecentSearches(),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('RECENT SEARCHES', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _recentSearches.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.history, color: Colors.grey, size: 20),
              title: Text(_recentSearches[index], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () {
                _searchController.text = _recentSearches[index];
                _performSearch(_recentSearches[index]);
              },
              trailing: const Icon(Icons.north_west, size: 14, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return TabBarView(
      controller: _tabController,
      children: [
        // Posts Results
        _postResults.isEmpty 
          ? _buildEmptyState('No posts found matching "${_searchController.text}"')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _postResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) => PostCard(post: _postResults[index]),
            ),

        // People Results
        _peopleResults.isEmpty 
          ? _buildEmptyState('No people found matching "${_searchController.text}"')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _peopleResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final person = _peopleResults[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => MemberProfileScreen(userId: person['id']))
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8EAED), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: person['avatar_url'] != null ? NetworkImage(person['avatar_url']) : null,
                          child: person['avatar_url'] == null ? Text(person['full_name'][0]) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(person['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(person['domain_id'] ?? 'Professional', style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
                              if (person['bio'] != null)
                                Text(person['bio'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
