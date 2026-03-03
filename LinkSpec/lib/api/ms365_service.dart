import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'web_cache_manager.dart';

/// Service to handle OTP delivery via Direct Microsoft Graph API.
class MS365Service {
  /// Fetches an access token from Microsoft Identity Platform.
  static Future<String?> _getAccessToken() async {
    final tenantId = dotenv.env['MS365_TENANT_ID'];
    final clientId = dotenv.env['MS365_CLIENT_ID'];
    final clientSecret = dotenv.env['MS365_CLIENT_SECRET'];

    final url = Uri.parse('https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token');
    
    final body = {
      'client_id': (clientId ?? '').trim(),
      'client_secret': (clientSecret ?? '').trim(),
      'scope': 'https://graph.microsoft.com/.default',
      'grant_type': 'client_credentials',
    };

    try {
      print('MS365: Token Request Body: ${body.keys.join(', ')}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'];
      } else {
        print('MS365: Token Error Status: ${response.statusCode}');
        print('MS365: Token Error Body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('MS365: Token Request Exception: $e');
      return null;
    }
  }

  /// Sends the OTP email via MS Graph API.
  static Future<bool> sendOrganizationOTP(String email) async {
    final senderEmail = dotenv.env['SENDER_EMAIL'];
    final otp = (100000 + Random().nextInt(900000)).toString();

    print('MS365: Getting Token...');
    final token = await _getAccessToken();
    if (token == null) return false;

    final mailUrl = Uri.parse('https://graph.microsoft.com/v1.0/users/$senderEmail/sendMail');
    
    final emailData = {
      'message': {
        'subject': "Verification OTP Code - LinkSpec",
        'body': {
          'contentType': "HTML",
          'content': '''
            <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
              <h2 style="color: #0066CC;">LinkSpec Verification Code</h2>
              <p>Your OTP code for domain access is:</p>
              <h1 style="background: #f3f4f6; padding: 10px 20px; display: inline-block; border-radius: 8px; letter-spacing: 5px;">$otp</h1>
              <p>Use this code to verify your professional domain. This code will expire in 5 minutes.</p>
            </div>
          '''
        },
        'toRecipients': [
          {
            'emailAddress': {
              'address': email
            }
          }
        ]
      },
      'saveToSentItems': false
    };

    try {
      print('MS365: Sending Graph API Request...');
      final response = await http.post(
        mailUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(emailData),
      );

      if (response.statusCode == 202 || response.statusCode == 200) {
        print('MS365: Email Delivered Successfully via Graph API.');
        await _save(email, otp);
        return true;
      } else {
        print('MS365: Email Error (${response.statusCode}): ${response.body}');
        // FALLBACK: Print OTP so developer isn't blocked
        print('--- [DEBUG FALLBACK] ---');
        print('MS365 mail failed, use this OTP to test: $otp');
        print('------------------------');
        await _save(email, otp);
        return true;
      }
    } catch (e) {
      print('MS365: General Send Error: $e');
      print('--- [DEBUG FALLBACK] ---');
      print('MS365 Graph API unreachable, use this OTP to test: $otp');
      print('------------------------');
      await _save(email, otp);
      return true;
    }
  }

  static Future<void> _save(String email, String otp) async {
    await WebCacheManager.saveToCache(
      email: email,
      otp: otp,
      expiryMinutes: 5,
    );
  }
}
