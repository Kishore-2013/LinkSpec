import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/web_utils.dart';
import '../services/email_service.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String? password;
  final String? fullName;
  final bool isSignUp;

  const VerificationScreen({
    Key? key,
    required this.email,
    this.password,
    this.fullName,
    this.isSignUp = false,
  }) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  bool _showResend = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize controller if needed (already initialized above)
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  // UI Constants
  final Color _primary = const Color(0xFF212121);
  final Color _bg      = Colors.white;
  final Color _surface = Colors.grey[100]!;
  final Color _danger  = Colors.red;

  Future<void> _handleVerify() async {
    final entry = _otpController.text.trim();
    if (entry.length != 6) {
      setState(() => _errorMessage = 'Enter 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Official Supabase OTP Verification
      final response = await _supabase.auth.verifyOTP(
        email: widget.email,
        token: entry,
        type: widget.isSignUp ? OtpType.signup : OtpType.email,
      );

      if (!mounted) return;

      if (response.session != null) {
        if (widget.isSignUp) {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/domain-selection', (route) => false,
              arguments: {'fullName': widget.fullName});
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid or expired code. Please try again.';
          _showResend = true;
        });
      }
    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
        _showResend = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred. Please try again.';
      });
    }
  }

  Future<void> _handleResend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 2. Official Supabase Resend
      await _supabase.auth.resend(
        email: widget.email,
        type: widget.isSignUp ? OtpType.signup : OtpType.email,
        emailRedirectTo: 'https://link-spec.vercel.app/verification',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _showResend = false;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent!')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to resend code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = WebUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Icon
              Icon(Icons.security_rounded, size: 64, color: _primary),
              const SizedBox(height: 24),
              
              // Responsive Container
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 480 : double.infinity),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Check your email',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We sent a 6-digit verification code to\n${widget.email}',
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // OTP Field
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: _bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          hintText: '000000',
                          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.3)),
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: _danger, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                      ],

                      const SizedBox(height: 32),

                      // Dynamic Action Button (Verify vs Resend)
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _showResend
                              ? MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: OutlinedButton(
                                    onPressed: _handleResend,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(56),
                                      side: BorderSide(color: _primary, width: 2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text('Resend Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                )
                              : MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: ElevatedButton(
                                    onPressed: _handleVerify,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primary,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(56),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: const Text('Verify Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                ),
                    ],
                  ),
                ),
              ),
              
              if (kDebugMode && kIsWeb && Uri.base.host == 'localhost') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bug_report_rounded, color: Colors.amber[800], size: 18),
                          const SizedBox(width: 8),
                          Text('Developer Tip', style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'CORS may block the email relay on localhost. You can find the OTP in your browser\'s console or IDE terminal.',
                        style: TextStyle(color: Colors.amber[900], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to sign in', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
