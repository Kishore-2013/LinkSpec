import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../services/linkspec_notify.dart';
import 'dart:async';
import 'dart:js_interop'; // Added for proper .toJS conversion if needed
import 'package:web/web.dart' as web;
import '../widgets/aw_logo.dart';
import '../services/supabase_service.dart';

/// Login Screen — Unified Microsoft 365 Authentication.
/// Features a single, premium 'Sign in with Microsoft' entry point.
class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // ─────────────────────────────────────────────────────────────────────────
  // Design tokens — Ultra-Minimalist
  static const _bg         = Color(0xFFF8F9FB); 
  static const _surface    = Color(0xFFFFFFFF);
  static const _textDark   = Color(0xFF1C1C1E);
  static const _textMid    = Color(0xFF8E8E93);
  static const _border     = Color(0xFFE5E5EA);

  // ── state ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  // blob float animations
  late final AnimationController _blobCtrl;
  late final Animation<double> _blobFloat1; 
  late final Animation<double> _blobFloat2; 
  late final StreamSubscription<sb.AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);

    _blobCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _blobFloat1 = Tween<double>(begin: 0, end: -16).animate(CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut));
    _blobFloat2 = Tween<double>(begin: 0, end: 14).animate(CurvedAnimation(parent: _blobCtrl, curve: const Interval(0.2, 1.0, curve: Curves.easeInOut)));

    _authSubscription = sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == sb.AuthChangeEvent.signedIn || data.event == sb.AuthChangeEvent.tokenRefreshed) {
        // Redirection handled by AuthWrapper, but localized logic can go here.
      }
    });

    // INTERCEPT: If the URL contains recovery parameters, redirect to dedicated auth screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      final hasCode = uri.queryParameters.containsKey('code') || uri.fragment.contains('code=');
      final isRecoveryMode = uri.queryParameters['type'] == 'recovery' || uri.fragment.contains('type=recovery');

      if (hasCode) {
        // VALID RECOVERY: Move to reset screen immediately
        Navigator.of(context).pushReplacementNamed('/reset-password');
      } else if (isRecoveryMode) {
        // GHOST SESSION: Clear URL to prevent 400 errors and notify user
        web.window.history.replaceState(null, '', web.window.location.pathname);
        LinkSpecNotify.show(context, 'Ohh! no, it looks like we need to get you back to the right screen. Could you please try logging in again?', LinkSpecNotifyType.warning);
      }
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _blobCtrl.dispose();
    _authSubscription.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      // 1. CLEAR GHOST SESSIONS: Ensure no stale session or recovery token interferes
      final uri = Uri.base;
      final hasGhostIntent = uri.queryParameters.containsKey('code') || 
                             uri.fragment.contains('code=') ||
                             uri.queryParameters['type'] == 'recovery' ||
                             sb.Supabase.instance.client.auth.currentSession != null;
      
      if (hasGhostIntent) {
        await sb.Supabase.instance.client.auth.signOut();
      }
      
      if (_isSignUp) {
        // 2. SIGN UP WITH METADATA
        final email = _emailCtrl.text.trim();
        await sb.Supabase.instance.client.auth.signUp(
          email: email,
          password: _passwordCtrl.text.trim(),
          data: {'full_name': _nameCtrl.text.trim()},
        );
        if (mounted) {
          LinkSpecNotify.show(context, "Perfect! We've sent a 6-digit verification code to your inbox!", LinkSpecNotifyType.info);
          try {
            // Enhanced with explicit Uri.encodeComponent for security
            context.go('/otp-verify?email=${Uri.encodeComponent(email)}');
          } catch (e) {
            LinkSpecNotify.show(
              context, 
              "Ohh! no, we couldn't move you to the verification screen. Could you please try again?", 
              LinkSpecNotifyType.warning
            );
          }
        }
      } else {
        // 3. SIGN IN
        await sb.Supabase.instance.client.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      }
    } on sb.AuthException catch (e) {
      if (mounted) {
        if (e.statusCode == '422' || e.message.toLowerCase().contains('already registered')) {
          // 422 Handle: User already exists
          LinkSpecNotify.show(context, 'Ohh! no, it looks like this email is already registered! Could you please try signing in or use a different email?', LinkSpecNotifyType.warning);
          setState(() {
            _isSignUp = false;
            _formKey.currentState?.reset();
          });
        } else if (e.statusCode == '400') {
          // 400 Handle: Bad Request/Stale Token
          LinkSpecNotify.show(context, 'Ohh! no, something went a bit wrong with the request. Could you please double-check your details and try one more time?', LinkSpecNotifyType.warning);
        } else {
          LinkSpecNotify.show(context, 'Ohh! no, we hit a bit of a snag. Could you please check this: ${e.message}', LinkSpecNotifyType.warning);
        }
      }
    } catch (e) {
      if (mounted) {
        LinkSpecNotify.show(context, 'Ohh! no, something unexpected happened. Could you please try again in a moment?', LinkSpecNotifyType.warning);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      LinkSpecNotify.show(context, "Please enter your email first.", LinkSpecNotifyType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
       await sb.Supabase.instance.client.auth.resetPasswordForEmail(
         email,
         redirectTo: kIsWeb ? '${Uri.base.origin}/reset-password' : null,
       );
       if (mounted) LinkSpecNotify.show(context, "Recovery link sent! Please check your inbox.", LinkSpecNotifyType.info);
    } catch (e) {
       if (mounted) LinkSpecNotify.show(context, LinkSpecNotify.mapError(e), LinkSpecNotifyType.warning);
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMicrosoftLogin() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.signInWithMicrosoft();
    } catch (e) {
      if (mounted) LinkSpecNotify.show(context, LinkSpecNotify.mapError(e), LinkSpecNotifyType.warning);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/svg/marble_texture.svg',
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.04), BlendMode.dstATop),
            ),
          ),
          
          // Decorative Blobs
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: -20, left: -20,
                  child: AnimatedBuilder(
                    animation: _blobCtrl,
                    builder: (_, child) => Transform.translate(offset: Offset(0, _blobFloat1.value), child: child),
                    child: Opacity(opacity: 0.25, child: SvgPicture.asset('assets/svg/soft_coral.svg', width: 350, color: Colors.grey[300])),
                  ),
                ),
                Positioned(
                  bottom: -90, left: -130,
                  child: AnimatedBuilder(
                    animation: _blobCtrl,
                    builder: (_, child) => Transform.translate(offset: Offset(_blobFloat2.value * 0.4, _blobFloat2.value), child: child),
                    child: Opacity(opacity: 0.2, child: SvgPicture.asset('assets/svg/soft_green_blob.svg', width: 300, color: Colors.grey[300])),
                  ),
                ),
              ],
            ),
          ),
          
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isDesktop = constraints.maxWidth > 900;
                return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
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
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: const Color(0xFFF0F4FF))),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 48, 48, 180),
                  child: SvgPicture.asset('assets/svg/undraw_login_weas.svg', fit: BoxFit.contain),
                ),
              ),
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
                      style: TextStyle(color: _textDark, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.1),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LinkSpec is the domain-gated networking platform\nfor the modern professional.',
                      style: TextStyle(color: _textDark.withOpacity(0.6), fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(padding: const EdgeInsets.all(60), child: _buildFormContent()),
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
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: _buildFormContent()),
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
        const Center(child: AWLogo(size: 64, showAppName: true)),
        const SizedBox(height: 48),
        
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Column(
            key: ValueKey(_isSignUp),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUp ? 'Join the community' : 'Welcome back',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _textDark, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp 
                    ? 'Create your professional profile and join your domain.' 
                    : 'Sign in to access your professional domain feed.',
                style: const TextStyle(fontSize: 15, color: _textMid),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        Form(
          key: _formKey,
          child: Column(
            children: [
              if (_isSignUp) ...[
                _buildTextField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
              ],
              _buildTextField(
                label: 'Email Address',
                controller: _emailCtrl,
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Password',
                controller: _passwordCtrl,
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                suffix: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: _textMid),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters required' : null,
              ),
            ],
          ),
        ),
        
        if (!_isSignUp)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _handleForgotPassword,
              child: const Text('Forgot Password?', style: TextStyle(color: _textMid, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        
        const SizedBox(height: 24),
        
        ElevatedButton(
          onPressed: _isLoading ? null : _handleEmailAuth,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: _textDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isSignUp ? 'Create Account' : 'Sign In', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        
        const SizedBox(height: 24),
        Row(
          children: const [
            Expanded(child: Divider(color: _border)),
            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('or', style: TextStyle(color: _textMid, fontSize: 13))),
            Expanded(child: Divider(color: _border)),
          ],
        ),
        const SizedBox(height: 24),
        
        _MicrosoftButton(isLoading: _isLoading, onTap: _isLoading ? null : _handleMicrosoftLogin),
        
        const SizedBox(height: 32),
        
        Center(
          child: TextButton(
            onPressed: () => setState(() => _isSignUp = !_isSignUp),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: _textMid, fontSize: 15),
                children: [
                  TextSpan(text: _isSignUp ? 'Already have an account? ' : "Don't have an account? "),
                  TextSpan(
                    text: _isSignUp ? 'Sign In' : 'Sign Up',
                    style: const TextStyle(color: _textDark, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: _textDark, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMid),
        prefixIcon: Icon(icon, size: 20, color: _textMid),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _textDark, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
      ),
    );
  }
}

class _MicrosoftButton extends StatelessWidget {
  const _MicrosoftButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.business_rounded, size: 22),
      label: Text(isLoading ? 'Signing in...' : 'Sign in with Microsoft 365'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: const Color(0xFF1C1C1E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
