import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'cache_manager.dart';
import '../config/supabase_config.dart';


/// Service to handle OTP generation, sending via external routes, and verification.
class OtpService {
  /// Generates a secure 6-digit OTP string.
  static String _generateOtp() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Integrated logic for Gmail and Microsoft routes.
  static Future<bool> sendOtp({
    required String email,
  }) async {
    final isGmail = email.toLowerCase().endsWith('@gmail.com');
    final gmailRouteFromEnv = dotenv.env['GMAIL_OTP_ROUTE'] ?? '';
    final msRouteFromEnv = dotenv.env['MICROSOFT_OTP_ROUTE'] ?? '';
    final route = isGmail 
        ? (gmailRouteFromEnv.isNotEmpty ? gmailRouteFromEnv : SupabaseConfig.gmailOtpRoute)
        : (msRouteFromEnv.isNotEmpty ? msRouteFromEnv : SupabaseConfig.microsoftOtpRoute);

    final otp = _generateOtp();

    try {
      if (route == null) return false;

      final response = await http.post(
        Uri.parse(route),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${dotenv.env['API_SECRET_KEY'] ?? SupabaseConfig.apiSecretKey}',

        },
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'config': isGmail 
            ? {
                'gmail_app_password': dotenv.env['GMAIL_APP_PASSWORD'] ?? SupabaseConfig.gmailAppPassword,
                'sender_email': dotenv.env['GMAIL_SENDER_EMAIL'] ?? SupabaseConfig.gmailSenderEmail,
              }
            : {
                'ms365_tenant_id': dotenv.env['MS365_TENANT_ID'] ?? SupabaseConfig.ms365TenantId,
                'ms365_client_id': dotenv.env['MS365_CLIENT_ID'] ?? SupabaseConfig.ms365ClientId,
                'ms365_client_secret': dotenv.env['MS365_CLIENT_SECRET'] ?? SupabaseConfig.ms365ClientSecret,
                'sender_email': dotenv.env['SENDER_EMAIL'] ?? SupabaseConfig.senderEmail,
              },

        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await CacheManager.saveOtp(
          email: email,
          otp: otp,
          expiryMinutes: 5,
        );
        return true;
      }
      return false;
    } catch (e) {
      print('OtpService.sendOtp Error: $e');
      return false;
    }
  }

  /// Compares user input to cached OTP and checks for expiration.
  static Future<Map<String, dynamic>> verifyOtp(String input) async {
    final cached = await CacheManager.getOtp();
    final cachedOtp = cached['otp'];
    final expiryStr = cached['expiry'];

    // 1. Check if OTP exists in cache
    if (cachedOtp == null || expiryStr == null) {
      return {
        'success': false,
        'message': 'No active session found. Please resend OTP.',
        'canResend': true,
      };
    }

    // 2. Check for expiration
    final expiryTime = DateTime.parse(expiryStr);
    if (DateTime.now().isAfter(expiryTime)) {
      return {
        'success': false,
        'message': 'OTP has expired.',
        'canResend': true,
      };
    }

    // 3. Compare input
    if (input.trim() == cachedOtp) {
      return {
        'success': true,
        'message': 'OTP Verified successfully!',
      };
    } else {
      return {
        'success': false,
        'message': 'Invalid OTP code. Please try again.',
        'canResend': false, // Allow another try unless they want to resend
      };
    }
  }
}
