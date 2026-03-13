import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../api/search_manager.dart';
import '../models/post.dart';
import '../widgets/post_card.dart';
import '../widgets/clay_container.dart';
import 'member_profile_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool autofocusSearch;
  final bool searchOnlyConnections;
  /// Pre-populate the search bar and immediately execute this query.
  final String? initialQuery;

  const SearchScreen({
    Key? key,
    this.onBack,
    this.autofocusSearch = false,
    this.searchOnlyConnections = false,
    this.initialQuery,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Post> _postResults = [];
  List<Map<String, dynamic>> _peopleResults = [];
  List<String> _trendingTags = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMsg;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: widget.searchOnlyConnections ? 1 : 2, vsync: this);

    // If we were given an initial query (from a hashtag tap), run it immediately.
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Search logic ──────────────────────────────────────────────

  Future<void> _performSearch(String rawQuery) async {
    // Guard: reject single char / symbol-only queries
    if (!SearchManager.isValidQuery(rawQuery)) {
      setState(() {
        _errorMsg = 'Please enter at least 2 characters to search.';
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMsg = null;
    });

    try {
      final List<Post> postsData;
      if (!widget.searchOnlyConnections) {
        postsData = await SearchManager.searchPosts(rawQuery);
      } else {
        postsData = [];
      }

      // Update trending tags from the freshly returned posts (dynamic, no hardcoding)
      final trending = SearchManager.extractTrendingTags(postsData);

      final peopleData = widget.searchOnlyConnections
          ? await SearchManager.searchPeople(rawQuery)
          : await SearchManager.searchPeople(rawQuery);

      if (mounted) {
        setState(() {
          _postResults   = postsData;
          _peopleResults = peopleData;
          _trendingTags  = trending;
          _isLoading     = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Search failed: $e';
        });
      }
    }
  }

  void _onTagTap(String tag) {
    _searchController.text = tag;
    _performSearch(tag);
  }

  // ── Build ─────────────────────────────────────────────────────

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
            focusNode: _searchFocus,
            autofocus: widget.autofocusSearch,
            decoration: const InputDecoration(
              hintText: 'Search #hashtags or people...',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
            ),
            onSubmitted: _performSearch,
          ),
        ),
        bottom: _hasSearched
            ? (widget.searchOnlyConnections
                ? TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue[800],
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue[800],
                    tabs: const [Tab(text: 'Unites')],
                  )
                : TabBar(
                    controller: _tabController,
                    labelColor: Colors.blue[800],
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue[800],
                    tabs: const [
                      Tab(text: 'Posts'),
                      Tab(text: 'People'),
                    ],
                  ))
            : null,
      ),
      body: Stack(
        children: [
          // ── Content (fills the full stack so Stack knows screen height) ──
          Positioned.fill(
            child: _hasSearched ? _buildSearchResults() : _buildDiscoveryPane(),
          ),

          // ── SVG pinned to screen bottom, drawn BEHIND content ──
          // (Stack children are painted in order; this renders first = behind)
          // We need it before content so we reorder: SVG first paints behind.
          // To achieve: use IgnorePointer so taps pass through.
          Positioned(
            bottom: 80, // above the bottom nav bar
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.35,
                child: SvgPicture.asset(
                  'assets/svg/undraw_searching_no1g.svg',
                  height: 350,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // ── Error banner ──
          if (_errorMsg != null)
            Positioned(
              top: 8,
              left: 20,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: Text(
                  _errorMsg!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Discovery pane (shown before any search) ──────────────────

  Widget _buildDiscoveryPane() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Trending tags (dynamic from last search) ───────────
          if (_trendingTags.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text(
                'TRENDING TAGS',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _trendingTags
                    .map((tag) => _TagChip(tag: tag, onTap: _onTagTap))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Suggested hashtag prompts ─────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Text(
              'SEARCH BY HASHTAG',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _StaticTagChip(tag: '#Medical'),
                _StaticTagChip(tag: '#Software'),
                _StaticTagChip(tag: '#Legal'),
                _StaticTagChip(tag: '#Engineering'),
                _StaticTagChip(tag: '#Finance'),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Results view ──────────────────────────────────────────────

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return TabBarView(
      controller: _tabController,
      children: [
        if (!widget.searchOnlyConnections)
          _postResults.isEmpty
              ? _buildEmptyState('No posts found for "${_searchController.text}".\nTry a hashtag like #Medical')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trending tags extracted from results
                    if (_trendingTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _trendingTags
                              .map((tag) => _TagChip(tag: tag, onTap: _onTagTap))
                              .toList(),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _postResults.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) =>
                            PostCard(post: _postResults[index]),
                      ),
                    ),
                  ],
                ),

        // People tab
        _peopleResults.isEmpty
            ? _buildEmptyState('No ${widget.searchOnlyConnections ? 'unites' : 'people'} found for "${_searchController.text}"')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _peopleResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final person = _peopleResults[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              MemberProfileScreen(userId: person['id'])),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFE8EAED), width: 0.5),
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
                            backgroundImage: person['avatar_url'] != null
                                ? NetworkImage(person['avatar_url'])
                                : null,
                            child: person['avatar_url'] == null
                                ? Text(person['full_name'][0])
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(person['full_name'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    if (person['verification_status'] == 'verified')
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(Icons.verified, color: Colors.blue, size: 16),
                                      ),
                                  ],
                                ),
                                Text(
                                  person['domain_id'] ?? 'Professional',
                                  style: TextStyle(
                                      color: Colors.blue[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                                if (person['bio'] != null)
                                  Text(
                                    person['bio'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.grey[600], fontSize: 13),
                                  ),
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
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable tag chip widgets ─────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  final String tag;
  final void Function(String) onTap;
  const _TagChip({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(tag),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0066CC).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF0066CC).withOpacity(0.3)),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            color: Color(0xFF0066CC),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// Static chip used in the pre-search discovery pane.
/// Needs its own stateful context to call the enclosing screen's search.
class _StaticTagChip extends StatelessWidget {
  final String tag;
  const _StaticTagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to a new SearchScreen with this tag pre-filled
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SearchScreen(
              initialQuery: tag,
              autofocusSearch: false,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            color: Color(0xFF444444),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
