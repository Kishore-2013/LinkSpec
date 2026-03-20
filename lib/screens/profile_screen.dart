import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../services/linkspec_notify.dart';
import '../utils/web_utils.dart';
import '../models/user_profile.dart';
import '../config/app_constants.dart';
import 'user_posts_insights_screen.dart';
import 'member_profile_screen.dart';
import '../widgets/post_card.dart' show ViewTracker;
import '../providers/saved_posts_provider.dart';
import '../services/verification_service.dart';
import '../widgets/verification_viewer.dart';
import 'dart:async';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart'; // for Clipboard if needed
import 'package:go_router/go_router.dart';
import '../providers/scroll_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // Optional; if null, defaults to current user
  final VoidCallback? onBack;
  final ScrollController? scrollController;
  const ProfileScreen({Key? key, this.userId, this.onBack, this.scrollController}) : super(key: key);

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
  bool _isOwnProfile = true;
  bool _isGuestMode = false;
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
    final currentUserId = SupabaseService.getCurrentUserId();
    final targetUserId = widget.userId ?? currentUserId;
    if (targetUserId == null) return;

    _profileSubscription = SupabaseService.subscribeToProfileChanges(targetUserId, (payload) {
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
    final currentUserId = SupabaseService.getCurrentUserId();
    final targetUserId = widget.userId ?? currentUserId;

    if (targetUserId == null) {
      if (mounted) setState(() {
        _isLoading = false;
        _isGuestMode = true;
        _isOwnProfile = false;
      });
      return;
    }

    _isOwnProfile = (targetUserId == currentUserId);
    _isGuestMode = (currentUserId == null);

    try {
      final profileData = await SupabaseService.getUserProfile(targetUserId);
      
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

        // Set page title for Web SEO/Ux
        if (kIsWeb) {
          SystemChrome.setApplicationSwitcherDescription(
            ApplicationSwitcherDescription(
              label: '${profile.fullName} | LinkSpec Profile',
              primaryColor: Theme.of(context).primaryColor.value,
            ),
          );
        }
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
        LinkSpecNotify.show(
          context, 
          'Profile updated successfully', 
          LinkSpecNotifyType.success
        );
      }
    } catch (e) {
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Error updating profile: $e', 
          LinkSpecNotifyType.error
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
    
    final bytes = result.files.single.bytes!;
    final name = result.files.single.name;
    final ext = name.split('.').last.toLowerCase();

    // 1. Type Validation
    if (!AppConstants.allowedImageExtensions.contains(ext)) {
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Unsupported file format. Please upload JPG or PNG.', 
          LinkSpecNotifyType.error
        );
      }
      return;
    }

    // 2. Size Validation
    if (bytes.length > AppConstants.maxMediaSize) {
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'File size exceeds limit (Max: 10MB). Please upload a smaller file.', 
          LinkSpecNotifyType.error
        );
      }
      return;
    }

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await SupabaseService.uploadAvatar(bytes, name);
      setState(() {
        _profile = _profile?.copyWith(avatarUrl: url);
      });
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Avatar updated!', 
          LinkSpecNotifyType.success
        );
      }
    } catch (e) {
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Upload failed: $e', 
          LinkSpecNotifyType.error
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
    
    final bytes = result.files.single.bytes!;
    final name = result.files.single.name;
    final ext = name.split('.').last.toLowerCase();

    // 1. Type Validation
    if (!AppConstants.allowedImageExtensions.contains(ext)) {
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Unsupported file format. Please upload JPG or PNG.', 
          LinkSpecNotifyType.error
        );
      }
      return;
    }

    // 2. Size Validation
    if (bytes.length > AppConstants.maxMediaSize) {
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'File size exceeds limit (Max: 10MB). Please upload a smaller file.', 
          LinkSpecNotifyType.error
        );
      }
      return;
    }

    setState(() => _isUploadingCover = true);
    try {
      final url = await SupabaseService.uploadCoverPhoto(bytes, name);
      setState(() => _coverUrl = url);
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Cover photo updated!', 
          LinkSpecNotifyType.success
        );
      }
    } catch (e) {
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Upload failed: $e', 
          LinkSpecNotifyType.error
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingCover = false);
    }
  }

  void _shareProfile() {
    if (_profile == null) return;
    final url = kIsWeb 
        ? '${Uri.base.origin}/profile/${_profile!.id}'
        : 'https://applywizz.com/profile/${_profile!.id}'; // Use generic URL for mobile
    
    Share.share('Check out ${_profile!.fullName}\'s professional profile on LinkSpec: $url');
  }

  Widget _buildRestrictedSection({required Widget child, required String message}) {
    if (!_isGuestMode) return child;

    return Stack(
      children: [
        AbsorbPointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: child,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.3),
                  Colors.white.withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 40, color: Colors.blue),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Sign In'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Optional Back Context Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
                onPressed: () => context.pop(),
              ),
              const Text('Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProfile,
            child: CustomScrollView(
              controller: ref.read(globalScrollControllerProvider),
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
                        onTap: _isOwnProfile ? _pickCover : null,
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
                              if (_isOwnProfile)
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
                             _buildRestrictedSection(
                               message: 'Sign in to view full stats',
                               child: Row(
                                 children: [
                                   _buildStat(_connectionsCount, 'Unites', onTap: _isGuestMode ? null : _showConnectionsDialog),
                                   const SizedBox(width: 24),
                                   _buildStat(_followersCount, 'Followers'),
                                   const SizedBox(width: 24),
                                   _buildStat(_followingCount, 'Following'),
                                 ],
                               ),
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
                      onTap: _isOwnProfile ? _pickAvatar : null,
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
                        _buildFloatingAction(Icons.share, _shareProfile),
                        if (_isOwnProfile) ...[
                          const SizedBox(width: 8),
                          _buildFloatingAction(Icons.settings, () => context.go('/settings')),
                          const SizedBox(width: 8),
                          _buildFloatingAction(_isEditing ? Icons.check : Icons.edit, _isEditing ? _updateProfile : () => setState(() => _isEditing = true)),
                          const SizedBox(width: 8),
                          _buildFloatingAction(Icons.logout, () async {
                             ViewTracker.clear();
                             ref.read(savedPostsProvider.notifier).clear();
                             await SupabaseService.signOut();
                             if (mounted) context.go('/login');
                          }, color: Colors.redAccent),
                        ],
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
                    child: _isOwnProfile ? _buildGetVerifiedButton() : const SizedBox.shrink(),
                  ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Activity ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildRestrictedSection(
                message: 'Sign in to view user activity',
                child: _buildSection(
                  title: 'Activity',
                  onHeaderTap: _isGuestMode ? null : () {
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
                                onPressed: _isGuestMode ? null : () {
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
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Experience ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildRestrictedSection(
                message: 'Sign in to view full experience',
                child: _buildSection(
                  title: 'Experience',
                  onAdd: _isEditing ? _addExperience : null,
                  content: _profile?.experience.isEmpty ?? true
                      ? const Text('No experience added yet', style: TextStyle(color: Colors.grey))
                      : Column(children: List.generate(_profile!.experience.length, (i) => _buildExpItem(_profile!.experience[i], i))),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Education ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildRestrictedSection(
                message: 'Sign in to view education',
                child: _buildSection(
                  title: 'Education',
                  onAdd: _isEditing ? _addEducation : null,
                  content: _profile?.education.isEmpty ?? true
                      ? const Text('No education added yet', style: TextStyle(color: Colors.grey))
                      : Column(children: List.generate(_profile!.education.length, (i) => _buildEduItem(_profile!.education[i], i))),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Projects ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildRestrictedSection(
                message: 'Sign in to view projects',
                child: _buildSection(
                  title: 'Projects',
                  onAdd: _isEditing ? _addProject : null,
                  content: _profile?.projects.isEmpty ?? true
                      ? const Text('No projects added yet', style: TextStyle(color: Colors.grey))
                      : Column(children: List.generate(_profile!.projects.length, (i) => _buildProjItem(_profile!.projects[i], i))),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Skills ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildRestrictedSection(
                message: 'Sign in to view skills',
                child: _buildSection(
                  title: 'Skills',
                  onAdd: _isEditing ? _addSkill : null,
                  content: _profile?.skills.isEmpty ?? true
                      ? const Text('No skills added yet', style: TextStyle(color: Colors.grey))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(_profile!.skills.length, (i) {
                            final skill = _profile!.skills[i];
                            return InputChip(
                              label: Text(skill),
                              backgroundColor: Colors.blue[50],
                              labelStyle: const TextStyle(color: Colors.blue, fontSize: 12),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onPressed: (_isEditing || _isGuestMode) ? null : () => _startVerification(skill: skill),
                              onDeleted: _isEditing ? () {
                                setState(() {
                                  final s = [..._profile!.skills];
                                  s.removeAt(i);
                                  _profile = _profile!.copyWith(skills: s);
                                });
                              } : null,
                            );
                          }),
                        ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    ),
      ],
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

  Future<void> _startVerification({String? skill}) async {
    if (_profile == null) return;

    final userId = SupabaseService.getCurrentUserId();
    if (userId == null) return;

    // Domain to Fermion Env mapping (new 15-domain system)
    final Map<String, String> domainToEnv = {
      'Healthcare & Life Sciences':    'medc1',
      'Software Development':          'sde1',
      'AI, Data & Analytics':          'sde1',
      'Data Engineering & Databases':  'sde1',
      'Cloud, DevOps & Infrastructure':'sde1',
      'Cybersecurity & Risk':          'sde1',
      'Networking & IT Support':       'sde1',
      'Core Engineering':              'de2',
      'Finance, Risk & Compliance':    'bie2',
      'Business, Product & Management':'ba2',
      // Legacy fallbacks (for existing users with old domain values)
      'Medical':          'medc1',
      'IT/Software':      'sde1',
      'Civil Engineering':'de2',
      'Law':              'bie2',
      'Business':         'ba2',
    };

    final env = domainToEnv[_profile!.domainId] ?? 'default';
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email;
    final name = _profile?.fullName;

    // Show mandatory warning dialog before proceeding
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Manual Login Requirement', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are about to be redirected to Fermion for verification.'),
            const SizedBox(height: 12),
            const Text('IMPORTANT:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const Text('You MUST sign in or sign up on Fermion using this exact email:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)),
              child: SelectableText(email ?? 'No email found', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            ),
            const SizedBox(height: 12),
            const Text('Using any other email will result in your verification failing.', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('I Understand, Proceed'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    final url = VerificationService.getRedirectUrl(
      userId: userId,
      env: env,
      skill: skill,
      email: email,
      name: name,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationViewer(
          url: url,
          onComplete: () {
            LinkSpecNotify.show(
              context, 
              'Verification in progress. Please wait a moment for the badge to appear.', 
              LinkSpecNotifyType.info
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
