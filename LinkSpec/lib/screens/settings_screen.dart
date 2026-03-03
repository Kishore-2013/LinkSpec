import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_l10n.dart';
import '../providers/theme_provider.dart';
import '../services/supabase_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  const SettingsScreen({Key? key, this.onBack}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedCategory = 'account_prefs';
  final List<Map<String, dynamic>> _categories = [
    {'key': 'account_prefs', 'icon': Icons.person_outlined},
    {'key': 'sign_security', 'icon': Icons.lock_outlined},
  ];

  bool _darkMode = false;
  bool _twoFactor = false;

  // Real user data loaded from Supabase
  String _userEmail = '';
  String _userPhone = ''; 
  String _userDisabilityStatus = '';
  bool _isVerificationsLoading = true;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _headlineController = TextEditingController();
  final _industryController = TextEditingController();
  bool _isSavingProfile = false;

  @override
  void initState() {
    super.initState();
    _darkMode = ref.read(themeProvider);
    _loadInitialProfileData();
  }

  /// Shorthand translator using the currently selected language.
  String _t(String key) => AppL10n.t(key, ref.watch(languageProvider));

  Future<void> _loadInitialProfileData() async {
    try {
      final profile = await SupabaseService.getCurrentUserProfile();
      // Real email comes from Supabase Auth, not the profile table
      final authEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
      if (profile != null) {
        final fullName = profile['full_name'] as String? ?? '';
        final names = fullName.split(' ');
        _firstNameController.text = names.isNotEmpty ? names[0] : '';
        _lastNameController.text = names.length > 1 ? names.sublist(1).join(' ') : '';
        _headlineController.text = profile['bio'] as String? ?? '';
        _industryController.text = (profile['industry'] as String?) ?? (profile['domain_id'] as String?) ?? '';
        if (mounted) {
          setState(() {
            _userEmail = authEmail;
            // Phone is not collected from users; leave empty
            _userPhone = (profile['phone'] as String?)?.trim() ?? '';
            _userDisabilityStatus = (profile['disability_status'] as String?)?.trim() ?? '';
            _isVerificationsLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _userEmail = authEmail; _isVerificationsLoading = false; });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isVerificationsLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSavingProfile = true);
    try {
      final fullName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
      await SupabaseService.updateProfile(
        fullName: fullName,
        bio: _headlineController.text,
      );
      
      if (mounted) {
        _showFeedback('Profile updated successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showFeedback('Error updating profile: $e');
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _headlineController.dispose();
    _industryController.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _navigateToDetail(String title, Widget content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
            backgroundColor: Theme.of(context).cardColor,
            elevation: 0,
          ),
          body: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.blue),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: isWideScreen ? _buildWideLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1128),
        margin: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sidebar
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _categories.map((cat) => _buildCategoryTile(cat)).toList(),
              ),
            ),
            const SizedBox(width: 24),
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_t(_selectedCategory), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
                    const SizedBox(height: 16),
                    _buildCategoryContent(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return ListView(
      children: _categories.map((cat) {
        final key = cat['key'] as String;
        return ListTile(
          leading: Icon(cat['icon']),
          title: Text(_t(key)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            setState(() {
              _selectedCategory = key;
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  appBar: AppBar(
                    title: Text(_t(key), style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color)),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    surfaceTintColor: Colors.transparent,
                  ),
                  body: SingleChildScrollView(child: _buildCategoryContent()),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> category) {
    final key = category['key'] as String;
    final bool isSelected = _selectedCategory == key;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? Colors.blue[700]! : Colors.transparent,
              width: 4,
            ),
          ),
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(category['icon'], color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).hintColor),
            const SizedBox(width: 12),
            Text(
              _t(key),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).primaryColor : Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryContent() {
    switch (_selectedCategory) {
      case 'account_prefs':
        return _buildAccountPreferences();
      case 'sign_security':
        return _buildSignInSecurity();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleLarge?.color)),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile(String title, {String? trailing, Widget? trailingWidget, bool showArrow = true, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () => _showFeedback('$title updated'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else if (trailing != null) ...[
              Text(trailing, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(width: 8),
            ],
            if (showArrow && trailingWidget == null) Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPreferences() {
    return Column(
      children: [
        _buildSection(_t('profile_info'), [
          _buildSettingTile(_t('full_name'), onTap: () => _navigateToDetail(_t('full_name'), _buildProfileEditForm())),
          _buildSettingTile('Personal demographic information', onTap: () => _navigateToDetail('Demographics', _buildDemographicsForm())),
          _buildSettingTile('Verifications', onTap: () => _navigateToDetail('Verifications', _buildVerificationsList())),
        ]),
        _buildSection(_t('display'), [
          _buildSettingTile(
            _t('dark_mode'),
            trailingWidget: Switch(
              value: ref.watch(themeProvider),
              onChanged: (val) {
                setState(() => _darkMode = val);
                ref.read(themeProvider.notifier).state = val;
              },
              activeColor: Colors.blue[700],
            ),
          ),
        ]),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                // Properly sign out: clear cache, invalidate Supabase session,
                // then replace entire navigation stack so back button cannot
                // return the user to the home feed.
                SupabaseService.clearCache();
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Text(_t('sign_out'), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildProfileEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextField('First Name', _firstNameController),
          const SizedBox(height: 16),
          _buildTextField('Last Name', _lastNameController),
          const SizedBox(height: 16),
          _buildTextField('Headline', _headlineController),
          const SizedBox(height: 16),
          // Industry is read-only and follows domain
          _buildTextField('Industry', _industryController, readOnly: true),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSavingProfile ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: _isSavingProfile 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, dynamic controllerOrValue, {bool readOnly = false}) {
    return TextField(
      controller: controllerOrValue is TextEditingController 
          ? controllerOrValue 
          : TextEditingController(text: controllerOrValue.toString()),
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey[100] : null,
      ),
    );
  }

  Widget _buildSignInSecurity() {
    return Column(
      children: [
        _buildSection('Account access', [
          _buildSettingTile(
            'Email addresses',
            trailing: _userEmail.isNotEmpty ? _userEmail : 'Not set',
            onTap: () => _navigateToDetail('Email addresses', _buildEmailManagement()),
          ),
          _buildSettingTile(
            'Phone numbers',
            trailing: _userPhone.isNotEmpty ? _userPhone : 'Not added',
            onTap: () => _navigateToDetail('Phone numbers', _buildPhoneManagement()),
          ),
          _buildSettingTile('Change password', onTap: () => _navigateToDetail('Change password', _buildChangePasswordForm())),
        ]),
      ],
    );
  }

  Widget _buildChangePasswordForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextField('Current Password', ''),
          const SizedBox(height: 16),
          _buildTextField('New Password', ''),
          const SizedBox(height: 16),
          _buildTextField('Confirm New Password', ''),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicsForm() {
    // Use persistent controllers seeded with current values so Save captures them
    final disabilityController = TextEditingController(text: _userDisabilityStatus);
    bool isSaving = false;
    return StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            TextField(
              controller: disabilityController,
              decoration: InputDecoration(
                labelText: 'Disability status (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setLocal(() => isSaving = true);
                try {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId != null) {
                    await Supabase.instance.client.from('profiles').update({
                      'disability_status': disabilityController.text.trim(),
                    }).eq('id', userId);
                    // Update local state so next open reflects saved values
                    if (mounted) {
                      setState(() {
                        _userDisabilityStatus = disabilityController.text.trim();
                      });
                    }
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) _showFeedback('Demographics saved!');
                } catch (e) {
                  if (mounted) _showFeedback('Error saving: $e');
                } finally {
                  setLocal(() => isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Demographics', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationsList() {
    if (_isVerificationsLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    return ListView(
      shrinkWrap: true,
      children: [
        // Email — always shown; verified = user has a confirmed auth account
        ListTile(
          leading: const Icon(Icons.email, color: Colors.blue),
          title: const Text('Email address'),
          subtitle: Text(_userEmail.isNotEmpty ? _userEmail : 'Not set'),
          trailing: _userEmail.isNotEmpty
              ? Icon(Icons.check_circle, color: Colors.blue[700])
              : const Icon(Icons.cancel_outlined, color: Colors.grey),
        ),
        // Phone — only show as verified if we actually have a number on file
        ListTile(
          leading: const Icon(Icons.phone, color: Colors.grey),
          title: const Text('Phone number'),
          subtitle: Text(_userPhone.isNotEmpty ? _userPhone : 'Not added'),
          trailing: _userPhone.isNotEmpty
              ? Icon(Icons.check_circle, color: Colors.blue[700])
              : TextButton(
                  onPressed: () => _showFeedback('Phone verification coming soon'),
                  child: const Text('Add', style: TextStyle(color: Colors.blue)),
                ),
        ),
      ],
    );
  }

  Widget _buildEmailManagement() {
    return Column(
      children: [
        ListTile(
          title: Text(_userEmail.isNotEmpty ? _userEmail : 'No email set'),
          subtitle: const Text('Primary email'),
          trailing: _userEmail.isNotEmpty ? Icon(Icons.check_circle, color: Colors.blue[700]) : null,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add email address'),
          onTap: () => _showFeedback('Contact support to change your email'),
        ),
      ],
    );
  }

  Widget _buildPhoneManagement() {
    return Column(
      children: [
        if (_userPhone.isNotEmpty)
          ListTile(
            title: Text(_userPhone),
            subtitle: const Text('Primary phone'),
            trailing: Icon(Icons.check_circle, color: Colors.blue[700]),
          )
        else
          const ListTile(
            title: Text('No phone number added'),
            subtitle: Text('Phone number is optional'),
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add phone number'),
          onTap: () => _showFeedback('Phone number feature coming soon'),
        ),
      ],
    );
  }

  Widget _buildSessionsList() {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.laptop),
          title: const Text('Windows ⋅ Chrome'),
          subtitle: const Text('Bangalore, India ⋅ Current session'),
        ),
        ListTile(
          leading: const Icon(Icons.phone_android),
          title: const Text('iPhone 13 ⋅ App'),
          subtitle: const Text('Bangalore, India ⋅ 2 hours ago'),
          trailing: TextButton(onPressed: () {}, child: const Text('Sign out')),
        ),
      ],
    );
  }
}
