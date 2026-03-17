import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/google_user_provider.dart';

/// Service layer for handling Google Sign-In logic.
/// This follows Clean Architecture by isolating the auth logic from the UI.
class GoogleAuthService {
  // 1. Private constructor
  GoogleAuthService._internal();

  // 2. Single instance
  static final GoogleAuthService _instance = GoogleAuthService._internal();

  // 3. Factory to return the same instance
  factory GoogleAuthService() => _instance;

  // Use the Client ID provided by the user.
  // For Web, this is essentially required inside the GoogleSignIn constructor
  // if not using the Meta tag, but having it here ensures consistency.
  static const String clientId = '761906978717-tvdv5e4ju6tdc4i12u8e5sepuvhsegla.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? clientId : null,
  );

  GoogleSignIn get instance => _googleSignIn;

  /// Initializes the stream listener. Should be called early (e.g., in main or a provider).
  void initialize(WidgetRef ref) {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      ref.read(googleUserProvider.notifier).state = account;
    });
  }

  /// Triggers the Google Sign-In flow (popup on Web).
  /// Returns a [GoogleSignInAccount] if successful, or null if cancelled.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      debugPrint('GoogleAuthService: Error during signIn: $error');
      rethrow;
    }
  }

  /// Handles logout flow.
  Future<void> signOut() async {
    try {
      if (kIsWeb) {
        // On Web, disconnect ensures the user can pick a different account next time.
        await _googleSignIn.disconnect();
      }
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint('GoogleAuthService: Error during signOut: $error');
    }
  }

  /// Returns the current signed-in user, if any.
  Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }
}

// Singleton instance for app-wide use.
final googleAuthService = GoogleAuthService();
