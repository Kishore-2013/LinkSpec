import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../services/supabase_service.dart';
import 'job_detail_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  bool _isLoading = true;
  String? _userDomain;
  List<Job> _allJobs = [];
  List<Job> _filteredJobs = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserAndFilterJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndFilterJobs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await SupabaseService.getCurrentUserProfile();
      if (profile != null) {
        _userDomain = profile['domain_id'];
        
        // Fetch from Supabase
        final jobsData = await SupabaseService.getJobs();
        
        if (mounted) {
          setState(() {
            _allJobs = jobsData.map((data) => Job.fromJson(data)).toList();
            _filteredJobs = _allJobs;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading jobs from Supabase: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleSaveJob(Job job) async {
    try {
      if (job.isSaved) {
        await SupabaseService.unsaveJob(job.id);
      } else {
        await SupabaseService.saveJob(job.id);
      }

      if (mounted) {
        setState(() {
          // Update the main source list
          _allJobs = _allJobs.map((j) => j.id == job.id ? j.copyWith(isSaved: !j.isSaved) : j).toList();
          // Re-apply filters to sync the current view
          _applyAllFilters();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(job.isSaved ? 'Job removed from bookmarks' : 'Job saved to bookmarks'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showApplyDialog(Job job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Application Sent!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.blue[700], size: 60),
            const SizedBox(height: 16),
            Text('Your application for "${job.title}" at ${job.company} has been submitted successfully.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search jobs, companies...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => _applyAllFilters(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Job Opportunities',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  if (_userDomain != null)
                    Text(
                      'Top picks for $_userDomain',
                      style: TextStyle(color: Colors.blue[600], fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.blue),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _filteredJobs = _allJobs;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadUserAndFilterJobs,
                    child: _filteredJobs.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _filteredJobs.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => JobDetailScreen(job: _filteredJobs[index]),
                                    ),
                                  );
                                },
                                child: _buildJobCard(_filteredJobs[index]),
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
      color: Colors.white,
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
        // Search filter
        final matchesSearch = query.isEmpty ||
            job.title.toLowerCase().contains(query) ||
            job.company.toLowerCase().contains(query) ||
            job.location.toLowerCase().contains(query);

        // Type/Saved filter
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

  Widget _buildJobCard(Job job) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _userDomain == 'Medical' ? Icons.medical_services : Icons.code,
                    color: Colors.blue,
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    job.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: job.isSaved ? Colors.blue : Colors.grey,
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
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  timeago.format(job.postedAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showApplyDialog(job),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Easy Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No matching jobs found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
