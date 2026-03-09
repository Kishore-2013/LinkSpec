import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/aw_logo.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // ─────────────────────────────────────────────────────────────────────────
  // Design tokens — Flamingo Warm
  static const _bg         = Color(0xFFFBF6F3); 
  static const _surface    = Color(0xFFFFFFFF); 
  static const _primary    = Color(0xFFCF7E6B); 
  static const _accent     = Color(0xFFE8B4A8); 
  static const _text       = Color(0xFF2D2525); 
  static const _textMid    = Color(0xFF9E9090); 
  static const _border     = Color(0xFFEDE0D8); 

  late final AnimationController _blobCtrl;
  late final Animation<double> _blobFloat1; 
  late final Animation<double> _blobFloat2; 
  late final Animation<double> _blobFloat3; 

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _blobFloat1 = Tween<double>(begin: 0, end: -16).animate(CurvedAnimation(parent: _blobCtrl, curve: Curves.easeInOut));
    _blobFloat2 = Tween<double>(begin: 0, end: 14).animate(CurvedAnimation(parent: _blobCtrl, curve: const Interval(0.2, 1.0, curve: Curves.easeInOut)));
    _blobFloat3 = Tween<double>(begin: 0, end: -12).animate(CurvedAnimation(parent: _blobCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeInOut)));
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _needsManualEmail = false;
  bool _needsOtpCode = false;
  final _manualEmailController = TextEditingController();
  final _otpCodeController = TextEditingController();

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final auth = Supabase.instance.client.auth;

      // 1. Give background tools a moment
      for (int i = 0; i < 3; i++) {
        if (auth.currentSession != null) break;
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final uri = Uri.base;
      String? code = uri.queryParameters['code'];
      String? emailInUrl = uri.queryParameters['email'];
      
      if (uri.fragment.contains('code=') || uri.fragment.contains('email=')) {
        final fragments = Uri.splitQueryString(uri.fragment.replaceAll('#', '').split('?').last);
        code ??= fragments['code'];
        emailInUrl ??= fragments['email'];
      }

      // IDENTIFICATION
      if (emailInUrl == null || emailInUrl.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        emailInUrl = prefs.getString('recovery_email');
      }

      // 2. Verification Step
      if (auth.currentSession == null) {
        final targetEmail = emailInUrl ?? auth.currentUser?.email ?? 
                           (_needsManualEmail ? _manualEmailController.text.trim() : null);
        
        if (targetEmail == null || targetEmail.isEmpty) {
          setState(() {
            _needsManualEmail = true;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please confirm your email address to continue.'),
              backgroundColor: Color(0xFFCF7E6B),
            ),
          );
          return;
        }

        try {
          // If we are in OTP mode, use the code they typed
          if (_needsOtpCode) {
            String typedCode = _otpCodeController.text.trim();
            if (typedCode.isEmpty) throw 'Please enter the 6-digit code sent to your email.';
            
            await auth.verifyOTP(
              email: targetEmail,
              token: typedCode,
              type: OtpType.magiclink, // Fallback to standard OTP login if recovery link is broken
            );
          } else {
             // Normal link recovery
             if (code == null) throw 'Security code is missing. Please request a new link.';
             await auth.verifyOTP(
               email: targetEmail,
               token: code,
               type: OtpType.recovery,
             );
          }
        } catch (otpError) {
          // If the link fails due to PKCE (Code verifier missing), we fallback to sending a clean 6-digit code
          if (auth.currentSession == null) {
             if (!_needsOtpCode && targetEmail != null && targetEmail.isNotEmpty) {
                // The link is broken by the browser. Let's send a standard OTP code instead.
                await auth.signInWithOtp(email: targetEmail);
                setState(() {
                  _needsOtpCode = true;
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Link expired due to browser security. We just sent a 6-digit code to your email. Enter it below.'),
                    backgroundColor: Color(0xFF0066CC),
                    duration: Duration(seconds: 5),
                  ),
                );
                return;
             }
             rethrow; 
          }
        }
      }

      // 3. Final update
      if (auth.currentSession != null) {
        await auth.updateUser(
          UserAttributes(password: _passwordController.text.trim()),
        );
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('recovery_email');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Succesfully Reset! Enjoy LinkSpec.'),
              backgroundColor: Color(0xFF34D399),
              behavior: SnackBarBehavior.floating,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted) Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        throw 'Security check failed. Please request a new link.';
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('otp_expired') || errorMsg.contains('403')) {
          errorMsg = 'This code is invalid or has expired.';
        } else if (errorMsg.contains('user not found') || errorMsg.contains('user_not_found')) {
          errorMsg = 'Account not found. Please ensure you are using the correct email address.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          Positioned.fill(child: SvgPicture.asset('assets/svg/marble_texture.svg', fit: BoxFit.cover)),
          AnimatedBuilder(
            animation: _blobCtrl,
            builder: (context, _) => Stack(
              children: [
                Positioned(top: -60 + _blobFloat1.value, left: -50, child: Opacity(opacity: 0.8, child: SvgPicture.asset('assets/svg/soft_coral.svg', width: 280))),
                Positioned(bottom: -70 + _blobFloat2.value, left: -80, child: Opacity(opacity: 0.7, child: SvgPicture.asset('assets/svg/soft_green_blob.svg', width: 340))),
                Positioned(bottom: -30 + _blobFloat3.value, right: -40, child: Opacity(opacity: 0.6, child: SvgPicture.asset('assets/svg/side_organic_curve.svg', width: 280))),
              ],
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const AWLogo(size: 72, showAppName: true),
                    const SizedBox(height: 48),
                    Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: _border, width: 1.5),
                        boxShadow: [BoxShadow(color: _primary.withOpacity(0.06), blurRadius: 30, offset: const Offset(0, 15))],
                      ),
                      padding: const EdgeInsets.all(40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Secure Your Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _text, letterSpacing: -1), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            const Text('Choose a strong new password to regain access to your LinkSpec feed.', style: TextStyle(color: _textMid, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
                            const SizedBox(height: 40),
                            
                            // 1. Fallback: Ask for clean OTP code if link is broken
                            if (_needsOtpCode) ...[
                              _buildLabel('6-DIGIT CODE'),
                              _buildTextField(
                                controller: _otpCodeController,
                                hint: 'Enter code from your email',
                                icon: Icons.numbers,
                                validator: (v) => (v == null || v.isEmpty) ? 'Code is required' : null,
                              ),
                              const SizedBox(height: 24),
                            ],

                            // 2. Fallback: Ask for email if memory/URL failed
                            if (_needsManualEmail) ...[
                              _buildLabel('EMAIL ADDRESS'),
                              _buildTextField(
                                controller: _manualEmailController,
                                hint: 'Verify your email',
                                icon: Icons.email_outlined,
                                validator: (v) => (v == null || v.isEmpty) ? 'Email is required' : null,
                              ),
                              const SizedBox(height: 24),
                            ],

                            _buildLabel('NEW PASSWORD'),
                            _buildTextField(
                              controller: _passwordController,
                              hint: 'Minimum 6 characters',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                              suffix: _buildToggleVisibility(),
                            ),
                            const SizedBox(height: 24),
                            _buildLabel('CONFIRM PASSWORD'),
                            _buildTextField(
                              controller: _confirmController,
                              hint: 'Re-type password',
                              icon: Icons.verified_user_outlined,
                              obscure: _obscurePassword,
                              validator: (v) => (v != _passwordController.text) ? 'Passwords do not match' : null,
                            ),
                            const SizedBox(height: 48),
                            _buildPrimaryButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: _textMid,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    String? Function(String?)? validator,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textMid, fontSize: 14, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: _primary.withOpacity(0.5), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _bg.withOpacity(0.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildToggleVisibility() => GestureDetector(
    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
    child: Icon(
      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      size: 18,
      color: _textMid,
    ),
  );

  Widget _buildPrimaryButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleReset,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text(
                  'Update Password',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
        ),
      ),
    );
  }
}
