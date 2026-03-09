import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/group.dart';
import '../services/supabase_service.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const GroupsScreen({Key? key, this.onBack}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group> _groups = [];
  bool _isLoading = true;

  final Set<String> _joinedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final data = await SupabaseService.getGroups();
      if (mounted) {
        setState(() {
          _groups = data.map((d) => Group.fromJson(d)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Groups'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/svg/undraw_coming-soon_7lvi.svg',
              height: 200,
              placeholderBuilder: (BuildContext context) => const CircularProgressIndicator(),
            ),
            const SizedBox(height: 32),
            Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Groups feature is under development.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
