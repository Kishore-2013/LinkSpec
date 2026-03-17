import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Provider to hold the currently signed-in Google user.
final googleUserProvider = StateProvider<GoogleSignInAccount?>((ref) => null);
