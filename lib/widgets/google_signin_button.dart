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
  final double width;

  const GoogleSignInButton({
    Key? key,
    required this.onCredential,
    this.width = double.infinity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // Non-web platforms: show nothing (email/password only)
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: width,
      height: 48,
      child: buildGoogleSignInButtonView(onCredential),
    );
  }
}
