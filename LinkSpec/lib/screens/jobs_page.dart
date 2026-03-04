import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../api/job_service.dart';
import '../services/supabase_service.dart';
import 'job_detail_screen.dart';
import '../widgets/clay_container.dart';
import 'package:timeago/timeago.dart' as timeago;

class JobsPage extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const JobsPage({Key? key, this.onBack}) : super(key: key);

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  final List<Job> _jobs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  bool _hasNextPage = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String? _currentDomain;
  bool _isHR = false;

  @override
  void initState() {
    super.initState();
    _initializePage();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializePage() async {
    setState(() => _isLoading = true);
    
    // Optimisation: Load profile and initial jobs in parallel
    try {
      final results = await Future.wait([
        SupabaseService.getCurrentUserProfile(),
        JobService.fetchJobs(
          page: 0,
          query: _searchController.text,
        ),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final jobData = results[1] as List<Map<String, dynamic>>;

      if (mounted) {
        setState(() {
          if (profile != null) {
            _isHR = profile['tag'] == 'HR';
            _currentDomain = profile['domain_id'] as String?;
          }
          _jobs.clear();
          _jobs.addAll(jobData.map((e) => Job.fromJson(e)));
          _currentPage = 0;
          _hasNextPage = jobData.length == 10;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error initializing JobsPage: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreJobs();
    }
  }

  Future<void> _loadInitialJobs() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _jobs.clear();
      _hasNextPage = true;
    });

    try {
      final results = await JobService.fetchJobs(
        page: 0,
        query: _searchController.text,
        domain: _currentDomain,
      );
      
      if (mounted) {
        setState(() {
          _jobs.addAll(results.map((e) => Job.fromJson(e)));
          _isLoading = false;
          _hasNextPage = results.length == 10;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error loading jobs: $e');
    }
  }

  Future<void> _loadMoreJobs() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;
      final results = await JobService.fetchJobs(
        page: _currentPage,
        query: _searchController.text,
        domain: _currentDomain,
      );

      if (mounted) {
        setState(() {
          _jobs.addAll(results.map((e) => Job.fromJson(e)));
          _isLoadingMore = false;
          _hasNextPage = results.length == 10;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
      print('Error loading more jobs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onBack != null ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack,
        ) : null,
        title: Text(
          'Jobs Board',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 18 : 22,
          ),
        ),
      ),
      floatingActionButton: _isHR ? FloatingActionButton.extended(
        onPressed: _showCreateJobModal,
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text('Post Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
      body: Column(
        children: [
          // Search Header
          _buildSearchHeader(isMobile),
          
          // Job List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadInitialJobs,
                  child: _jobs.isEmpty 
                    ? _buildEmptyState()
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 1 : (MediaQuery.of(context).size.width > 1200 ? 3 : 2),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: isMobile ? 1.2 : 1.6,
                        ),
                        itemCount: _jobs.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _jobs.length) {
                            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
                          }
                          return _buildJobCard(_jobs[index], isMobile);
                        },
                      ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClayContainer(
        borderRadius: 12,
        depth: 3,
        child: TextField(
          controller: _searchController,
          onSubmitted: (_) => _loadInitialJobs(),
          decoration: InputDecoration(
            hintText: 'Search title, company...',
            prefixIcon: const Icon(Icons.search, color: Colors.blue),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(Job job, bool isMobile) {
    return ClayContainer(
      borderRadius: 16,
      depth: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business, color: Colors.blue, size: 20),
                ),
                const Spacer(),
                if (job.hasApplied)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: const Text('Applied', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                  const Spacer(),
                  Text(job.salary, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0066CC), fontSize: 13)),
                  Text(
                    '${job.location} • ${timeago.format(job.postedAt, locale: 'en_short')}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
                  ).then((_) => _loadInitialJobs());
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateJobModal() {
    final titleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final salaryCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'Full-time');
    final descCtrl = TextEditingController();
    String selectedDomain = _currentDomain ?? 'IT/Software';
    final List<String> customQuestions = [];
    final questionCtrl = TextEditingController();

    final List<String> availableDomains = [
      'Medical', 'IT/Software', 'Civil Engineering', 'Law', 'Business', 'Global'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 40),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 24),
                const Text('Post a New Job', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildField('Job Title', titleCtrl, Icons.work_outline),
                _buildField('Company Name', companyCtrl, Icons.business),
                _buildField('Location', locCtrl, Icons.location_on_outlined),
                _buildField('Salary Range (e.g. \$80k - \$120k)', salaryCtrl, Icons.payments_outlined),
                _buildField('Description', descCtrl, Icons.description_outlined, maxLines: 5),
                const SizedBox(height: 20),
                const Text('Target Domain', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableDomains.map((domain) {
                    final isSelected = selectedDomain == domain;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedDomain = domain),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.blue : Colors.grey[200]!),
                        ),
                        child: Text(
                          domain,
                          style: TextStyle(
                            color: isSelected ? Colors.blue : Colors.grey[700],
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 30),
                const Text('Application Form Builder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Add custom questions for candidates to answer.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: questionCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter a question...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        if (questionCtrl.text.trim().isNotEmpty) {
                          setSheetState(() {
                            customQuestions.add(questionCtrl.text.trim());
                            questionCtrl.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                    ),
                  ],
                ),
                if (customQuestions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...customQuestions.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.blue[50]?.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                          IconButton(
                            onPressed: () => setSheetState(() => customQuestions.removeAt(entry.key)),
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty || companyCtrl.text.isEmpty) return;
                      try {
                        await JobService.createJob(
                          title: titleCtrl.text,
                          company: companyCtrl.text,
                          location: locCtrl.text,
                          type: typeCtrl.text,
                          salary: salaryCtrl.text,
                          description: descCtrl.text,
                          domainId: selectedDomain,
                          applicationFormSchema: customQuestions,
                        );
                        Navigator.pop(context);
                        _loadInitialJobs();
                      } catch (e) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Publish Job Listing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          ClayContainer(
            borderRadius: 12,
            depth: 3,
            child: TextField(
              controller: ctrl,
              maxLines: maxLines,
              decoration: InputDecoration(
                prefixIcon: Icon(icon, color: Colors.blue, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
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
          Icon(Icons.work_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No jobs found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Try a different search or check back later.', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}
