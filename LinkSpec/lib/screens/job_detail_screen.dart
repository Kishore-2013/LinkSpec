
import 'package:flutter/material.dart';
import '../models/job.dart';
import '../services/supabase_service.dart';
import 'package:timeago/timeago.dart' as timeago;

class JobDetailScreen extends StatefulWidget {
  final Job job;

  const JobDetailScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _isSaved = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSavedStatus();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.job.company, style: const TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.blue,
            ),
            onPressed: _isLoading ? null : _toggleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
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

            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  _showApplyDialog(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Easy Apply Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
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
