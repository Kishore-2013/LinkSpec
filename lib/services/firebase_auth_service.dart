import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Service layer for handling Firebase Authentication logic.
/// Specifically focuses on Google Sign-In for Flutter Web.
class FirebaseAuthService {
  // Singleton pattern
  FirebaseAuthService._internal();
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // No need to pass clientId here if initialized via FirebaseOptions in main.dart
  );

  /// Triggers the Google Sign-In flow using Firebase.
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Firebase Auth Google flow for Web
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // We use signInWithPopup for a better Web experience
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // Mobile flow (if ever needed, though task is Web-focused)
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        return userCredential.user;
      }
    } catch (e) {
      debugPrint('FirebaseAuthService: Error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Handles logout for BOTH Firebase and Supabase to ensure clean state.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (kIsWeb) {
        await _googleSignIn.disconnect();
      }
      await _googleSignIn.signOut();
      
      // Also clear Supabase to prevent hybrid session confusion
      SupabaseService.clearCache();
    } catch (e) {
      debugPrint('FirebaseAuthService: Error during signOut: $e');
    }
  }

  /// Returns the current Firebase user.
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}

final firebaseAuthService = FirebaseAuthService();
