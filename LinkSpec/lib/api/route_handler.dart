import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'web_cache_manager.dart';
import 'dart:math';
import 'ms365_service.dart';
import 'gmail_service.dart';

/// Domain-based OTP routing and initiation.
class RouteHandler {
  /// Initiates verification based on email domain.
  static Future<bool> initiateVerification(String email) async {
    final isGmail = email.toLowerCase().endsWith('@gmail.com');
    
    if (isGmail) {
      // Use the newly created GmailService
      return await GmailService.sendGmailOTP(email);
    } else {
      // Use the newly created MS365Service for organization emails
      return await MS365Service.sendOrganizationOTP(email);
    }
  }
}
