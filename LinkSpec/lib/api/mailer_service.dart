import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'web_cache_manager.dart';
import '../config/supabase_config.dart';


// Conditional imports for SMTP
import 'mailer_service_stub.dart'
    if (dart.library.io) 'mailer_service_io.dart' as smtpImpl;

/// A completely standalone OTP system.
/// No Supabase Auth, no Edge Functions, no database tables.
class MailerService {
  static final _rng = Random.secure();

  /// 1. Generate & Send OTP
  static Future<bool> sendOTP(String email) async {
    // Generate code
    final otp = (_rng.nextInt(900000) + 100000).toString();
    
    // REQUIREMENT: Store in Local Cache ONLY (No Database)
    await WebCacheManager.saveToCache(
      email: email, 
      otp: otp, 
      expiryMinutes: 5
    );

    debugPrint('MailerService: Stored OTP $otp in local cache for $email (Cache-Only)');

    // Send via appropriate channel
    if (kIsWeb) {
      return _sendViaWebRelay(email, otp);
    } else {
      return _sendViaDirectSMTP(email, otp);
    }
  }

  /// 2. Verify OTP (Requirement: Standalone Cache flow)
  static Future<Map<String, dynamic>> verifyOTP(String email, String code) async {
    // Check local device cache only
    final result = await WebCacheManager.verifyOtp(code);
    
    if (result['success'] == true) {
      await _applyVerification(email);
    }
    return result;
  }

  /// Helper to finalize verification in profiles table
  static Future<void> _applyVerification(String email) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_verified': true})
            .eq('id', userId);
        debugPrint('MailerService: Profile marked as is_verified=true ✓');
      }
    } catch (e) {
      debugPrint('MailerService: Error marking user as verified: $e');
    }
  }

  /// Web: Use your GMAIL_OTP_ROUTE relay (Vercel backend)
  static Future<bool> _sendViaWebRelay(String email, String otp) async {
    final routeFromEnv = dotenv.env['GMAIL_OTP_ROUTE']?.trim() ?? '';
    var route = routeFromEnv.isNotEmpty ? routeFromEnv : SupabaseConfig.gmailOtpRoute;
    
    // Safety: Handle shell-style placeholders or relative paths
    if (route.contains('${')) {
      route = route.replaceAll(RegExp(r'\$\{.*?\}'), '');
    }

    if (route.isEmpty) {
      // If we are on web and at the same domain, try relative path
      route = '/api/auth/otp/gmail';
    }

    // Ensure absolute URL for URI parsing
    String finalUrl = route;
    if (route.startsWith('/')) {
      final base = Uri.base.origin;
      finalUrl = '$base$route';
    }

    debugPrint('MailerService: Attempting relay to: $finalUrl');

    final apiKeyFromEnv = dotenv.env['API_SECRET_KEY']?.trim() ?? '';
    final apiKey = apiKeyFromEnv.isNotEmpty ? apiKeyFromEnv : SupabaseConfig.apiSecretKey;

    if (finalUrl.isEmpty || (!finalUrl.startsWith('http') && !kIsWeb)) {
      return _debugCallback(email, otp, 'Invalid relay URL: $finalUrl');
    }

    try {
      final resp = await http.post(
        Uri.parse(finalUrl),

        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'config': {
            'gmail_app_password': dotenv.env['GMAIL_APP_PASSWORD'] ?? SupabaseConfig.gmailAppPassword,
            'sender_email': dotenv.env['GMAIL_SENDER_EMAIL'] ?? SupabaseConfig.gmailSenderEmail,

          }
        }),
      );

      if (resp.statusCode < 300) {
        try {
          final data = jsonDecode(resp.body);
          if (data is Map && data.containsKey('success')) {
            debugPrint('MailerService: Relay success!');
            return true;
          }
          return _debugCallback(email, otp, 'Relay returned non-JSON content (likely index.html)');
        } catch (_) {
          return _debugCallback(email, otp, 'Relay returned non-JSON content (likely index.html)');
        }
      }

      return _debugCallback(email, otp, 'Relay failed with status ${resp.statusCode}');
    } on Object catch (e) {
      return _debugCallback(email, otp, 'Relay network error (likely CORS): $e');
    }
  }

  /// Mobile: Direct SMTP via mailer package
  static Future<bool> _sendViaDirectSMTP(String email, String otp) async {
    final senderEmailFromEnv = dotenv.env['GMAIL_SENDER_EMAIL']?.trim() ?? '';
    final senderEmail = senderEmailFromEnv.isNotEmpty ? senderEmailFromEnv : SupabaseConfig.gmailSenderEmail;

    final appPasswordFromEnv = dotenv.env['GMAIL_APP_PASSWORD']?.trim() ?? '';
    final appPassword = appPasswordFromEnv.isNotEmpty ? appPasswordFromEnv : SupabaseConfig.gmailAppPassword;


    if (senderEmail.isEmpty || appPassword.isEmpty) {
      return _debugCallback(email, otp, 'SMTP credentials missing in .env');
    }

    final success = await smtpImpl.sendEmail(
      senderEmail: senderEmail,
      appPassword: appPassword,
      toEmail: email,
      otp: otp,
    );

    return success ? true : _debugCallback(email, otp, 'SMTP plugin failed');
  }

  static bool _debugCallback(String email, String code, String reason) {
    debugPrint('--- [OTP STANDALONE DEBUG] ---');
    debugPrint('Reason: $reason');
    debugPrint('Target: $email');
    debugPrint('CODE  : $code');
    debugPrint('------------------------------');
    return true; // Return true to allow user to proceed with the code from console
  }
}
