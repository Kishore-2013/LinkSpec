import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/aw_logo.dart';
import '../widgets/clay_container.dart';
import '../services/linkspec_notify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/domain_provider.dart';
import '../services/supabase_service.dart';

/// Domain Selection Screen — Claymorphism design.
/// Receives optional route argument `{'fullName': String}` from the sign-up flow
/// to pre-populate the Full Name field so users don't have to type it twice.
class DomainSelectionScreen extends ConsumerStatefulWidget {
  final String? fullName;
  const DomainSelectionScreen({Key? key, this.fullName}) : super(key: key);

  @override
  ConsumerState<DomainSelectionScreen> createState() => _DomainSelectionScreenState();
}

class _DomainSelectionScreenState extends ConsumerState<DomainSelectionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _selectedDomain;
  bool _isLoading = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Domains matching the 15-domain system
  final List<Map<String, dynamic>> _domains = [
    {'id': 'Software Development',           'icon': Icons.code,                  'color': const Color(0xFF1565C0)},
    {'id': 'AI, Data & Analytics',           'icon': Icons.auto_awesome,          'color': const Color(0xFF6A1B9A)},
    {'id': 'Data Engineering & Databases',   'icon': Icons.storage,               'color': const Color(0xFF00838F)},
    {'id': 'Cloud, DevOps & Infrastructure', 'icon': Icons.cloud_queue,           'color': const Color(0xFF0277BD)},
    {'id': 'Cybersecurity & Risk',           'icon': Icons.security,              'color': const Color(0xFFC62828)},
    {'id': 'Networking & IT Support',        'icon': Icons.router,                'color': const Color(0xFF00695C)},
    {'id': 'Business, Product & Management', 'icon': Icons.business_center,       'color': const Color(0xFF558B2F)},
    {'id': 'Finance, Risk & Compliance',     'icon': Icons.account_balance,       'color': const Color(0xFF2E7D32)},
    {'id': 'Healthcare & Life Sciences',     'icon': Icons.local_hospital,        'color': const Color(0xFFE53935)},
    {'id': 'Core Engineering',               'icon': Icons.engineering,           'color': const Color(0xFFE65100)},
    {'id': 'Agriculture & Environmental',    'icon': Icons.eco,                   'color': const Color(0xFF388E3C)},
    {'id': 'Design & Creative',              'icon': Icons.palette,               'color': const Color(0xFFAD1457)},
    {'id': 'Sales, Marketing & CRM',         'icon': Icons.campaign,              'color': const Color(0xFFFF6F00)},
    {'id': 'ERP & Enterprise Systems',       'icon': Icons.hub,                   'color': const Color(0xFF4527A0)},
    {'id': 'HR, Operations & Support',       'icon': Icons.people,                'color': const Color(0xFF00897B)},
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
    // Pre-fill name from sign-up arguments
    if (_fullNameController.text.isEmpty) {
      if (widget.fullName != null) {
        _fullNameController.text = widget.fullName!;
      } else {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['fullName'] != null) {
          _fullNameController.text = args['fullName'] as String;
        }
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
      LinkSpecNotify.show(context, 'Ohh! no, we still need you to pick a professional domain before you can enter!', LinkSpecNotifyType.warning);
      return;
    }
    setState(() => _isLoading = true);

    try {
      // 1. NULL SAFETY GUARD: Ensure we have a valid user session
      final client = Supabase.instance.client;
      var user = client.auth.currentUser;
      
      if (user == null) {
        // Attempt one-time refresh if session is just stale
        try {
          await client.auth.refreshSession();
          user = client.auth.currentUser;
        } catch (_) {
          // Refresh failed
        }
      }

      if (user == null) {
        if (mounted) {
          LinkSpecNotify.show(context, 'Ohh! no, your session timed out. Could you please try the verification again?', LinkSpecNotifyType.warning);
          context.go('/auth');
        }
        return;
      }

      // 2. VALIDATE email — profiles_dim.email is NOT NULL
      final email = user.email;
      if (email == null || email.isEmpty) {
        if (mounted) {
          LinkSpecNotify.show(
            context,
            'Ohh! no, we couldn\'t find your email address. Please sign in again.',
            LinkSpecNotifyType.warning,
          );
          context.go('/auth');
        }
        return;
      }

      // 3. SAVE PROFILE with professional sync (upsert prevents duplicates)
      await client.from('profiles_dim').upsert({
        'id': user.id,
        'email': email,                                          // ✅ Required — NOT NULL
        'full_name': _fullNameController.text.trim(),
        'mother_domain': _selectedDomain,
        'domain_id': _selectedDomain,
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      });

      // Update domain provider for immediate feed refresh
      ref.read(currentDomainProvider.notifier).state = _selectedDomain!;

      if (!mounted) return;
      // SUCCESS! Move to home feed
      context.go('/home');
    } on PostgrestException catch (e) {
      if (mounted) LinkSpecNotify.show(context, 'Ohh! no, we hit a database snag: ${e.message}', LinkSpecNotifyType.warning);
      debugPrint('DomainSelection Error (Postgrest): ${e.message} | ${e.details}');
    } on AuthException catch (e) {
      if (mounted) LinkSpecNotify.show(context, 'Ohh! no, there was an authentication hiccup: ${e.message}', LinkSpecNotifyType.warning);
      debugPrint('DomainSelection Error (Auth): ${e.message}');
    } catch (e) {
      if (mounted) LinkSpecNotify.show(context, 'Ohh! no, we hit a snag: ${e.toString()}', LinkSpecNotifyType.warning);
      debugPrint('DomainSelection Error (Unexpected): $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    LinkSpecNotify.show(
      context, 
      msg, 
      isError ? LinkSpecNotifyType.error : LinkSpecNotifyType.success
    );
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
                            'You\'ll unite with professionals in your selected field',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          const SizedBox(height: 16),

                          // ── Domain Dropdown ──────────────────────────────
                          Builder(builder: (_) {
                            final selected = _domains.firstWhere(
                              (d) => d['id'] == _selectedDomain,
                              orElse: () => <String, dynamic>{},
                            );
                            final selectedColor = selected.isNotEmpty
                                ? selected['color'] as Color
                                : Colors.blue[400]!;

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
                              child: DropdownButtonFormField<String>(
                                value: _selectedDomain,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  labelText: 'Professional Domain',
                                  labelStyle: TextStyle(
                                    color: selectedColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: Icon(
                                    selected.isNotEmpty
                                        ? selected['icon'] as IconData
                                        : Icons.work_outline,
                                    color: selectedColor,
                                    size: 20,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                                  errorStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.6,
                                  ),
                                ),
                                hint: const Text(
                                  'Choose your domain…',
                                  style: TextStyle(color: Color(0xFFAFC6E0), fontSize: 14),
                                ),
                                dropdownColor: const Color(0xFFF0F6FF),
                                borderRadius: BorderRadius.circular(20),
                                icon: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: selectedColor),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1A2740),
                                ),
                                validator: (v) =>
                                    v == null ? 'Please select your professional domain' : null,
                                onChanged: (val) => setState(() => _selectedDomain = val),
                                items: _domains.map((d) {
                                  final dId = d['id'] as String;
                                  final dIcon = d['icon'] as IconData;
                                  final dColor = d['color'] as Color;
                                  return DropdownMenuItem<String>(
                                    value: dId,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: dColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(dIcon, color: dColor, size: 16),
                                        ),
                                        const SizedBox(width: 10),
                                        Flexible(
                                          child: Text(
                                            dId,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1A2740),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }),
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
                                        'Continue to linkspec  →',
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

