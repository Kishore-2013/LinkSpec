import 'package:supabase_flutter/supabase_flutter.dart';

/// AuthService: Manages secure authentication via Microsoft 365 (Azure AD).
class AuthService {
  static final _supabase = Supabase.instance.client;

  /// Initiate Microsoft 365 (Azure AD) OAuth sign-in flow.
  /// This replaces all legacy custom OTP/Gmail authentication methods.
  static Future<void> signInWithMicrosoft() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.azure,
        // Azure AD handles the entire authentication, no manual OTP required.
      );
    } catch (e) {
      print('AuthService: Microsoft Sign-In failed: $e');
      rethrow;
    }
  }

  /// Synchronize Microsoft account data to public profile.
  static Future<void> syncProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null && user.email != null) {
        await _supabase
            .from('profiles')
            .update({
              'email': user.email,
              'full_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first,
            })
            .eq('id', user.id);
      }
    } catch (e) {
      print('AuthService: Profile synchronization failed: $e');
    }
  }
}
