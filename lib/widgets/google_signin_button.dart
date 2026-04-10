import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// JS interop only compiled on web
import 'google_signin_button_stub.dart'
    if (dart.library.js_interop) 'google_signin_button_web.dart';

/// A widget that renders the official Google Sign-In button using
/// Google Identity Services (GIS) `renderButton()` API via an HtmlElementView.
///
/// • Only shown on Flutter Web (`kIsWeb` is true).
/// • Fires [onCredential] with the raw JWT id_token string when the user
///   successfully picks a Google account.
/// • Uses renderButton — NO popup flow, NO deprecated APIs.
class GoogleSignInButton extends StatelessWidget {
  final void Function(String idToken) onCredential;
  final VoidCallback? onMobileTap;
  final double width;

  const GoogleSignInButton({
    Key? key,
    required this.onCredential,
    this.onMobileTap,
    this.width = double.infinity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(
        width: width,
        height: 48,
        child: buildGoogleSignInButtonView(onCredential),
      );
    }

    // Non-web platforms: Native Styled Button
    return SizedBox(
      width: width,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onMobileTap,
        icon: Image.network(
          'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg', // Placeholder or use localized asset
          height: 18,
          errorBuilder: (_, __, ___) => const Icon(Icons.login),
        ),
        label: const Text(
          'Sign in with Google',
          style: TextStyle(
            color: Color(0xFF1C1C1E),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE5E5EA)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1C1C1E),
        ),
      ),
    );
  }
}
