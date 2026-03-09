import 'package:flutter/material.dart';
import '../api/job_service.dart';
import '../models/job.dart';
import '../widgets/clay_container.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'chat_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class JobApplicantsPage extends StatefulWidget {
  final Job job;
  const JobApplicantsPage({Key? key, required this.job}) : super(key: key);

  @override
  State<JobApplicantsPage> createState() => _JobApplicantsPageState();
}

class _JobApplicantsPageState extends State<JobApplicantsPage> {
  List<Map<String, dynamic>> _applicants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplicants();
  }

  Future<void> _loadApplicants() async {
    setState(() => _isLoading = true);
    final data = await JobService.fetchApplicantsForJob(widget.job.id);
    if (mounted) {
      setState(() {
        _applicants = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Job Applicants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(widget.job.title, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ],
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applicants.isEmpty
              ? _buildEmptyState()
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350, // Responsive: ~3 items per row on web, 1 on mobile
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 90, // Strict height for ListTile consistency
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    profile['domain_id'] ?? 'General',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: Colors.blue[700], fontSize: 10, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeago.format(appliedAt, locale: 'en_short'),
                                    style: TextStyle(color: Colors.grey[400], fontSize: 9),
                                  ),
                                ],
                              ),
                            ),
                            // Trailing: Actions
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (app['answers_json'] != null && (app['answers_json'] as Map).isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.description_outlined, size: 16, color: Colors.blue),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showSubmissionDetail(context, app),
                                    tooltip: 'View Form',
                                  ),
                                const SizedBox(height: 8),
                                IconButton(
                                  icon: const Icon(Icons.mail_outline, color: Colors.blue, size: 18),
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
    );
  }

  void _showSubmissionDetail(BuildContext context, Map<String, dynamic> app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.description_outlined, color: Colors.blue),
                const SizedBox(width: 12),
                const Text('Form Submission', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
            ...(app['answers_json'] as Map<String, dynamic>).entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 8),
                  Text(e.value.toString(), style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color, height: 1.5)),
                ],
              ),
            )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No applicants yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Try sharing your job listing to attract talent.', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}