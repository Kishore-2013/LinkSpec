import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Domain Selection Screen
/// This screen is shown to newly registered users to select their professional domain.
/// Users MUST select a domain before accessing the main app.
class DomainSelectionScreen extends StatefulWidget {
  const DomainSelectionScreen({Key? key}) : super(key: key);

  @override
  State<DomainSelectionScreen> createState() => _DomainSelectionScreenState();
}

class _DomainSelectionScreenState extends State<DomainSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  
  String? _selectedDomain;
  bool _isLoading = false;

  // Available domains - matches database CHECK constraint
  final List<String> _domains = [
    'Medical',
    'IT/Software',
    'Civil Engineering',
    'Law',
  ];

  // Domain icons for visual appeal
  final Map<String, IconData> _domainIcons = {
    'Medical': Icons.local_hospital,
    'IT/Software': Icons.computer,
    'Civil Engineering': Icons.engineering,
    'Law': Icons.gavel,
  };

  // Domain colors for visual distinction
  final Map<String, Color> _domainColors = {
    'Medical': Colors.red,
    'IT/Software': Colors.blue,
    'Civil Engineering': Colors.orange,
    'Law': Colors.purple,
  };

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveDomainSelection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedDomain == null) {
      _showErrorSnackBar('Please select a domain');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check both currentUser and currentSession
      final user = Supabase.instance.client.auth.currentUser;
      final session = Supabase.instance.client.auth.currentSession;
      
      print('DEBUG: User: ${user?.id}');
      print('DEBUG: Session: ${session?.user.id}');
      
      final userId = user?.id ?? session?.user.id;
      
      if (userId == null) {
        // Try to refresh the session
        await Supabase.instance.client.auth.refreshSession();
        final refreshedUser = Supabase.instance.client.auth.currentUser;
        
        if (refreshedUser == null) {
          throw Exception('User not authenticated. Please sign in again.');
        }
      }

      final finalUserId = Supabase.instance.client.auth.currentUser!.id;

      // Save profile with domain selection
      await Supabase.instance.client.from('profiles').insert({
        'id': finalUserId,
        'full_name': _fullNameController.text.trim(),
        'domain_id': _selectedDomain,
        'bio': _bioController.text.trim().isEmpty 
            ? null 
            : _bioController.text.trim(),
      });

      if (!mounted) return;

      // Navigate to home screen
      Navigator.of(context).pushReplacementNamed('/home');
      
    } on PostgrestException catch (e) {
      print('DEBUG: PostgrestException: ${e.message}');
      _showErrorSnackBar('Database error: ${e.message}');
    } on AuthException catch (e) {
      print('DEBUG: AuthException: ${e.message}');
      _showErrorSnackBar('Authentication error: ${e.message}');
    } catch (e) {
      print('DEBUG: General error: $e');
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2EE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    
                    // Logo or App Name
                    const Icon(
                      Icons.business_center,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Welcome to LinkSpec',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Complete your profile to get started',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    // Full Name Field
                    TextFormField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: const Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // Domain Selection
                    Text(
                      'Select Your Professional Domain',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      'You can only connect with professionals in your domain',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Domain Cards
                    ...(_domains.map((domain) => _buildDomainCard(domain))),
                    
                    const SizedBox(height: 24),
                    
                    // Bio Field (Optional)
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: 'Bio (Optional)',
                        hintText: 'Tell us about yourself',
                        prefixIcon: const Icon(Icons.edit_note),
                      ),
                      maxLines: 3,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveDomainSelection,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Continue to LinkSpec',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDomainCard(String domain) {
    final isSelected = _selectedDomain == domain;
    final color = _domainColors[domain] ?? Colors.grey;
    final icon = _domainIcons[domain] ?? Icons.work;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDomain = domain;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  domain,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
