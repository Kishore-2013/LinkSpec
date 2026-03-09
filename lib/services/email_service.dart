import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// EmailService: Refactored to use Supabase's native Auth for email delivery.
class EmailService {
  static final _supabase = Supabase.instance.client;

  /// Triggers a native Supabase OTP signup email.
  static Future<bool> sendOtpEmail({
    required String recipientEmail,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: recipientEmail,
        password: password,
        emailRedirectTo: 'https://link-spec.vercel.app/verification',
      );
      
      return response.user != null;
    } on AuthException catch (e) {
      debugPrint('EmailService: Supabase Auth Error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('EmailService: Unexpected Auth error: $e');
      rethrow;
    }
  }

  /// Generic method to send an email (Stub for future SMTP integration).
  static Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
  }) async {
    // Note: To be implemented if custom SMTP verification is required.
    debugPrint('EmailService: sendEmail is currently disabled.');
    return false;
  }
}
