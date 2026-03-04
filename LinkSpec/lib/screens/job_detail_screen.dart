import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/supabase_service.dart';
import '../api/job_service.dart';
import 'job_applicants_page.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/clay_container.dart';
import 'chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;

  const JobDetailScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isSaved = false;
  bool _hasApplied = false;
  bool _isLoading = true;
  bool _isApplying = false;
  bool _isDeleting = false;
  List<Map<String, dynamic>> _applicants = [];
  bool _isLoadingApplicants = false;
  bool _isHR = false;
  
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _formSectionKey = GlobalKey();
  final Map<String, TextEditingController> _formControllers = {};

  @override
  void initState() {
    super.initState();
    _isSaved = widget.job.isSaved;
    _hasApplied = widget.job.hasApplied;
    
    // Initialize form controllers
    for (var question in widget.job.applicationFormSchema) {
      _formControllers[question] = TextEditingController();
    }
    
    _initializeData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var controller in _formControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _scrollToForm() {
    final context = _formSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _initializeData() async {
    try {
      final results = await Future.wait([
        SupabaseService.getCurrentUserProfile(),
        SupabaseService.isJobSaved(widget.job.id),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final savedStatus = results[1] as bool;
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (mounted) {
        setState(() {
          _isHR = widget.job.postedBy == currentUserId;
          _isSaved = savedStatus;
          _isLoading = false;
        });
      }

      // If HR, load applicants (doesn't block the main UI thread)
      if (_isHR) {
        _loadApplicants();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadApplicants() async {
    if (!mounted) return;
    setState(() => _isLoadingApplicants = true);
    try {
      final data = await JobService.fetchApplicantsForJob(widget.job.id);
      if (mounted) {
        setState(() {
          _applicants = data;
          _isLoadingApplicants = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingApplicants = false);
    }
  }

  Future<void> _checkSavedStatus() async {
    try {
      final saved = await SupabaseService.isJobSaved(widget.job.id);
      if (mounted) {
        setState(() {
          _isSaved = saved;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleSave() async {
    setState(() => _isLoading = true);
    try {
      if (_isSaved) {
        await SupabaseService.unsaveJob(widget.job.id);
      } else {
        await SupabaseService.saveJob(widget.job.id);
      }
      if (mounted) {
        setState(() {
          _isSaved = !_isSaved;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSaved ? 'Job saved to bookmarks' : 'Job removed from bookmarks'),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleApply() async {
    if (_hasApplied || _isApplying) return;

    if (widget.job.applicationFormSchema.isNotEmpty) {
      _showDynamicFormModal();
      return;
    }

    setState(() => _isApplying = true);
    try {
      await JobService.applyForJob(widget.job.id);
      if (mounted) {
        setState(() {
          _hasApplied = true;
          _isApplying = false;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Application failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDynamicFormModal() {
    final Map<String, TextEditingController> controllers = {
      for (var q in widget.job.applicationFormSchema) q: TextEditingController()
    };

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
                Text('Apply for ${widget.job.title}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Please answer the following questions to complete your application for ${widget.job.company}.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 24),
                ...widget.job.applicationFormSchema.map((question) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A2740))),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        controller: controllers[question],
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Your answer...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isApplying ? null : () async {
                      // Check validation
                      bool allFilled = true;
                      for(var ctrl in controllers.values) {
                        if (ctrl.text.trim().isEmpty) allFilled = false;
                      }
                      if (!allFilled) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please answer all questions'), backgroundColor: Colors.orange));
                        return;
                      }

                      setSheetState(() => _isApplying = true);
                      try {
                        final answers = controllers.map((q, ctrl) => MapEntry(q, ctrl.text.trim()));
                        await JobService.applyForJob(widget.job.id, answers: answers);
                        Navigator.pop(context);
                        if (mounted) {
                          setState(() {
                            _hasApplied = true;
                            _isApplying = false;
                          });
                          _showSuccessDialog();
                        }
                      } catch (e) {
                        setSheetState(() => _isApplying = false);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isApplying 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteJob() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Job Posting?'),
        content: const Text('This action cannot be undone. All application data for this job will also be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await JobService.deleteJob(widget.job.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Job posting deleted successfully'), backgroundColor: Colors.blue));
        Navigator.pop(context, true); // Signal that it was deleted
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete job: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Application Sent!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            Text('Your application for "${widget.job.title}" at ${widget.job.company} has been submitted successfully.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Great'),
          ),
        ],
      ),
    );
  }

   @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;
    final bool showApplicantsSide = isDesktop && _isHR;

     return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2740)),
        title: Text(widget.job.company, style: const TextStyle(color: Color(0xFF1A2740))),
        actions: [
          if (!_isHR && !_hasApplied)
            TextButton.icon(
              onPressed: _scrollToForm,
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text('Apply Now', style: TextStyle(fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
            ),
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.blue,
            ),
            onPressed: _isLoading ? null : _toggleSave,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (showApplicantsSide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Job Details
                Expanded(
                  flex: 4,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: _buildJobDetailContent(),
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xFFE5E5EA)),
                // Right Side: Applicant list
                Expanded(
                  flex: 3,
                  child: _buildApplicantsSidebar(),
                ),
              ],
            );
          }
          return SingleChildScrollView(
            controller: _scrollController,
            child: _buildJobDetailContent(),
          );
        },
      ),
    );
  }

  Widget _buildJobDetailContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  widget.job.domainId == 'Medical' ? Icons.medical_services : Icons.code,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              if (_isHR)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: Text(_applicants.isEmpty ? 'Applicants' : 'Applicants (${_applicants.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          // On mobile, navigate to full page. On desktop, it's already visible in sidebar.
                          if (MediaQuery.of(context).size.width < 900) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JobApplicantsPage(job: widget.job),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(color: Colors.blue[700]!, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        icon: _isDeleting ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red)) : const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isDeleting ? null : _handleDeleteJob,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          side: BorderSide(color: Colors.red[300]!, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                widget.job.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.job.company,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                children: [
                  _buildInfoBadge(Icons.location_on_outlined, widget.job.location),
                  _buildInfoBadge(Icons.work_outline, widget.job.type),
                  _buildInfoBadge(Icons.calendar_today_outlined, timeago.format(widget.job.postedAt)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Salary & Type
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Salary Range', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(widget.job.salary, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Job Type', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(widget.job.type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Description
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Job Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                widget.job.description,
                style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.6),
              ),
              const SizedBox(height: 24),
              const Text('Responsibilities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildBulletPoint('Work closely with cross-functional teams to deliver high-quality results.'),
              _buildBulletPoint('Maintain code quality through best practices and rigorous testing.'),
              _buildBulletPoint('Stay updated with industry trends and emerging technologies.'),
              _buildBulletPoint('Participate in regular team meetings and contribute ideas.'),
            ],
          ),
        ),

        if (!_isHR) ...[
          const SizedBox(height: 24),
          _buildApplicationFormSection(),
        ],

        const SizedBox(height: 100), 
      ],
    );
  }

  Widget _buildApplicationFormSection() {
    if (_hasApplied) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green[100]!),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 16),
            const Text('Application Submitted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 8),
            Text('You have already applied for this position. We will contact you soon.', 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.green[800], fontSize: 14)
            ),
          ],
        ),
      );
    }

    return Container(
      key: _formSectionKey,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_document, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Apply for this Position', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Complete the form below to submit your application for ${widget.job.title}.', 
            style: TextStyle(color: Colors.grey[600], fontSize: 13)
          ),
          const SizedBox(height: 32),
          
          // Dynamic Form Fields
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth > 600;
              final questions = widget.job.applicationFormSchema;
              
              if (questions.isEmpty) {
                return const Text('No additional questions required. Just click submit!');
              }

              // Pair questions if screen is wide
              List<Widget> rows = [];
              for (int i = 0; i < questions.length; i += (isWide ? 2 : 1)) {
                if (isWide && i + 1 < questions.length) {
                  rows.add(Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildFormField(questions[i])),
                      const SizedBox(width: 20),
                      Expanded(child: _buildFormField(questions[i + 1])),
                    ],
                  ));
                } else {
                  rows.add(_buildFormField(questions[i]));
                }
              }

              return Column(children: rows);
            }
          ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isApplying ? null : _submitIntegratedForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isApplying 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Submit Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(String question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A2740))),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: TextField(
              controller: _formControllers[question],
              maxLines: question.toLowerCase().contains('description') || question.toLowerCase().contains('why') ? 3 : 1,
              decoration: InputDecoration(
                hintText: 'Your answer...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitIntegratedForm() async {
    // Check validation
    bool allFilled = true;
    for(var ctrl in _formControllers.values) {
      if (ctrl.text.trim().isEmpty) allFilled = false;
    }
    if (!allFilled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please answer all questions'), backgroundColor: Colors.orange));
      _scrollToForm();
      return;
    }

    setState(() => _isApplying = true);
    try {
      final answers = _formControllers.map((q, ctrl) => MapEntry(q, ctrl.text.trim()));
      await JobService.applyForJob(widget.job.id, answers: answers);
      if (mounted) {
        setState(() {
          _hasApplied = true;
          _isApplying = false;
        });
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildApplicantsSidebar() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.people_outline, color: Colors.blue),
              const SizedBox(width: 12),
              const Text('Applicants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2740))),
              const Spacer(),
              if (_isLoadingApplicants)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              if (!_isLoadingApplicants)
                Text('${_applicants.length}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingApplicants && _applicants.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _applicants.isEmpty
                  ? _buildApplicantsEmptyState()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: 90,
                      ),
                      itemCount: _applicants.length,
                      itemBuilder: (context, index) {
                        final app = _applicants[index];
                        final profile = app['profiles'] as Map<String, dynamic>;
                        final appliedAt = DateTime.parse(app['applied_at']);

                        return ClayContainer(
                          borderRadius: 12,
                          depth: 3,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Leading: Avatar
                                CircleAvatar(
                                  radius: 18,
                                  backgroundImage: profile['avatar_url'] != null
                                      ? CachedNetworkImageProvider(profile['avatar_url'])
                                      : null,
                                  child: profile['avatar_url'] == null
                                      ? const Icon(Icons.person, size: 18)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                // Middle: Info
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile['full_name'] ?? 'Unknown',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1A2740)),
                                      ),
                                      Text(
                                        profile['domain_id'] ?? 'General',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: Colors.blue[700], fontSize: 9, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        timeago.format(appliedAt, locale: 'en_short'),
                                        style: TextStyle(color: Colors.grey[400], fontSize: 8),
                                      ),
                                    ],
                                  ),
                                ),
                                // Trailing: Actions
                                const SizedBox(width: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (app['answers_json'] != null && (app['answers_json'] as Map).isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.description_outlined, size: 14, color: Colors.blue),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _showSubmissionDetailSide(context, app),
                                        tooltip: 'View Form',
                                      ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.mail_outline, color: Colors.blue, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatScreen(otherUser: profile),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildApplicantsEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('No applicants yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showSubmissionDetailSide(BuildContext context, Map<String, dynamic> app) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text('Form Submission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...(app['answers_json'] as Map<String, dynamic>).entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                            const SizedBox(height: 8),
                            Text(e.value.toString(), style: const TextStyle(fontSize: 15, color: Color(0xFF1A2740), height: 1.5)),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyBottomSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: const Color(0xFF1A2740).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _hasApplied || _isApplying ? null : _handleApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasApplied ? Colors.grey[200] : Colors.blue,
                foregroundColor: _hasApplied ? Colors.grey[600] : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isApplying 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    _hasApplied ? 'Applied' : 'Easy Apply Now', 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[700]))),
        ],
      ),
    );
  }

  void _showApplyDialog(BuildContext context) {
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
            Text('Your application for "${widget.job.title}" at ${widget.job.company} has been submitted successfully.'),
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
}
