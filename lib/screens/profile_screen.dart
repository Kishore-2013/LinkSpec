import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';
import 'user_posts_insights_screen.dart';
import 'member_profile_screen.dart';
import '../widgets/post_card.dart' show ViewTracker;
import '../providers/saved_posts_provider.dart';
import '../services/verification_service.dart';
import '../widgets/verification_viewer.dart';
import 'dart:async';

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const ProfileScreen({Key? key, this.onBack}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  List<Map<String, dynamic>> _userPosts = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  final _bioController = TextEditingController();
  final _nameController = TextEditingController();
  int _followersCount = 0;
  int _followingCount = 0;
  int _connectionsCount = 0;
  String? _coverUrl; // separate so we can update it live
  RealtimeChannel? _profileSubscription;


  @override
  void initState() {
    super.initState();
    _loadProfile();
    _setupProfileListener();
  }

  void _setupProfileListener() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _profileSubscription = SupabaseService.subscribeToProfileChanges(userId, (payload) {
      if (mounted) {
        setState(() {
          if (_profile != null) {
            _profile = _profile!.copyWith(
              verificationStatus: payload['verification_status'] as String?,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _bioController.dispose();
    _nameController.dispose();
    _profileSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final profileData = await SupabaseService.getCurrentUserProfile(forceRefresh: true);
      if (profileData == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final profile = UserProfile.fromJson(profileData);

      // Run secondary calls in parallel; don't let them block profile display
      final results = await Future.wait([
        SupabaseService.getConnectionCounts(profile.id).catchError((_) => {'followers': 0, 'following': 0}),
        SupabaseService.getPostsByUser(userId: profile.id, limit: 3).catchError((_) => <Map<String, dynamic>>[]),
        SupabaseService.getUniteCount(profile.id).catchError((_) => 0),
      ]);

      final counts = results[0] as Map<String, int>;
      final posts  = results[1] as List<Map<String, dynamic>>;
      final cCount = results[2] as int;

      if (mounted) {
        setState(() {
          _profile         = profile;
          _bioController.text  = profile.bio ?? '';
          _nameController.text = profile.fullName;
          _followersCount  = counts['followers'] ?? 0;
          _followingCount  = counts['following'] ?? 0;
          _connectionsCount = cCount;
          _userPosts       = posts;
          _coverUrl        = profileData['cover_url'];
        });
      }
    } catch (e) {
      debugPrint('ProfileScreen: error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _updateProfile() async {
    if (_profile == null) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updateProfile(
        fullName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        experience: _profile!.experience,
        education: _profile!.education,
        projects: _profile!.projects,
        skills: _profile!.skills,
      );
      await _loadProfile();
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.blue[700]),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    
    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = result.files.single.bytes!;
      final url = await SupabaseService.uploadAvatar(bytes, result.files.single.name);
      setState(() {
        _profile = _profile?.copyWith(avatarUrl: url);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Avatar updated!'), backgroundColor: Colors.blue[700]),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    
    setState(() => _isUploadingCover = true);
    try {
      final bytes = result.files.single.bytes!;
      final url = await SupabaseService.uploadCoverPhoto(bytes, result.files.single.name);
      setState(() => _coverUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Cover photo updated!'), backgroundColor: Colors.blue[700]),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  void _addSkill() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Skill'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. Python, Flutter, Java',
            helperText: 'Separate multiple skills with commas',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final raw = controller.text.trim();
              if (raw.isNotEmpty) {
                // Split by comma and clean each skill
                final newSkills = raw
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                setState(() {
                  _profile = _profile?.copyWith(
                    skills: [..._profile!.skills, ...newSkills],
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addExperience() {
    _showExperienceDialog();
  }

  void _editExperience(int index) {
    final exp = _profile!.experience[index];
    _showExperienceDialog(existingExp: exp, editIndex: index);
  }

  void _showExperienceDialog({Map<String, dynamic>? existingExp, int? editIndex}) {
    final roleC = TextEditingController(text: existingExp?['role'] ?? '');
    final companyC = TextEditingController(text: existingExp?['company'] ?? '');
    DateTime? startDate;
    DateTime? endDate;
    String? dateError;

    // Parse existing dates if editing
    if (existingExp != null) {
      final startStr = existingExp['start_date'] as String?;
      final endStr = existingExp['end_date'] as String?;
      if (startStr != null && startStr.isNotEmpty) {
        startDate = DateTime.tryParse(startStr);
      }
      if (endStr != null && endStr.isNotEmpty) {
        endDate = DateTime.tryParse(endStr);
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editIndex != null ? 'Edit Experience' : 'Add Experience'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: roleC, decoration: const InputDecoration(labelText: 'Role / Title')),
              const SizedBox(height: 8),
              TextField(controller: companyC, decoration: const InputDecoration(labelText: 'Company')),
              const SizedBox(height: 16),
              // Start Date
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(1950),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            startDate = picked;
                            dateError = null;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          startDate != null
                              ? '${_monthName(startDate!.month)}-${startDate!.day.toString().padLeft(2, '0')}-${startDate!.year}'
                              : 'Start Date',
                          style: TextStyle(color: startDate != null ? Colors.black : Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // End Date
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(1950),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            endDate = picked;
                            dateError = null;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          endDate != null
                              ? '${_monthName(endDate!.month)}-${endDate!.day.toString().padLeft(2, '0')}-${endDate!.year}'
                              : 'End Date (leave empty if current)',
                          style: TextStyle(color: endDate != null ? Colors.black : Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (dateError != null) ...[  
                const SizedBox(height: 8),
                Text(dateError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (roleC.text.trim().isEmpty) return;
                // Validate dates
                if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) {
                  setDialogState(() =>
                    dateError = 'Incorrect data: End date cannot be before start date');
                  return;
                }
                final duration = startDate != null
                    ? '${_monthName(startDate!.month)} ${startDate!.year} - ${endDate != null ? "${_monthName(endDate!.month)} ${endDate!.year}" : "Present"}'
                    : '';
                final entry = {
                  'role': roleC.text.trim(),
                  'company': companyC.text.trim(),
                  'duration': duration,
                  'start_date': startDate?.toIso8601String() ?? '',
                  'end_date': endDate?.toIso8601String() ?? '',
                };
                setState(() {
                  if (editIndex != null) {
                    final l = [..._profile!.experience];
                    l[editIndex] = entry;
                    _profile = _profile!.copyWith(experience: l);
                  } else {
                    _profile = _profile?.copyWith(
                      experience: [..._profile!.experience, entry],
                    );
                  }
                });
                Navigator.pop(context);
              },
              child: Text(editIndex != null ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get month name
  String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }

  void _addEducation() {
    _showEducationDialog();
  }

  void _editEducation(int index) {
    final edu = _profile!.education[index];
    _showEducationDialog(existingEdu: edu, editIndex: index);
  }

  void _showEducationDialog({Map<String, dynamic>? existingEdu, int? editIndex}) {
    final degC = TextEditingController(text: existingEdu?['degree'] ?? '');
    final instC = TextEditingController(text: existingEdu?['institution'] ?? '');
    DateTime? startDate;
    DateTime? endDate;
    String? dateError;

    if (existingEdu != null) {
      final startStr = existingEdu['start_date'] as String?;
      final endStr = existingEdu['end_date'] as String?;
      if (startStr != null && startStr.isNotEmpty) startDate = DateTime.tryParse(startStr);
      if (endStr != null && endStr.isNotEmpty) endDate = DateTime.tryParse(endStr);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(editIndex != null ? 'Edit Education' : 'Add Education'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: degC, decoration: const InputDecoration(labelText: 'Degree')),
              const SizedBox(height: 8),
              TextField(controller: instC, decoration: const InputDecoration(labelText: 'Institution / School')),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(1950),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() { startDate = picked; dateError = null; });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          startDate != null ? '${_monthName(startDate!.month)}-${startDate!.day.toString().padLeft(2,'0')}-${startDate!.year}' : 'Start Date',
                          style: TextStyle(color: startDate != null ? Colors.black : Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(1950),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() { endDate = picked; dateError = null; });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          endDate != null ? '${_monthName(endDate!.month)}-${endDate!.day.toString().padLeft(2,'0')}-${endDate!.year}' : 'End Date (leave empty if current)',
                          style: TextStyle(color: endDate != null ? Colors.black : Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (dateError != null) ...[  
                const SizedBox(height: 8),
                Text(dateError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (degC.text.trim().isEmpty) return;
                if (startDate != null && endDate != null && endDate!.isBefore(startDate!)) {
                  setDialogState(() => dateError = 'Incorrect data: End date cannot be before start date');
                  return;
                }
                final duration = startDate != null
                    ? '${_monthName(startDate!.month)} ${startDate!.year} - ${endDate != null ? "${_monthName(endDate!.month)} ${endDate!.year}" : "Present"}'
                    : '';
                final entry = {
                  'degree': degC.text.trim(),
                  'institution': instC.text.trim(),
                  'duration': duration,
                  'start_date': startDate?.toIso8601String() ?? '',
                  'end_date': endDate?.toIso8601String() ?? '',
                };
                setState(() {
                  if (editIndex != null) {
                    final l = [..._profile!.education];
                    l[editIndex] = entry;
                    _profile = _profile!.copyWith(education: l);
                  } else {
                    _profile = _profile?.copyWith(education: [..._profile!.education, entry]);
                  }
                });
                Navigator.pop(context);
              },
              child: Text(editIndex != null ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addProject() {
    final titleC = TextEditingController(), descC = TextEditingController(), linkC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Project'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleC, decoration: const InputDecoration(hintText: 'Project Title')),
          TextField(controller: descC, decoration: const InputDecoration(hintText: 'Description')),
          TextField(controller: linkC, decoration: const InputDecoration(hintText: 'Link (Optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (titleC.text.trim().isNotEmpty) {
                setState(() { _profile = _profile?.copyWith(projects: [..._profile!.projects, {'title': titleC.text.trim(), 'description': descC.text.trim(), 'link': linkC.text.trim()}]); });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: CustomScrollView(
          slivers: [
            // ── Full header: cover + avatar + info in ONE stack ──────────
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Cover + content column
                  Column(
                    children: [
                      // Cover area
                      GestureDetector(
                        onTap: _pickCover,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            image: DecorationImage(
                              image: _coverUrl != null
                                  ? CachedNetworkImageProvider(_coverUrl!)
                                  : const CachedNetworkImageProvider(
                                      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=2070&auto=format&fit=crop',
                                    ) as ImageProvider,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                          child: Stack(
                            children: [
                              if (_isUploadingCover)
                                Container(
                                  color: Colors.black26,
                                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Change cover', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // White Card Area
                      Container(
                        color: Theme.of(context).cardTheme.color,
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isEditing)
                              TextField(
                                controller: _nameController,
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(hintText: 'Full Name', border: InputBorder.none),
                              )
                             else
                               Row(
                                 children: [
                                   Text(_profile?.fullName ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                   _buildVerificationBadge(),
                                 ],
                               ),
                            const SizedBox(height: 6),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                               decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                               child: Text(
                                 _profile?.domainId.toUpperCase() ?? '',
                                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                               ),
                             ),
                             const SizedBox(height: 12),
                             Row(
                               children: [
                                 const Icon(Icons.business, size: 16, color: Colors.blue),
                                 const SizedBox(width: 8),
                                 Text(
                                   'Industry: ${_profile?.domainId.toUpperCase() ?? "Professional"}',
                                   style: TextStyle(
                                     fontSize: 14,
                                     fontWeight: FontWeight.w600,
                                     color: Colors.blue[900],
                                   ),
                                 ),
                               ],
                             ),

                             const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildStat(_connectionsCount, 'Unites', onTap: _showConnectionsDialog),
                                  const SizedBox(width: 24),
                                  _buildStat(_followersCount, 'Followers'),
                                  const SizedBox(width: 24),
                                  _buildStat(_followingCount, 'Following'),
                                ],
                              ),
                            const SizedBox(height: 16),
                            if (_isEditing) ...[
                              TextField(
                                controller: _bioController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Write something about yourself...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('Industry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  _profile?.domainId.toUpperCase() ?? 'NONE',
                                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                                ),
                              ),
                            ]
                            else if (_profile?.bio != null && _profile!.bio!.isNotEmpty)
                               Text(_profile!.bio!, style: const TextStyle(fontSize: 15, height: 1.5, color: Color(0xFF1A2740))),
                            if (_isEditing) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _updateProfile,
                                    child: const Text('Save Changes'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: () => setState(() => _isEditing = false),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 2. Avatar (TOP LAYER)
                  Positioned(
                    top: 140, // 200 cover - 60 offset
                    left: 20,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).cardTheme.color ?? Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.blue[50],
                                backgroundImage: _profile?.avatarUrl != null
                                  ? CachedNetworkImageProvider(_profile!.avatarUrl!)
                                  : null,
                              child: _profile?.avatarUrl == null
                                  ? Text(
                                      _profile?.fullName[0].toUpperCase() ?? '?',
                                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                                    )
                                  : null,
                            ),
                            if (_isUploadingAvatar)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Floating Actions (Sticky top-right)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    right: 12,
                    child: Row(
                      children: [
                        _buildFloatingAction(Icons.settings, () => Navigator.pushNamed(context, '/settings')),
                        const SizedBox(width: 8),
                        _buildFloatingAction(_isEditing ? Icons.check : Icons.edit, _isEditing ? _updateProfile : () => setState(() => _isEditing = true)),
                        const SizedBox(width: 8),
                        _buildFloatingAction(Icons.logout, () async {
                           ViewTracker.clear();
                           ref.read(savedPostsProvider.notifier).clear();
                           await Supabase.instance.client.auth.signOut();
                           if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                        }, color: Colors.redAccent),
                      ],
                    ),
                  ),
                  // 4. Floating Back Button
                   Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 10,
                    child: _buildFloatingAction(Icons.arrow_back_ios_new_rounded, widget.onBack ?? () => Navigator.maybePop(context)),
                  ),
                  // 5. Absolute Get Verified Button
                  Positioned(
                    top: 260, // Level with name (200 cover + 60 padding)
                    right: 20,
                    child: _buildGetVerifiedButton(),
                  ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Activity ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Activity',
                onHeaderTap: () {
                  if (_profile != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserPostsInsightsScreen(userId: _profile!.id),
                      ),
                    );
                  }
                },
                content: _userPosts.isEmpty
                    ? const Text('No recent activity', style: TextStyle(color: Colors.grey))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ..._userPosts.map((post) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('Posted ${post['created_at'].toString().substring(0, 10)}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                    const Spacer(),
                                    Icon(Icons.bar_chart, size: 14, color: Colors.blue[300]),
                                    const SizedBox(width: 4),
                                    Text('${(post['views_count'] ?? 0)} impressions', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                  ],
                                ),
                              ],
                            ),
                          )).toList(),
                          const Divider(height: 24),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                if (_profile != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserPostsInsightsScreen(userId: _profile!.id),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Show all activity →', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Experience ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Experience',
                onAdd: _isEditing ? _addExperience : null,
                content: _profile?.experience.isEmpty ?? true
                    ? const Text('No experience added yet', style: TextStyle(color: Colors.grey))
                    : Column(children: List.generate(_profile!.experience.length, (i) => _buildExpItem(_profile!.experience[i], i))),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Education ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Education',
                onAdd: _isEditing ? _addEducation : null,
                content: _profile?.education.isEmpty ?? true
                    ? const Text('No education added yet', style: TextStyle(color: Colors.grey))
                    : Column(children: List.generate(_profile!.education.length, (i) => _buildEduItem(_profile!.education[i], i))),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Projects ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Projects',
                onAdd: _isEditing ? _addProject : null,
                content: _profile?.projects.isEmpty ?? true
                    ? const Text('No projects added yet', style: TextStyle(color: Colors.grey))
                    : Column(children: List.generate(_profile!.projects.length, (i) => _buildProjItem(_profile!.projects[i], i))),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Skills ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Skills',
                onAdd: _isEditing ? _addSkill : null,
                content: _profile?.skills.isEmpty ?? true
                    ? const Text('No skills added yet', style: TextStyle(color: Colors.grey))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_profile!.skills.length, (i) => Chip(
                          label: Text(_profile!.skills[i]),
                          backgroundColor: Colors.blue[50],
                          labelStyle: const TextStyle(color: Colors.blue, fontSize: 12),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onDeleted: _isEditing ? () {
                            setState(() {
                              final s = [..._profile!.skills];
                              s.removeAt(i);
                              _profile = _profile!.copyWith(skills: s);
                            });
                          } : null,
                        )),
                      ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(int count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.blue[700], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showConnectionsDialog() async {
    if (_profile == null) return;
    
    showDialog(
      context: context,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final connections = await SupabaseService.getAcceptedConnections(_profile!.id);
    
    if (mounted) Navigator.pop(context); // Close loading

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('United'),
          content: connections.isEmpty
              ? const Text('No united people yet.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: connections.length,
                    itemBuilder: (context, index) {
                      final conn = connections[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: conn['avatar_url'] != null ? NetworkImage(conn['avatar_url']) : null,
                          child: conn['avatar_url'] == null ? Text(conn['full_name'][0].toUpperCase()) : null,
                        ),
                        title: Text(conn['full_name'] ?? 'Unknown'),
                        subtitle: Text(conn['domain_id'] ?? ''),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MemberProfileScreen(userId: conn['id'])),
                          );
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    }
  }

  Widget _buildSection({required String title, required Widget content, VoidCallback? onAdd, VoidCallback? onHeaderTap}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
         boxShadow: [BoxShadow(color: const Color(0xFF1A2740).withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onHeaderTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (onAdd != null)
                  IconButton(icon: const Icon(Icons.add, size: 20, color: Colors.blue), onPressed: onAdd, padding: EdgeInsets.zero, constraints: const BoxConstraints())
                else if (onHeaderTap != null)
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildExpItem(Map<String, dynamic> exp, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.business, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(exp['role'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(exp['company'] ?? '', style: const TextStyle(color: Colors.grey)),
          Text(exp['duration'] ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ])),
        if (_isEditing) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
            onPressed: () => _editExperience(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () {
            setState(() { final l = [..._profile!.experience]; l.removeAt(index); _profile = _profile!.copyWith(experience: l); });
          }),
        ],
      ]),
    );
  }

  Widget _buildEduItem(Map<String, dynamic> edu, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.school, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(edu['degree'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(edu['institution'] ?? '', style: const TextStyle(color: Colors.grey)),
          Text(edu['duration'] ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ])),
        if (_isEditing) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
            onPressed: () => _editEducation(index),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () {
            setState(() { final l = [..._profile!.education]; l.removeAt(index); _profile = _profile!.copyWith(education: l); });
          }),
        ],
      ]),
    );
  }

  Widget _buildProjItem(Map<String, dynamic> proj, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.folder_outlined, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(proj['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(proj['description'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          if (proj['link'] != null && proj['link'].toString().isNotEmpty)
            Text(proj['link'], style: const TextStyle(color: Colors.blue, fontSize: 12)),
        ])),
        if (_isEditing)
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () {
            setState(() { final l = [..._profile!.projects]; l.removeAt(index); _profile = _profile!.copyWith(projects: l); });
          }),
      ]),
    );
  }

  Widget _buildFloatingAction(IconData icon, VoidCallback onTap, {Color? color}) {
    return CircleAvatar(
      backgroundColor: Colors.white.withOpacity(0.9),
      radius: 18,
      child: IconButton(
        icon: Icon(icon, size: 18, color: color ?? const Color(0xFF1A2740)),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Future<void> _startVerification() async {
    if (_profile == null) return;

    final userId = SupabaseService.getCurrentUserId();
    if (userId == null) return;

    // Domain to Fermion Env mapping
    final Map<String, String> domainToEnv = {
      'Medical': 'medc1',
      'IT/Software': 'sde1',
      'Civil Engineering': 'de2',
      'Law': 'bie2',
      'Business': 'ba2',
      'Global': 'default',
    };

    final env = domainToEnv[_profile!.domainId] ?? 'default';
    final url = VerificationService.getRedirectUrl(userId: userId, env: env);

    // Optional: Pre-create user in Fermion
    await VerificationService.createFermionUser(
      userId: userId, 
      name: _profile!.fullName, 
      email: _profile!.email ?? '',
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationViewer(
          url: url,
          onComplete: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Verification in progress. Please wait a moment for the badge to appear.')),
            );
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    if (_profile?.verificationStatus != 'verified') return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(left: 6),
      child: Icon(Icons.verified, color: Colors.blue, size: 20),
    );
  }

  Widget _buildGetVerifiedButton() {
    final status = _profile?.verificationStatus ?? 'none';
    if (status == 'verified') return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: _startVerification,
      icon: Icon(status == 'pending' ? Icons.hourglass_bottom_rounded : Icons.verified_user, size: 14),
      label: Text(status == 'pending' ? 'Pending' : 'Get Verified', 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        backgroundColor: status == 'pending' ? Colors.grey[700] : Colors.blue[900],
        foregroundColor: Colors.white,
        side: BorderSide(color: status == 'pending' ? Colors.grey[700]! : Colors.blue[900]!, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        minimumSize: const Size(0, 32),
      ),
    );
  }
}
