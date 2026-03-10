import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../widgets/aw_logo.dart';
import '../services/supabase_service.dart';

/// Enum to manage the dynamic states of the unified recovery flow.
enum AuthState { 
  forgot,   // Initial "Enter email" view
  mailSent, // Confirmation after sending reset link
  reset,    // "Enter new password" view (if token detected)
  success   // Celebration view after successful reset
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> 
    with TickerProviderStateMixin {
  
  // ── State ──────────────────────────────────────────────────────────────────
  AuthState _currentState = AuthState.forgot;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  // ── Design Tokens ────────────────────────────────────────────────────────
  static const _primary    = Color(0xFF1C1C1E); // Deep Black
  static const _accent     = Color(0xFF0066CC); // Apple Blue
  static const _text       = Color(0xFF1C1C1E); 
  static const _textMid    = Color(0xFF8E8E93); 
  static const _border     = Color(0xFFE5E5EA); 
  static const _bg         = Color(0xFFFBF6F3);

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  /// Logic to detect if we arrived via a recovery deep link.
  void _checkInitialState() {
    // Note: Supabase on Web usually handles the hash session automatically.
    // We check for 'code' or 'type=recovery' in current URL.
    final uri = Uri.base;
    final hasCode = uri.queryParameters.containsKey('code') || 
                    uri.fragment.contains('code=') ||
                    uri.fragment.contains('type=recovery') ||
                    uri.queryParameters['type'] == 'recovery';

    if (hasCode) {
      setState(() => _currentState = AuthState.reset);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Flow Handlers ─────────────────────────────────────────────────────────

  /// Step 1: Request reset link
  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await SupabaseService.sendPasswordResetEmail(email);
      setState(() => _currentState = AuthState.mailSent);
    } catch (e) {
      _showSnackbar(e.toString(), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Step 2: Update password with new one
  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final newPassword = _passwordController.text.trim();
      
      // Update the user's password in the current auth session
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      setState(() => _currentState = AuthState.success);
      
      // Auto-navigate to home after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      });
    } catch (e) {
      _showSnackbar(e.toString(), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05), 
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _buildCurrentView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentState) {
      case AuthState.forgot:
        return _ForgotPasswordView(
          key: const ValueKey('forgot'),
          controller: _emailController,
          isLoading: _isLoading,
          onSend: _handleForgotPassword,
          onBack: () => Navigator.pop(context),
        );
      case AuthState.mailSent:
        return _MailSentView(
          key: const ValueKey('mailSent'),
          email: _emailController.text,
          onBack: () => setState(() => _currentState = AuthState.forgot),
        );
      case AuthState.reset:
        return _ResetView(
          key: const ValueKey('reset'),
          formKey: _formKey,
          passCtrl: _passwordController,
          confCtrl: _confirmController,
          isLoading: _isLoading,
          obscure: _obscurePassword,
          onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
          onSubmit: _handleResetPassword,
        );
      case AuthState.success:
        return _SuccessView(
          key: const ValueKey('success'),
          onHome: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT VIEWS
// ─────────────────────────────────────────────────────────────────────────────

class _ForgotPasswordView extends StatelessWidget {
  const _ForgotPasswordView({
    Key? key,
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onBack,
  }) : super(key: key);

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AWLogo(size: 60, showAppName: true),
        const SizedBox(height: 40),
        const Text(
          'Password Recovery',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your email to receive a recovery link.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 32),
        Form(
          child: _CustomField(
            controller: controller,
            hint: 'Email Address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        const SizedBox(height: 24),
        _ActionBtn(
          label: 'Send Reset Link',
          isLoading: isLoading,
          onTap: onSend,
        ),
        TextButton(
          onPressed: onBack,
          child: const Text('Back to Login', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}

class _MailSentView extends StatelessWidget {
  const _MailSentView({Key? key, required this.email, required this.onBack}) : super(key: key);
  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 80, color: Color(0xFF0066CC)),
        const SizedBox(height: 24),
        const Text(
          'Check your inbox',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a secure link to $email.\nPlease click it to reset your password.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 40),
        _ActionBtn(
          label: 'I didn\'t get an email',
          onTap: onBack,
          isOutline: true,
        ),
      ],
    );
  }
}

class _ResetView extends StatelessWidget {
  const _ResetView({
    Key? key,
    required this.formKey,
    required this.passCtrl,
    required this.confCtrl,
    required this.isLoading,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  }) : super(key: key);

  final GlobalKey<FormState> formKey;
  final TextEditingController passCtrl;
  final TextEditingController confCtrl;
  final bool isLoading;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AWLogo(size: 50, showAppName: true),
          const SizedBox(height: 32),
          const Text(
            'New Password',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ensure your new password is secure.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          _CustomField(
            controller: passCtrl,
            hint: 'New Password',
            icon: Icons.lock_outline_rounded,
            obscure: obscure,
            suffix: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: onToggleObscure,
              iconSize: 20,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          _CustomField(
            controller: confCtrl,
            hint: 'Confirm Password',
            icon: Icons.verified_user_outlined,
            obscure: obscure,
            validator: (v) => v != passCtrl.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 32),
          _ActionBtn(
            label: 'Update Password',
            isLoading: isLoading,
            onTap: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({Key? key, required this.onHome}) : super(key: key);
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green),
        ),
        const SizedBox(height: 24),
        const Text(
          'Identity Verified',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const Text(
          'Your password has been updated.\nYou can now sign in with your new credentials.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 40),
        _ActionBtn(
          label: 'Continue to App',
          onTap: onHome,
        ),
      ],
    );
  }
}

// ── UI HELPERS ───────────────────────────────────────────────────────────────

class _CustomField extends StatelessWidget {
  const _CustomField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator ?? (v) => (v == null || v.isEmpty) ? 'Required' : null,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF8E8E93)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.isOutline = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isOutline;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isOutline ? Colors.transparent : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(14),
          border: isOutline ? Border.all(color: const Color(0xFFE5E5EA), width: 1.5) : null,
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  label,
                  style: TextStyle(
                    color: isOutline ? const Color(0xFF1C1C1E) : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

