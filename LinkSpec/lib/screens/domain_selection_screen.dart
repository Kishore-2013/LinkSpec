import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/aw_logo.dart';
import '../widgets/clay_container.dart';

/// Domain Selection Screen — Claymorphism design.
/// Receives optional route argument `{'fullName': String}` from the sign-up flow
/// to pre-populate the Full Name field so users don't have to type it twice.
class DomainSelectionScreen extends StatefulWidget {
  const DomainSelectionScreen({Key? key}) : super(key: key);

  @override
  State<DomainSelectionScreen> createState() => _DomainSelectionScreenState();
}

class _DomainSelectionScreenState extends State<DomainSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedDomain;
  bool _isLoading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Domains matching the DB CHECK constraint
  final List<Map<String, dynamic>> _domains = [
    {'id': 'Medical',          'icon': Icons.local_hospital,  'color': const Color(0xFFE53935)},
    {'id': 'IT/Software',      'icon': Icons.computer,        'color': const Color(0xFF1565C0)},
    {'id': 'Civil Engineering','icon': Icons.engineering,     'color': const Color(0xFFE65100)},
    {'id': 'Law',              'icon': Icons.gavel,           'color': const Color(0xFF6A1B9A)},
    {'id': 'Business',         'icon': Icons.business_center, 'color': const Color(0xFF00897B)},
    {'id': 'Global',           'icon': Icons.public_rounded,  'color': const Color(0xFF00BFA5)},
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-fill name from sign-up arguments (only on first call)
    if (_fullNameController.text.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['fullName'] != null) {
        _fullNameController.text = args['fullName'] as String;
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveDomainSelection() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDomain == null) {
      _showSnack('Please select your professional domain');
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Ensure session is valid
      var user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        await Supabase.instance.client.auth.refreshSession();
        user = Supabase.instance.client.auth.currentUser;
      }
      if (user == null) throw Exception('Not authenticated. Please sign in again.');

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'full_name': _fullNameController.text.trim(),
        'domain_id': _selectedDomain,
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on PostgrestException catch (e) {
      _showSnack('Database error: ${e.message}');
    } on AuthException catch (e) {
      _showSnack('Auth error: ${e.message}');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.red[700] : Colors.blue[700],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD9E9FF), Color(0xFFB4DAFF), Color(0xFFD9E9FF)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ClayContainer(
                    borderRadius: 40,
                    depth: 14,
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Logo ────────────────────────────────────────
                          const AWLogo(size: 72, showAppName: true, showTagline: false),
                          const SizedBox(height: 8),
                          const Text(
                            'Complete your profile to get started',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5B7EA6), fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 36),

                          // ── Full Name ───────────────────────────────────
                          _sectionLabel('Your Name'),
                          const SizedBox(height: 10),
                          _buildClayField(
                            controller: _fullNameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter your full name';
                              if (v.trim().length < 2) return 'Name must be at least 2 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          // ── Domain Selection ────────────────────────────
                          _sectionLabel('Select Your Domain'),
                          const SizedBox(height: 4),
                          Text(
                            'You\'ll connect with professionals in your selected field',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          const SizedBox(height: 14),

                          ...(_domains.map((d) => _buildDomainTile(d))),
                          const SizedBox(height: 24),

                          // ── Bio (Optional) ──────────────────────────────
                          _sectionLabel('Bio  (optional)'),
                          const SizedBox(height: 10),
                          ClayContainer(
                            borderRadius: 20,
                            depth: -6,
                            emboss: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: TextFormField(
                              controller: _bioController,
                              maxLines: 3,
                              maxLength: 200,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Tell the community about yourself...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                prefixIcon: Icon(Icons.edit_note, color: Colors.blue[400], size: 20),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Continue Button ─────────────────────────────
                          GestureDetector(
                            onTap: _isLoading ? null : _saveDomainSelection,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1565C0),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1565C0).withOpacity(0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Continue to LinkSpec  →',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: Color(0xFF003366),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildDomainTile(Map<String, dynamic> d) {
    final id = d['id'] as String;
    final icon = d['icon'] as IconData;
    final color = d['color'] as Color;
    final isSelected = _selectedDomain == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedDomain = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.12) : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.blue.withOpacity(0.15),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: color.withOpacity(0.18), blurRadius: 12, offset: const Offset(0, 4))]
                : [BoxShadow(color: const Color(0xFF1A2740).withOpacity(0.04), blurRadius: 6)],
          ),
          child: Row(
            children: [
              // Icon pill
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(isSelected ? 0.18 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  id,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : const Color(0xFF1A2740),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: isSelected
                    ? Icon(Icons.check_circle_rounded, color: color, size: 24, key: const ValueKey('checked'))
                    : Icon(Icons.radio_button_unchecked, color: Colors.grey[300], size: 24, key: const ValueKey('unchecked')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClayField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.14),
            blurRadius: 8,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 8,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        validator: validator,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF1A2740),
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.blue[400],
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          errorStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.6,
          ),
          prefixIcon: Icon(icon, color: Colors.blue[400], size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          isDense: false,
        ),
      ),
    );
  }
}
