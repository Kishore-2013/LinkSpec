// Stub for non-web platforms.
// The real implementation is in google_signin_button_web.dart

import 'package:flutter/material.dart';

Widget buildGoogleSignInButtonView(void Function(String idToken) onCredential) {
  return const SizedBox.shrink();
}
