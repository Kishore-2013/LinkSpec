import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/aw_logo.dart';
import '../widgets/clay_container.dart';

/// Login / Sign-Up Screen — Claymorphism design.
/// Sign-Up collects Name + Email + Password, then navigates to domain selection.
/// Sign-In authenticates and goes straight to /home (or /domain-selection if no profile yet).
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // ── Sign Up ──────────────────────────────────────────────────────
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          emailRedirectTo: null,
        );

        if (!mounted) return;

        if (response.user != null && response.session != null) {
          // Authenticated immediately → go to domain selection with prefilled name
          Navigator.of(context).pushReplacementNamed(
            '/domain-selection',
            arguments: {'fullName': _nameController.text.trim()},
          );
        } else if (response.user != null) {
          // Email confirmation required
          _showSnack(
            'Account created! Check your email to verify, then sign in.',
            isError: false,
          );
          // Switch to sign-in mode so they can log in after verifying
          setState(() => _isSignUp = false);
        } else {
          _showSnack('Failed to create account. Please try again.');
        }
      } else {
        // ── Sign In ──────────────────────────────────────────────────────
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) return;

        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          try {
            final profile = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', userId)
                .maybeSingle();

            if (!mounted) return;
            Navigator.of(context).pushReplacementNamed(
              profile == null ? '/domain-selection' : '/home',
            );
          } catch (_) {
            if (mounted) Navigator.of(context).pushReplacementNamed('/domain-selection');
          }
        }
      }
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('An error occurred: $e');
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

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _formKey.currentState?.reset();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
    });
    // Re-fade on mode switch
    _fadeCtrl.forward(from: 0.4);
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: ClayContainer(
                    borderRadius: 40,
                    depth: 14,
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Logo ──────────────────────────────────────
                          const AWLogo(size: 80, showAppName: true, showTagline: true),
                          const SizedBox(height: 36),

                          // ── Heading ────────────────────────────────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: Text(
                              _isSignUp ? 'Create Account' : 'Welcome Back',
                              key: ValueKey(_isSignUp),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF003366),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: Text(
                              _isSignUp
                                  ? 'Join your professional community'
                                  : 'Sign in to your domain feed',
                              key: ValueKey('sub$_isSignUp'),
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 30),

                          // ── Name Field (Sign Up only) ──────────────────
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _isSignUp
                                ? Column(
                                    children: [
                                      _buildClayField(
                                        controller: _nameController,
                                        label: 'Full Name',
                                        icon: Icons.person_outline,
                                        textCapitalization: TextCapitalization.words,
                                        textInputAction: TextInputAction.next,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) return 'Please enter your name';
                                          if (v.trim().length < 2) return 'Name must be at least 2 characters';
                                          return null;
                                        },
                                        autofillHints: [AutofillHints.name],
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // ── Email Field ────────────────────────────────
                          _buildClayField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter your email';
                              if (!v.contains('@')) return 'Please enter a valid email';
                              return null;
                            },
                            autofillHints: [AutofillHints.email],
                          ),
                          const SizedBox(height: 14),

                          // ── Password Field ─────────────────────────────
                          _buildClayField(
                            controller: _passwordController,
                            label: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleAuth(),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              child: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.blue[400],
                                size: 20,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Please enter your password';
                              if (_isSignUp && v.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                            autofillHints: [_isSignUp ? AutofillHints.newPassword : AutofillHints.password],
                          ),
                          const SizedBox(height: 28),

                          // ── Primary Button ──────────────────────────────
                          GestureDetector(
                            onTap: _isLoading ? null : _handleAuth,
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
                                    : Text(
                                        _isSignUp ? 'Create Account  →' : 'Sign In  →',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // ── Divider ────────────────────────────────────
                          Row(children: [
                            Expanded(child: Divider(color: Colors.blue[100])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600)),
                            ),
                            Expanded(child: Divider(color: Colors.blue[100])),
                          ]),
                          const SizedBox(height: 18),

                          // ── Toggle Sign In / Sign Up ────────────────────
                          GestureDetector(
                            onTap: _toggleMode,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              child: Text(
                                _isSignUp
                                    ? 'Already have an account? Sign In'
                                    : "Don't have an account? Sign Up",
                                key: ValueKey('toggle$_isSignUp'),
                                style: const TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
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

  Widget _buildClayField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
    Iterable<String>? autofillHints,
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
        obscureText: obscureText,
        onFieldSubmitted: onSubmitted,
        autofillHints: autofillHints,
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
          suffixIcon: suffixIcon,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          isDense: false,
        ),
      ),
    );
  }
}
