import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:go_router/go_router.dart';
import '../widgets/aw_logo.dart';
import '../services/linkspec_notify.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  const OTPVerificationScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleVerifyOTP() async {
    final token = _otpController.text.trim();
    if (token.length < 6) {
      LinkSpecNotify.show(context, 'Ohh! no, please enter the full 6-digit code!', LinkSpecNotifyType.warning);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await sb.Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: sb.OtpType.signup,
      );

      if (mounted) {
        LinkSpecNotify.show(
          context, 
          'Perfect! Your email is verified. Let\'s set up your professional domain now!', 
          LinkSpecNotifyType.info
        );
        context.go('/domain-selection');
      }
    } on sb.AuthException catch (e) {
      if (mounted) {
        LinkSpecNotify.show(context, 'Ohh! no, that code doesn\'t seem right. Could you please double-check your inbox?', LinkSpecNotifyType.warning);
      }
    } catch (e) {
      if (mounted) {
        LinkSpecNotify.show(context, 'Ohh! no, we hit a bit of a snag. Could you please try again?', LinkSpecNotifyType.warning);
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
                    onPressed: _isLoading ? null : _handleVerifyOTP,
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
                  onPressed: () {
                    // Logic for resending could go here
                    LinkSpecNotify.show(context, "Resending code... please check your inbox in a moment!", LinkSpecNotifyType.info);
                  },
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
