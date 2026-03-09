import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AuthService: Manages secure authentication and credential synchronization.
class AuthService {
  static final _supabase = Supabase.instance.client;
  
  // A secret key used as a secondary salt (should ideally come from .env)
  static const String _secretKey = "LINK_SPEC_SECRET_SALT_2026";

  /// Synchronize the current user's email into their public profile.
  /// (Backup manual sync if the DB trigger is bypassed)
  static Future<void> syncEmailToProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && user.email != null) {
        await _supabase
            .from('profiles')
            .update({'email': user.email})
            .eq('id', user.id);
      }
    } catch (e) {
      print('AuthService: Email sync failed: $e');
    }
  }

  /// hashPassword: Creates a secure SHA-256 hash of a raw password string.
  /// 
  /// Uses a composite salt of User ID + Internal Secret Key to prevent 
  /// rainbow table attacks and ensure global uniqueness of hashes.
  static String hashPassword(String rawPassword, String userId) {
    // Logic: String hashedPw = sha256.convert(utf8.encode(rawPassword + salt)).toString();
    final salt = userId + _secretKey;
    final bytes = utf8.encode(rawPassword + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// updateCustomPassword: Hashes and stores a secondary password in the profile.
  /// 
  /// Secondary passwords are used for legacy support or multi-factor scenarios,
  /// while primary login remains strictly via Supabase Auth.
  static Future<void> updateCustomPassword(String rawPassword) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("Unauthorized: No active session.");

    final hashedPw = hashPassword(rawPassword, user.id);

    try {
      await _supabase
          .from('profiles')
          .update({'custom_password': hashedPw})
          .eq('id', user.id);
    } catch (e) {
      print('AuthService: Failed to update secondary password: $e');
      rethrow;
    }
  }

  /// verifyCustomPassword: Checks if a raw string matches the stored hash.
  static Future<bool> verifyCustomPassword(String rawPassword) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final response = await _supabase
          .from('profiles')
          .select('custom_password')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) return false;

      final storedHash = response['custom_password'] as String?;
      if (storedHash == null) return false;

      final inputHash = hashPassword(rawPassword, user.id);
      return inputHash == storedHash;
    } catch (e) {
      print('AuthService: Error verifying password: $e');
      return false;
    }
  }
}
