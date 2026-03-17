import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';

/// Provider to hold the currently signed-in Firebase user.
final firebaseUserProvider = StreamProvider<User?>((ref) {
  return firebaseAuthService.authStateChanges;
});
