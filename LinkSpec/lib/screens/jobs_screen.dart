import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../services/supabase_service.dart';
import 'job_detail_screen.dart';
import '../widgets/clay_container.dart';
import 'package:timeago/timeago.dart' as timeago;

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  List<Job> _allJobs = [];
  List<Job> _filteredJobs = [];
  bool _isLoading = true;
  String? _userDomain;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserDomainAndJobs();
  }

  Future<void> _loadUserDomainAndJobs() async {
    setState(() => _isLoading = true);
    try {
      final profile = await SupabaseService.getCurrentUserProfile();
      _userDomain = profile?['domain_id'] as String?;
      
      final jobsData = await SupabaseService.getJobs();
      setState(() {
        _allJobs = jobsData.map((data) => Job.fromJson(data)).toList();
        _applyAllFilters();
      });
    } catch (e) {
      print('Error loading jobs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSaveJob(Job job) async {
    try {
      if (job.isSaved) {
        await SupabaseService.unsaveJob(job.id);
      } else {
        await SupabaseService.saveJob(job.id);
      }
      setState(() {
        // Update both lists to reflect the change
        final allIndex = _allJobs.indexWhere((j) => j.id == job.id);
        if (allIndex != -1) {
          _allJobs[allIndex] = _allJobs[allIndex].copyWith(isSaved: !job.isSaved);
        }
        
        final filteredIndex = _filteredJobs.indexWhere((j) => j.id == job.id);
        if (filteredIndex != -1) {
          _filteredJobs[filteredIndex] = _filteredJobs[filteredIndex].copyWith(isSaved: !job.isSaved);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showApplyDialog(Job job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply for Job'),
        content: Text('Would you like to apply to ${job.company} for the ${job.title} position?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application submitted successfully!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () {
              setState(() {
                _selectedFilter = 'Saved';
                _applyAllFilters();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _applyAllFilters(),
                decoration: const InputDecoration(
                  hintText: 'Search jobs, companies...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          
          _buildFilterBar(),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadUserDomainAndJobs,
                  child: _filteredJobs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('No jobs found matching your criteria', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                                if (_selectedFilter != 'All')
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedFilter = 'All';
                                        _applyAllFilters();
                                      });
                                    },
                                    child: const Text('Clear Filters'),
                                  ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final int crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;
                              
                              if (crossAxisCount > 1) {
                                return GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 1.4,
                                  ),
                                  itemCount: _filteredJobs.length,
                                  itemBuilder: (context, index) {
                                    final job = _filteredJobs[index];
                                    return _buildResponsiveJobCard(job);
                                  },
                                );
                              }
                              
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: _filteredJobs.length,
                                itemBuilder: (context, index) {
                                  final job = _filteredJobs[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildResponsiveJobCard(job),
                                  );
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Saved', 'Full-time', 'Remote', 'Contract'];

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                  _applyAllFilters();
                });
              },
              backgroundColor: Colors.grey[50],
              selectedColor: Colors.blue[50],
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              checkmarkColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[200]!),
              ),
            ),
          );
        },
      ),
    );
  }

  void _applyAllFilters() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      _filteredJobs = _allJobs.where((job) {
        final matchesSearch = query.isEmpty ||
            job.title.toLowerCase().contains(query) ||
            job.company.toLowerCase().contains(query) ||
            job.location.toLowerCase().contains(query);

        bool matchesStatus = true;
        if (_selectedFilter == 'Saved') {
          matchesStatus = job.isSaved;
        } else if (_selectedFilter != 'All') {
          matchesStatus = job.type == _selectedFilter;
        }

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Widget _buildResponsiveJobCard(Job job) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailScreen(job: job),
          ),
        );
      },
      child: ClayContainer(
        borderRadius: 14,
        depth: 5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: _buildJobCard(job),
        ),
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.blue[900]?.withOpacity(0.3) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _userDomain == 'Medical' ? Icons.medical_services : Icons.code,
                color: Colors.blue[800],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    job.company,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: job.isSaved ? Colors.blue[800] : Colors.grey[700],
              ),
              onPressed: () => _toggleSaveJob(job),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildChip(Icons.location_on_outlined, job.location),
            const SizedBox(width: 8),
            _buildChip(Icons.work_outline, job.type),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              job.salary,
              style: TextStyle(
                color: Colors.blue[900],
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              timeago.format(job.postedAt),
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _showApplyDialog(job),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: Colors.blue.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Easy Apply', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
