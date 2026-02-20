import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _recentSearches = ['Cardiology Jobs', 'AI in Healthcare', 'Nursing Events', 'Top Recruiters'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search for jobs, people, groups...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 0),
          ),
          onSubmitted: (value) {
            // Future: Implement actual search
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Searching for: $value')));
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Recent Searches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _recentSearches.length,
              itemBuilder: (context, index) => ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(_recentSearches[index]),
                onTap: () {
                  _searchController.text = _recentSearches[index];
                },
                trailing: const Icon(Icons.north_west, size: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
