import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job.dart';
import '../api/job_service.dart';
import '../services/supabase_service.dart';
import '../services/linkspec_notify.dart';
import '../providers/domain_provider.dart';
import 'job_detail_screen.dart';
import '../widgets/clay_container.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../providers/scroll_provider.dart';

class JobsPage extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final ScrollController? scrollController;
  const JobsPage({Key? key, this.onBack, this.scrollController}) : super(key: key);

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  final List<Job> _jobs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  DateTime? _lastTimestamp;
  bool _hasNextPage = true;
  late ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  bool _isHR = false;
  String? _lastDomain;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ref.read(globalScrollControllerProvider);
    _initializePage();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializePage() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getCurrentUserProfile(),
        JobService.fetchJobs(query: _searchController.text),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final jobResult = results[1] as Map<String, dynamic>;
      final List<Map<String, dynamic>> jobData = jobResult['jobs'];

      if (mounted) {
        setState(() {
          if (profile != null) {
            _isHR = profile['tag'] == 'HR';
            final String? profileDomain = profile['domain_id'] as String?;
            if (profileDomain != null && ref.read(currentDomainProvider) == 'Global') {
              ref.read(currentDomainProvider.notifier).state = profileDomain;
            }
          }
          _jobs.clear();
          _jobs.addAll(jobData.map((e) => Job.fromJson(e)));
          _lastTimestamp = jobResult['lastTimestamp'] as DateTime?;
          _hasNextPage = jobResult['hasMore'] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreJobs();
    }
  }

  Future<void> _loadInitialJobs({String? newDomain}) async {
    setState(() {
      _isLoading = true;
      _lastTimestamp = null;
      _jobs.clear();
      _hasNextPage = true;
    });

    final domainToUse = newDomain ?? ref.read(currentDomainProvider);

    try {
      final result = await JobService.fetchJobs(
        query: _searchController.text,
        domain: domainToUse,
      );

      final List<Map<String, dynamic>> jobData = result['jobs'];
      if (mounted) {
        setState(() {
          _jobs.addAll(jobData.map((e) => Job.fromJson(e)));
          _lastTimestamp = result['lastTimestamp'] as DateTime?;
          _hasNextPage = result['hasMore'] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreJobs() async {
    if (_isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await JobService.fetchJobs(
        before: _lastTimestamp,
        query: _searchController.text,
        domain: ref.read(currentDomainProvider),
      );
      final List<Map<String, dynamic>> jobData = result['jobs'];
      if (mounted) {
        setState(() {
          _jobs.addAll(jobData.map((e) => Job.fromJson(e)));
          _lastTimestamp = result['lastTimestamp'] as DateTime?;
          _hasNextPage = result['hasMore'] as bool;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width <= 700;
    final String activeDomain = ref.watch(currentDomainProvider);

    if (_lastDomain != activeDomain) {
      final oldDomain = _lastDomain;
      _lastDomain = activeDomain;
      if (oldDomain != null) {
        Future.microtask(() => _loadInitialJobs(newDomain: activeDomain));
      }
    }

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          Column(
            children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
                    onPressed: widget.onBack ?? () => context.go('/home'),
                  ),
                  const Text('Jobs Board', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
            ),
            _buildSearchHeader(isMobile),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadInitialJobs,
                    child: _jobs.isEmpty 
                      ? _buildEmptyState()
                      : GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isMobile ? 1 : (MediaQuery.of(context).size.width > 1200 ? 2 : 1),
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: isMobile ? 1.4 : 2.5,
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
        if (_isHR)
          Positioned(
            right: 20,
            bottom: 120,
            child: FloatingActionButton.extended(
              onPressed: _showCreateJobModal,
              backgroundColor: Colors.blue[700],
              icon: const Icon(Icons.add_business, color: Colors.white),
              label: const Text('Post Job', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchHeader(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ClayContainer(
        borderRadius: 12,
        emboss: true,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _searchController,
          onSubmitted: (_) => _loadInitialJobs(),
          decoration: const InputDecoration(
            hintText: 'Search title, company...',
            prefixIcon: Icon(Icons.search, color: Colors.blue),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(Job job, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(job.company, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              if (job.hasApplied)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                  child: const Text('Applied', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Spacer(),
          Text(job.salary, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14)),
          Text('${job.location} • ${timeago.format(job.postedAt, locale: 'en_short')}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => JobDetailScreen.show(context, job).then((_) => _loadInitialJobs()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('View Details'),
            ),
          ),
        ],
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
    final activeDomain = ref.read(currentDomainProvider);
    String selectedDomain = activeDomain.isNotEmpty && activeDomain != 'Global' ? activeDomain : 'Software Development';
    final List<String> customQuestions = [];
    final questionCtrl = TextEditingController();

    final List<String> availableDomains = [
      'Software Development', 'AI, Data & Analytics', 'Healthcare & Life Sciences', 'Finance, Risk & Compliance', 'Design & Creative'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 40),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                const Text('Post a New Job', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildField('Job Title', titleCtrl, Icons.work_outline),
                _buildField('Company', companyCtrl, Icons.business),
                _buildField('Location', locCtrl, Icons.location_on_outlined),
                _buildField('Salary', salaryCtrl, Icons.payments_outlined),
                _buildField('Description', descCtrl, Icons.description_outlined, maxLines: 4),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty || companyCtrl.text.isEmpty) return;
                      await JobService.createJob(
                        title: titleCtrl.text, company: companyCtrl.text, location: locCtrl.text,
                        type: typeCtrl.text, salary: salaryCtrl.text, description: descCtrl.text,
                        domainId: selectedDomain, applicationFormSchema: customQuestions,
                      );
                      Navigator.pop(context);
                      _loadInitialJobs();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: const Text('Publish Job Listing'),
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
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.blue, size: 20),
              filled: true, fillColor: Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
        ],
      ),
    );
  }
}
