import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
  String? _coverUrl; // separate so we can update it live

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profileData = await SupabaseService.getCurrentUserProfile();
      if (profileData != null) {
        final profile = UserProfile.fromJson(profileData);
        final counts = await SupabaseService.getConnectionCounts(profile.id);
        final posts = await SupabaseService.getPostsByUser(userId: profile.id, limit: 3);
        setState(() {
          _profile = profile;
          _bioController.text = profile.bio ?? '';
          _nameController.text = profile.fullName;
          _followersCount = counts['followers'] ?? 0;
          _followingCount = counts['following'] ?? 0;
          _userPosts = posts;
          _coverUrl = profileData['cover_url'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
          const SnackBar(content: Text('Profile updated!'), backgroundColor: Colors.green),
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
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (picked == null) return;
    setState(() => _isUploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await SupabaseService.uploadAvatar(bytes, 'avatar.jpg');
      setState(() => _profile = _profile?.copyWith(avatarUrl: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated!'), backgroundColor: Colors.green),
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
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
    if (picked == null) return;
    setState(() => _isUploadingCover = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await SupabaseService.uploadCoverPhoto(bytes, 'cover.jpg');
      setState(() => _coverUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover photo updated!'), backgroundColor: Colors.green),
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
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'e.g. Flutter, Design'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() { _profile = _profile?.copyWith(skills: [..._profile!.skills, controller.text.trim()]); });
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
    final roleC = TextEditingController(), companyC = TextEditingController(), durC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Experience'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: roleC, decoration: const InputDecoration(hintText: 'Role')),
          TextField(controller: companyC, decoration: const InputDecoration(hintText: 'Company')),
          TextField(controller: durC, decoration: const InputDecoration(hintText: 'Duration (e.g. 2021 - Present)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (roleC.text.trim().isNotEmpty) {
                setState(() { _profile = _profile?.copyWith(experience: [..._profile!.experience, {'role': roleC.text.trim(), 'company': companyC.text.trim(), 'duration': durC.text.trim()}]); });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addEducation() {
    final degC = TextEditingController(), instC = TextEditingController(), durC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Education'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: degC, decoration: const InputDecoration(hintText: 'Degree')),
          TextField(controller: instC, decoration: const InputDecoration(hintText: 'Institution')),
          TextField(controller: durC, decoration: const InputDecoration(hintText: 'Duration')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (degC.text.trim().isNotEmpty) {
                setState(() { _profile = _profile?.copyWith(education: [..._profile!.education, {'degree': degC.text.trim(), 'institution': instC.text.trim(), 'duration': durC.text.trim()}]); });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
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
      backgroundColor: const Color(0xFFF4F2EE),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: CustomScrollView(
          slivers: [
            // ── Full header: cover + avatar + info in ONE stack ──────────
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── White info card (sits below cover) ─────────────────
                  Column(
                    children: [
                      // Cover photo area (200px tall)
                      GestureDetector(
                        onTap: _pickCover,
                        child: SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _coverUrl != null
                                  ? Image.network(_coverUrl!, fit: BoxFit.cover)
                                  : Image.network(
                                      'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=2070&auto=format&fit=crop',
                                      fit: BoxFit.cover,
                                    ),
                              if (_isUploadingCover)
                                Container(
                                  color: Colors.black45,
                                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                )
                              else
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Change cover', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              // Back button top-left
                              Positioned(
                                top: 12,
                                left: 12,
                                child: SafeArea(
                                  child: GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white.withOpacity(0.85),
                                      radius: 18,
                                      child: const Icon(Icons.arrow_back, size: 18, color: Colors.black87),
                                    ),
                                  ),
                                ),
                              ),
                              // Edit & Logout buttons top-right
                              Positioned(
                                top: 12,
                                right: 12,
                                child: SafeArea(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.white.withOpacity(0.85),
                                        radius: 18,
                                        child: IconButton(
                                          icon: Icon(
                                            _isEditing ? Icons.check : Icons.edit,
                                            size: 18,
                                            color: _isEditing ? Colors.green : Colors.black87,
                                          ),
                                          onPressed: _isEditing ? _updateProfile : () => setState(() => _isEditing = true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        backgroundColor: Colors.white.withOpacity(0.85),
                                        radius: 18,
                                        child: IconButton(
                                          icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                                          onPressed: () async {
                                            await Supabase.instance.client.auth.signOut();
                                            if (mounted) {
                                              Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // White info section — top padding leaves room for avatar
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
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
                              Text(_profile?.fullName ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                _profile?.domainId.toUpperCase() ?? '',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildStat(_followersCount, 'Followers'),
                                Container(width: 1, height: 28, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 20)),
                                _buildStat(_followingCount, 'Following'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isEditing)
                              TextField(
                                controller: _bioController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Write something about yourself...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              )
                            else if (_profile?.bio != null && _profile!.bio!.isNotEmpty)
                              Text(_profile!.bio!, style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87)),
                            if (_isEditing) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => setState(() => _isEditing = false),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Avatar overlapping cover/card boundary ──────────────
                  Positioned(
                    top: 200 - 60, // sits half on cover, half on white card
                    left: 20,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.blue[50],
                              backgroundImage: _profile?.avatarUrl != null
                                  ? NetworkImage(_profile!.avatarUrl!)
                                  : null,
                              child: _profile?.avatarUrl == null
                                  ? Text(
                                      _profile?.fullName[0].toUpperCase() ?? 'U',
                                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue),
                                    )
                                  : null,
                            ),
                          ),
                          if (_isUploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black45),
                                child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                              ),
                            ),
                          if (!_isUploadingAvatar)
                            // Camera badge
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Activity ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildSection(
                title: 'Activity',
                content: _userPosts.isEmpty
                    ? const Text('No recent activity', style: TextStyle(color: Colors.grey))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _userPosts.map((post) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Posted ${post['created_at'].toString().substring(0, 10)}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            ],
                          ),
                        )).toList(),
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

  Widget _buildStat(int count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildSection({required String title, required Widget content, VoidCallback? onAdd}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (onAdd != null)
                IconButton(icon: const Icon(Icons.add, size: 20, color: Colors.blue), onPressed: onAdd, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
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
        if (_isEditing)
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () {
            setState(() { final l = [..._profile!.experience]; l.removeAt(index); _profile = _profile!.copyWith(experience: l); });
          }),
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
        if (_isEditing)
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () {
            setState(() { final l = [..._profile!.education]; l.removeAt(index); _profile = _profile!.copyWith(education: l); });
          }),
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
}
