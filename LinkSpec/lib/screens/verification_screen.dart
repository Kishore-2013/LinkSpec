import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../api/mailer_service.dart';
import '../api/route_handler.dart';
import '../api/web_cache_manager.dart';
import '../utils/web_utils.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String providerType;
  final String? password;
  final String? fullName;
  final bool isSignUp;

  const VerificationScreen({
    Key? key,
    required this.email,
    required this.providerType,
    this.password,
    this.fullName,
    this.isSignUp = false,
  }) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _showResend = false;
  String? _errorMessage;

  // Design Tokens
  static const _primary = Color(0xFF0066CC);
  static const _surface = Colors.white;
  static const _bg      = Color(0xFFF5F5F7);
  static const _danger  = Color(0xFFFF3B30);

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
      // Standalone Verification: Checks local cache (device only)
      // If successful, MailerService updates the 'is_verified' flag in Supabase DB.
      final result = await MailerService.verifyOTP(widget.email, entry);

      if (!mounted) return;

      if (result['success'] == true) {
        // Verification was successful against the local cache.
        if (widget.isSignUp) {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/domain-selection', (route) => false,
              arguments: {'fullName': widget.fullName});
        } else {
          // Regular login - proceed to Home
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'] ?? 'Invalid code. Please try again.';
          if (result['canResend'] == true) _showResend = true;
        });
      }
    } on Object catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Verification failed. Please try again.';
      });
    }
  }


  Future<void> _handleResend() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Re-trigger the same domain logic via RouteHandler
    final success = await RouteHandler.initiateVerification(widget.email);

    if (!mounted) return;

    if (success) {
      setState(() {
        _isLoading = false;
        _showResend = false;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent!')),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to resend code. Try again later.';
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
              const Icon(Icons.security_rounded, size: 64, color: _primary),
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
                          style: const TextStyle(color: _danger, fontWeight: FontWeight.w600),
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
                                      side: const BorderSide(color: _primary, width: 2),
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
