import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'supabase_service.dart';
import '../config/supabase_config.dart';


/// Managed Authentication Service for LinkSpec.
/// Handles Firebase & Google Sign-In for Mobile while providing
/// the ID Token for Supabase synchronization.
class AuthService {
  static final _auth = FirebaseAuth.instance;
  
  // Scopes are critical for certain Google APIs, but for basic Sign-In, 
  // 'email' and 'profile' are provided by default.
  // serverClientId is REQUIRED for Supabase to accept the id_token.
  static final _googleSignIn = GoogleSignIn(
    serverClientId: SupabaseConfig.googleClientId,
  );


  /// Current user observable
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// NATIVE GOOGLE SIGN-IN (Android/iOS)
  /// 
  /// Flow: 
  /// 1. Trigger Native Account Picker
  /// 2. Exchange Google Auth code for Tokens (accessToken, idToken)
  /// 3. Sign in to Firebase Auth (User Identity)
  /// 4. Synchronize with Backend (Supabase) using the original Google ID Token
  static Future<UserCredential?> signInWithGoogleMobile() async {
    try {
      // ── Step 1: Trigger Native Google Picker ──────────────────────────
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // Handle user cancellation gracefully
      if (googleUser == null) return null; 

      // ── Step 2: Obtain Auth details from request ──────────────────────
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // ── Step 3: Create Firebase Credential ────────────────────────────
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // ── Step 4: Sign in to Firebase ──────────────────────────────────
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // ── Step 5: Sync with Supabase ──────────────────────────────────
      // This ensures that the user's mobile session matches their web identity.
      if (googleAuth.idToken != null) {
        await SupabaseService.signInWithGoogle(googleAuth.idToken!);
      } else {
        debugPrint('WARNING: Google ID Token was null. Supabase sync might fail.');
      }

      return userCredential;

    } on PlatformException catch (e) {
      // Common issues:
      // 1. DEVELOPER_ERROR: Usually means SHA-1 doesn't match Firebase Console.
      // 2. network_error: User has no internet.
      debugPrint('NATIVE AUTH ERROR: ${e.code} - ${e.message}');
      
      if (e.code == 'DEVELOPER_ERROR') {
        throw 'Configuration Error: Potential SHA-1 fingerprint mismatch in Firebase Console.';
      }
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('FIREBASE AUTH ERROR: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('UNEXPECTED SIGN-IN ERROR: $e');
      rethrow;
    }
  }

  /// COMPREHENSIVE SIGN OUT
  /// Signs out of Firebase, Google SDK, and Supabase to ensure a clean state.
  static Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
        SupabaseService.signOut(),
      ]);
    } catch (e) {
      debugPrint('SIGN OUT ERROR: $e');
    }
  }

  /// Get Current Firebase User
  static User? get currentUser => _auth.currentUser;
}

