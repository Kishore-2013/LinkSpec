import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';
import 'package:flutter/foundation.dart';

class VerificationService {
  static const String _baseUrl = 'https://link-spec.vercel.app/api';

  /// Triggers the Fermion enrollment and returns the redirect URL.
  /// env: the environment/contest key (e.g., 'fe1', 'be1', etc.)
  static String getRedirectUrl({
    required String userId, 
    required String env, 
    String? name,
    String? email,
    String? skill,
  }) {
    var url = '$_baseUrl/fermion-redirect?uid=$userId&env=$env';
    if (name != null) url += '&name=${Uri.encodeComponent(name)}';
    if (email != null) url += '&email=${Uri.encodeComponent(email)}';
    if (skill != null) {
      url += '&skill=${Uri.encodeComponent(skill)}';
    }
    return url;
  }

  /// Optional: Pre-create Fermion user to ensure they exist before redirect
  static Future<void> createFermionUser({
    required String userId,
    required String name,
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/create-fermion-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'name': name,
          'email': email,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('VerificationService: User creation failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('VerificationService error: $e');
    }
  }

  /// Add experience and work email
  static Future<bool> addExperienceWithEmail({
    required String userId,
    required String companyName,
    required String workEmail,
    required Map<String, dynamic> otherFields,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/profile/experience/add'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'company_name': companyName,
          'work_email': workEmail,
          ...otherFields,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('VerificationService error: $e');
      return false;
    }
  }

  /// Request OTP for work email verification
  static Future<bool> requestWorkEmailOtp({
    required String userId,
    required String workEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/work-email/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'work_email': workEmail,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('VerificationService error: $e');
      return false;
    }
  }

  /// Verify OTP for work email
  static Future<bool> verifyWorkEmailOtp({
    required String userId,
    required String workEmail,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/work-email/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'work_email': workEmail,
          'otp': otp,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('VerificationService error: $e');
      return false;
    }
  }

  /// Fetch results for a specific user and lab
  static Future<Map<String, dynamic>?> getLabResults({
    required String userId,
    required String labId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/get-fermion-lab-results'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'labId': labId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('VerificationService: Result fetch failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('VerificationService error: $e');
      return null;
    }
  }

  /// Check if the user is verified based on their profile data
  static Future<bool> isUserVerified(String userId) async {
    final profile = await SupabaseService.getUserProfile(userId);
    return profile?['verification_status'] == 'verified';
  }
}
