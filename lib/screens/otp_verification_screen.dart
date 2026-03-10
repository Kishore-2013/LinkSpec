import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/aw_logo.dart';
import '../services/linkspec_notify.dart';

  final String email;
  final String? name;
  final String? password;

  const OTPVerificationScreen({
    Key? key, 
    required this.email,
    this.name,
    this.password,
  }) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyWithServer() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      LinkSpecNotify.show(context, 'Ohh! no, please enter the full 6-digit code!', LinkSpecNotifyType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.otpApiUrl}/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'otp_code': code,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // OTP VERIFIED BY PYTHON BACKEND. Now, proceed with Supabase signup if details provided.
        if (widget.name != null && widget.password != null) {
          try {
            await sb.Supabase.instance.client.auth.signUp(
              email: widget.email,
              password: widget.password!,
              data: {'full_name': widget.name!},
            );
            
            if (!mounted) return;
            LinkSpecNotify.show(
              context, 
              'Perfect! Your identity is verified. Your account has been created!', 
              LinkSpecNotifyType.info
            );
            context.go('/domain-selection');
          } catch (e) {
            LinkSpecNotify.show(
              context, 
              'Identity verified, but account registration failed. Please try logging in.', 
              LinkSpecNotifyType.warning
            );
          }
        } else {
           // Success for non-signup flows (like password reset etc)
           context.go('/domain-selection');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        LinkSpecNotify.show(
          context, 
          'Ohh! no, that code doesn’t seem right. Could you please double-check your inbox?', 
          LinkSpecNotifyType.warning
        );
      } else if (response.statusCode == 410) {
        LinkSpecNotify.show(
          context, 
          'Ohh! no, it looks like that code has expired. Could you please request a new one?', 
          LinkSpecNotifyType.warning
        );
      } else {
        LinkSpecNotify.show(
          context, 
          'Ohh! no, we hit a bit of a snag on the server. Could you please try again?', 
          LinkSpecNotifyType.warning
        );
      }
    } catch (e) {
      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Ohh! no, we couldn’t reach the server. Please check your connection and try again.', 
          LinkSpecNotifyType.warning
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendFromServer() async {
    if (_isLoading) return; // Prevent double-tap
    
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('${SupabaseConfig.otpApiUrl}/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        LinkSpecNotify.show(
          context, 
          "Perfect! We've sent a fresh code to your inbox.", 
          LinkSpecNotifyType.info
        );
      } else {
        LinkSpecNotify.show(
          context, 
          "Ohh! no, we couldn't resend the code right now. Could you please try again in a moment?", 
          LinkSpecNotifyType.warning
        );
      }
    } catch (e) {
      if (mounted) {
        LinkSpecNotify.show(context, "Ohh! no, something went wrong with the connection.", LinkSpecNotifyType.warning);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AWLogo(size: 80, showAppName: true),
                const SizedBox(height: 48),
                const Text(
                  'Verify your Identity',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                ),
                const SizedBox(height: 12),
                Text(
                  'We sent a 6-digit verification code to:\n${widget.email}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 40),
                
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "000000",
                    hintStyle: TextStyle(color: Colors.grey[300]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF1C1C1E), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyWithServer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1C1C1E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _isLoading ? null : _resendFromServer,
                  child: const Text(
                    'Didn\'t receive a code? Resend',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
