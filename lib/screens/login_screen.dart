import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../widgets/aw_logo.dart';
import '../services/email_service.dart';
import '../services/supabase_service.dart';
import '../utils/validators.dart';

/// Login / Sign-Up Screen — Minimalistic design.
/// Clean white surface, hairline input borders, single accent colour.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // ─────────────────────────────────────────────────────────────────────────
  // Design tokens — Ultra-Minimalist
  static const _bg         = Color(0xFFF8F9FB); // Very Light Grey / Concrete
  static const _surface    = Color(0xFFFFFFFF); // Pure White (inputs)
  static const _primary    = Color(0xFF1C1C1E); // Deep Charcoal / Black (CTA button)
  static const _accent     = Color(0xFF2C2C2E); // Dark Grey (focus, links)
  static const _accentSoft = Color(0xFFF2F2F7); // Lite Grey tint
  static const _text       = Color(0xFF1C1C1E); // Black text
  static const _textMid    = Color(0xFF8E8E93); // iOS style muted text
  static const _border     = Color(0xFFE5E5EA); // Lite separator
  static const _danger     = Color(0xFFFF3B30); // Apple Red
  static const _success    = Color(0xFF34C759); // Apple Green
  // alias so _textDark compile references still resolve
  static const _textDark   = _text;

  // ── state ────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  // blob float animations
  late final AnimationController _blobCtrl;
  late final Animation<double> _blobFloat1; // coral — drifts up
  late final Animation<double> _blobFloat2; // green — drifts down-right
  late final Animation<double> _blobFloat3; // curve — drifts up-left
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    // blob float — slow looping breathe
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _blobFloat1 = Tween<double>(begin: 0, end: -16).animate(
      CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut),
    );
    _blobFloat2 = Tween<double>(begin: 0, end: 14).animate(
      CurvedAnimation(
        parent: _blobCtrl,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );
    _blobFloat3 = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(
        parent: _blobCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        Navigator.of(context).pushReplacementNamed('/reset-password');
      }
    });

    // INTERCEPT: If the URL has a code, don't let the user stay here. Move them to Reset immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      final hasCode = uri.queryParameters.containsKey('code') || 
                      uri.fragment.contains('code=') ||
                      uri.fragment.contains('type=recovery') ||
                      uri.queryParameters['type'] == 'recovery';

      if (hasCode && mounted) {
        Navigator.of(context).pushReplacementNamed('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _slideCtrl.dispose();
    _blobCtrl.dispose();
    _authSubscription.cancel();
    super.dispose();
  }

  // ── auth ─────────────────────────────────────────────────────────────────
  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    final fullName = _nameController.text.trim();

    try {
      // ── Step 1: Always try Sign In first ──
      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (response.session != null) {
          if (!mounted) return;
          // SUCCESS: Already an existing user, go straight to routing logic
          await _handlePostAuthRouting();
          return;
        }
      } on AuthException catch (e) {
        // Only proceed to Sign Up if it's an 'Invalid login credentials' error
        // which usually means the user doesn't exist yet (or wrong pass).
        // If it's another error (e.g. email not confirmed), we should show it.
        if (e.message.contains('Invalid login credentials') || e.message.contains('Email not confirmed')) {
          // If the user entered a name, they probably intended to sign up.
          // Or if they are on the sign-up toggle.
          // But according to the prompt: "Only if signIn fails with an 'Invalid login credentials' error, then call supabase.auth.signUp."
          
          if (e.message.contains('Email not confirmed')) {
             // If email not confirmed, we might want to try signing up anyway or just show error.
             // Supabase signUp will return an error if user exists.
          }
        } else {
          rethrow; // Rethrow other auth errors
        }
      }

      // ── Step 2: Try Sign Up (New User) ──
      // Note: We only reach here if signIn failed with credentials error.
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (!mounted) return;
      if (response.user != null) {
        // SUCCESS: New user created.
        // Bypass VerificationScreen: Navigate directly to routing logic.
        await _handlePostAuthRouting();
      } else {
        _showSnack('Sign up failed. Please check your credentials.');
      }

    } on AuthException catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (e) {
      if (mounted) _showSnack('An unexpected error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fast Domain-Based Routing Logic
  Future<void> _handlePostAuthRouting() async {
    if (!mounted) return;
    
    try {
      // Immediately fetch profile
      final profile = await SupabaseService.getCurrentUserProfile(forceRefresh: true);
      
      if (!mounted) return;
      
      final domainId = profile?['domain_id'];
      
      if (domainId == null) {
        // No domain? Go to selection
        Navigator.of(context).pushNamedAndRemoveUntil('/domain-selection', (route) => false, arguments: {
          'fullName': _nameController.text.trim(),
        });
      } else {
        // Has domain? Go home
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    } catch (e) {
      // If profile fetch fails (e.g. trigger lag), still go home and let Home handle it
      // or try again. But prompt says "Navigate directly to HomeScreen or DomainSelectionScreen".
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: isError ? _danger : _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
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
    _slideCtrl.forward(from: 0.3);
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // ── Background Layers (Mobile only or base) ──
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/svg/marble_texture.svg',
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.04), BlendMode.dstATop),
            ),
          ),
          
          // Decorative Blobs (Faint)
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -20, left: -20,
                  child: AnimatedBuilder(
                    animation: _blobCtrl,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _blobFloat1.value),
                      child: child,
                    ),
                    child: Opacity(
                      opacity: 0.25,
                      child: SvgPicture.asset('assets/svg/soft_coral.svg', width: 350, color: Colors.grey[300]),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -90, left: -130,
                  child: AnimatedBuilder(
                    animation: _blobCtrl,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(_blobFloat2.value * 0.4, _blobFloat2.value),
                      child: child,
                    ),
                    child: Opacity(
                      opacity: 0.2,
                      child: SvgPicture.asset('assets/svg/soft_green_blob.svg', width: 300, color: Colors.grey[300]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // ── foreground ───────────────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 900;
                
                if (isDesktop) {
                  return _buildDesktopLayout();
                } else {
                  return _buildMobileLayout();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Left Side: Branding & Image
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              // Clean solid background — no image, no gradient
              Positioned.fill(
                child: Container(color: const Color(0xFFF0F4FF)),
              ),
              // SVG illustration centered in the upper portion
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 48, 48, 180),
                  child: SvgPicture.asset(
                    'assets/svg/undraw_login_weas.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Branding text at the bottom
              Padding(
                padding: const EdgeInsets.all(60.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const AWLogo(size: 80, showAppName: false),
                    const SizedBox(height: 24),
                    const Text(
                      'Unite with your\nprofessional domain.',
                      style: TextStyle(
                        color: Color(0xFF1C1C1E),
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LinkSpec is the domain-gated networking platform\nfor the modern professional.',
                      style: TextStyle(
                        color: const Color(0xFF1C1C1E).withOpacity(0.6),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Right Side: Form
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(60),
                child: _buildFormContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildFormContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
                          // ── Logo ───────────────────────────────────────
                          Center(
                            child: AWLogo(
                              size: 52,
                              showAppName: true,
                              showTagline: false,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Heading ─────────────────────────────────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Column(
                              key: ValueKey(_isSignUp),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isSignUp ? 'Create account' : 'Welcome back',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark,
                                    letterSpacing: -0.5,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isSignUp
                                      ? 'Join your professional community.'
                                      : 'Sign in to your domain feed.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _textMid,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // ── Form ───────────────────────────────────────
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Name (sign-up only)
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOut,
                                  child: _isSignUp
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            _buildLabel('Full Name'),
                                            const SizedBox(height: 6),
                                            _buildField(
                                              controller: _nameController,
                                              focusNode: _nameFocus,
                                              hint: 'Jane Doe',
                                              icon: Icons.person_outline_rounded,
                                              textCapitalization: TextCapitalization.words,
                                              textInputAction: TextInputAction.next,
                                              onSubmitted: (_) => FocusScope.of(context).requestFocus(_emailFocus),
                                              validator: (v) {
                                                if (v == null || v.trim().isEmpty) return 'Name is required';
                                                if (v.trim().length < 2) return 'At least 2 characters';
                                                return null;
                                              },
                                              autofillHints: [AutofillHints.name],
                                            ),
                                            const SizedBox(height: 20),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),

                                // Email
                                _buildLabel('Email'),
                                const SizedBox(height: 6),
                                _buildField(
                                  controller: _emailController,
                                  focusNode: _emailFocus,
                                  hint: 'you@example.com',
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => FocusScope.of(context).requestFocus(_passFocus),
                                  validator: Validators.validateEmail,
                                  autofillHints: [AutofillHints.email],
                                ),
                                const SizedBox(height: 20),

                                // Password
                                _buildLabel('Password'),
                                const SizedBox(height: 6),
                                _buildField(
                                  controller: _passwordController,
                                  focusNode: _passFocus,
                                  hint: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _handleAuth(),
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                    child: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: _textMid,
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Password is required';
                                    if (_isSignUp && v.length < 6) return 'At least 6 characters';
                                    return null;
                                  },
                                  autofillHints: [_isSignUp ? AutofillHints.newPassword : AutofillHints.password],
                                ),

                                // Hidden username field for accessibility (resolves Chrome warning)
                                if (!_isSignUp)
                                  const Offstage(
                                    child: TextField(
                                      autofillHints: [AutofillHints.username],
                                    ),
                                  ),

                                if (!_isSignUp)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _handleForgotPassword,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Forgot password?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _accent,
                                        ),
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 32),

                                // ── CTA button ────────────────────────────
                                _PrimaryButton(
                                  isLoading: _isLoading,
                                  label: _isSignUp ? 'Create account' : 'Sign in',
                                  onTap: _isLoading ? null : _handleAuth,
                                ),
                                const SizedBox(height: 24),

                                // ── Divider ───────────────────────────────
                                Row(children: const [
                                  Expanded(child: Divider(color: _border)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('or', style: TextStyle(color: _textMid, fontSize: 13)),
                                  ),
                                  Expanded(child: Divider(color: _border)),
                                ]),
                                const SizedBox(height: 20),

                                // ── Toggle ────────────────────────────────
                                Center(
                                  child: GestureDetector(
                                    onTap: _toggleMode,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      child: RichText(
                                        key: ValueKey(_isSignUp),
                                        text: TextSpan(
                                          style: const TextStyle(fontSize: 14, color: _textMid),
                                          children: [
                                            TextSpan(
                                              text: _isSignUp ? 'Already have an account? ' : "Don't have an account? ",
                                            ),
                                            TextSpan(
                                              text: _isSignUp ? 'Sign in' : 'Sign up',
                                              style: const TextStyle(color: _accent, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
  }

  // ── Forgot Password Logic ────────────────────────────────────────────────
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email address first.');
      _emailFocus.requestFocus();
      return;
    }

    setState(() => _isLoading = true);
    try {
      // PERSISTENCE: Save the email locally so we can identify the user when they return from the link
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('recovery_email', email);

      await SupabaseService.sendPasswordResetEmail(email);
      if (mounted) {
        _showSuccess('Password reset link sent to $email');
      }
    } catch (e) {
      if (mounted) _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



  // ── helpers ───────────────────────────────────────────────────────────────
  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _textDark,
          letterSpacing: 0.1,
        ),
      );

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
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
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      onFieldSubmitted: onSubmitted,
      autofillHints: autofillHints,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: _textDark,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _textMid.withOpacity(0.6), fontSize: 15),
        prefixIcon: Icon(icon, size: 18, color: _textMid),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _danger, width: 1.5),
        ),
        errorStyle: TextStyle(fontSize: 12, height: 1.4, color: _danger),
      ),
    );
  }
}

// ── Primary button ─────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.isLoading,
    required this.label,
    required this.onTap,
  });

  final bool isLoading;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 52,
          decoration: BoxDecoration(
            color: widget.onTap == null
                ? const Color(0xFF1C1C1E).withOpacity(0.45) // disabled: dim black
                : const Color(0xFF1C1C1E),                   // active: Deep Black
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white, // white on coral bg
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
