import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    {'key': 'visibility',    'icon': Icons.visibility_outlined},
    {'key': 'notifications', 'icon': Icons.notifications_none},
  ];

  bool _darkMode = false;
  bool _twoFactor = false;
  String _profileVisibility = 'All members';
  bool _syncContacts = false;
  bool _personalizedAds = true;

  // Visibility & Activity toggles
  bool _activeStatus = true;
  bool _shareJobChanges = true;
  bool _mentionsTags = true;

  // Notification toggles
  bool _notifJobSearch = true;
  bool _notifHiring = true;
  bool _notifConnecting = true;
  bool _notifNetwork = true;
  
  // Profile controllers
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
      if (profile != null) {
        final fullName = profile['full_name'] as String? ?? '';
        final names = fullName.split(' ');
        _firstNameController.text = names.isNotEmpty ? names[0] : '';
        _lastNameController.text = names.length > 1 ? names.sublist(1).join(' ') : '';
        _headlineController.text = profile['bio'] as String? ?? '';
        _industryController.text = profile['industry'] as String? ?? 'Technology';
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSavingProfile = true);
    try {
      final fullName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
      await SupabaseService.updateProfile(
        fullName: fullName,
        bio: _headlineController.text,
        industry: _industryController.text,
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
        leading: isWideScreen ? null : IconButton(
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
      case 'visibility':
        return _buildVisibility();
      case 'notifications':
        return _buildNotifications();
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
        _buildSection(_t('gen_prefs'), [
          _buildSettingTile(
            'Sync contacts',
            trailingWidget: Switch(
              value: _syncContacts,
              onChanged: (val) => setState(() => _syncContacts = val),
              activeColor: Colors.blue[700],
            ),
          ),
          _buildSettingTile(
            'Personalized ads',
            trailingWidget: Switch(
              value: _personalizedAds,
              onChanged: (val) => setState(() => _personalizedAds = val),
              activeColor: Colors.blue[700],
            ),
          ),
          _buildSettingTile(_t('profile_photo'), trailing: _t(_profileVisibility == 'All members' ? 'all_members' : _profileVisibility == 'My network' ? 'my_network' : 'only_me'), onTap: () => _showVisibilityPicker()),
        ]),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
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
          _buildTextField('Industry', _industryController),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSavingProfile ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blue[700],
            ),
            child: _isSavingProfile 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, dynamic controllerOrValue) {
    return TextField(
      controller: controllerOrValue is TextEditingController 
          ? controllerOrValue 
          : TextEditingController(text: controllerOrValue.toString()),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showVisibilityPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['All members', 'My network', 'Only me'].map((opt) {
              return ListTile(
                title: Text(opt),
                onTap: () {
                  setState(() => _profileVisibility = opt);
                  Navigator.pop(context);
                },
                trailing: _profileVisibility == opt ? Icon(Icons.check, color: Colors.blue[700]) : null,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSignInSecurity() {
    return Column(
      children: [
        _buildSection('Account access', [
          _buildSettingTile('Email addresses', trailing: 'kishore@example.com', onTap: () => _navigateToDetail('Email addresses', _buildEmailManagement())),
          _buildSettingTile('Phone numbers', trailing: '+91 98765 43210', onTap: () => _navigateToDetail('Phone numbers', _buildPhoneManagement())),
          _buildSettingTile('Change password', onTap: () => _navigateToDetail('Change password', _buildChangePasswordForm())),
          _buildSettingTile('Where you\'re signed in', onTap: () => _navigateToDetail('Active Sessions', _buildSessionsList())),
          _buildSettingTile(
            'Two-factor authentication',
            trailingWidget: Switch(
              value: _twoFactor,
              onChanged: (val) => setState(() => _twoFactor = val),
              activeColor: Colors.blue[700],
            ),
          ),
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
            ),
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibility() {
    return Column(
      children: [
        _buildSection('Visibility of your profile & network', [
          _buildSettingTile('Profile viewing options', trailing: 'Your name and headline', onTap: () => _showProfileViewingOptions()),
          _buildSettingTile('Edit your public profile', onTap: () => _navigateToDetail('Public Profile Settings', _buildPublicProfileSettings())),
          _buildSettingTile('Who can see or download your email address', trailing: 'Connections', onTap: () => _showEmailVisibilityPicker()),
          _buildSettingTile('Connections', trailing: 'On', onTap: () => _showToggleDialog('Connections visibility', 'Allow connections to see your connection list')),
        ]),
        _buildSection('Visibility of your activity', [
          _buildSettingTile(
            'Manage active status',
            trailingWidget: Switch(
              value: _activeStatus,
              onChanged: (val) => setState(() => _activeStatus = val),
              activeColor: Colors.blue[700],
            ),
          ),
          _buildSettingTile(
            'Share job changes from profile',
            trailingWidget: Switch(
              value: _shareJobChanges,
              onChanged: (val) => setState(() => _shareJobChanges = val),
              activeColor: Colors.blue[700],
            ),
          ),
          _buildSettingTile(
            'Mentions or tags',
            trailingWidget: Switch(
              value: _mentionsTags,
              onChanged: (val) => setState(() => _mentionsTags = val),
              activeColor: Colors.blue[700],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildNotifications() {
    return Column(
      children: [
        _buildSection('Notifications you receive', [
          _buildSettingTile(
            'Searching for a job',
            trailingWidget: Switch(
              value: _notifJobSearch,
              onChanged: (val) => setState(() => _notifJobSearch = val),
              activeColor: Colors.blue[700],
            ),
          ),
          _buildSettingTile(
            'Hiring someone',
            trailingWidget: Switch(
              value: _notifHiring,
              onChanged: (val) => setState(() => _notifHiring = val),
              activeColor: Colors.blue[700],
            ),
          ),
          _buildSettingTile(
            'Connecting with others',
            trailingWidget: Switch(
              value: _notifConnecting,
              onChanged: (val) => setState(() => _notifConnecting = val),
              activeColor: Colors.blue[700],
            ),
          ),
          _buildSettingTile(
            'Network updates',
            trailingWidget: Switch(
              value: _notifNetwork,
              onChanged: (val) => setState(() => _notifNetwork = val),
              activeColor: Colors.blue[700],
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildDemographicsForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTextField('Gender', 'Male'),
          const SizedBox(height: 16),
          _buildTextField('Disability status', 'None'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue[700]),
            child: const Text('Save Demographics'),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationsList() {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.email, color: Colors.blue),
          title: const Text('Email verified'),
          subtitle: const Text('kishore@example.com'),
          trailing: Icon(Icons.check_circle, color: Colors.blue[700]),
        ),
        ListTile(
          leading: const Icon(Icons.phone, color: Colors.blue),
          title: const Text('Phone verified'),
          subtitle: const Text('+91 98765 43210'),
          trailing: Icon(Icons.check_circle, color: Colors.blue[700]),
        ),
        ListTile(
          leading: const Icon(Icons.business, color: Colors.blue),
          title: const Text('Work email'),
          subtitle: const Text('kishore@applywizz.com'),
          onTap: () {},
          trailing: const Text('Verify', style: TextStyle(color: Colors.blue)),
        ),
      ],
    );
  }

  Widget _buildEmailManagement() {
    return Column(
      children: [
        ListTile(
          title: const Text('kishore@example.com'),
          subtitle: const Text('Primary email'),
          trailing: Icon(Icons.check_circle, color: Colors.blue[700]),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add email address'),
          onTap: () => _showFeedback('Email added'),
        ),
      ],
    );
  }

  Widget _buildPhoneManagement() {
    return Column(
      children: [
        ListTile(
          title: const Text('+91 98765 43210'),
          subtitle: const Text('Primary phone'),
          trailing: Icon(Icons.check_circle, color: Colors.blue[700]),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('Add phone number'),
          onTap: () => _showFeedback('Phone added'),
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

  Widget _buildPublicProfileSettings() {
    return Column(
      children: [
        _buildSection('Profile visibility', [
          _buildSettingTile('Public visibility', trailingWidget: Switch(value: true, onChanged: (v) {}, activeColor: Colors.blue[700])),
          _buildSettingTile('Headline', trailingWidget: Switch(value: true, onChanged: (v) {}, activeColor: Colors.blue[700])),
          _buildSettingTile('Experience', trailingWidget: Switch(value: true, onChanged: (v) {}, activeColor: Colors.blue[700])),
        ]),
      ],
    );
  }

  void _showProfileViewingOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Your name and headline'), subtitle: const Text('Visible to everyone'), onTap: () => Navigator.pop(context)),
            ListTile(title: const Text('Private profile characteristics'), subtitle: const Text('e.g. Someone at LinkSpec'), onTap: () => Navigator.pop(context)),
            ListTile(title: const Text('Private mode'), subtitle: const Text('No information shared'), onTap: () => Navigator.pop(context)),
          ],
        );
      },
    );
  }

  void _showEmailVisibilityPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Only me', 'First-degree connections', 'Everyone'].map((opt) {
            return ListTile(title: Text(opt), onTap: () => Navigator.pop(context));
          }).toList(),
        );
      },
    );
  }

  void _showToggleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Off')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('On')),
        ],
      ),
    );
  }
}
