// ignore_for_file: avoid_web_libraries_in_flutter
// This file is only ever imported on Flutter Web.

import 'dart:js_interop';
import 'package:flutter/foundation.dart';

// ─── Raw JS type bindings ────────────────────────────────────────────────────

/// Represents the `google.accounts.id` namespace.
@JS('google.accounts.id')
external _GoogleAccountsId get _googleAccountsId;

@JS()
@staticInterop
class _GoogleAccountsId {}

extension _GoogleAccountsIdExt on _GoogleAccountsId {
  external void initialize(JSObject options);
  external void renderButton(JSObject element, JSObject options);
  external void disableAutoSelect();
  external void cancel();
}

// ─── window-level callback hook ─────────────────────────────────────────────

@JS('window.flutterGoogleSignInCallback')
external set _flutterGoogleSignInCallback(JSFunction? callback);

// ─── Public API used by Dart code ────────────────────────────────────────────

/// Register the Flutter-side callback that receives the raw JWT `id_token`
/// string whenever GIS produces a credential.
///
/// This bridges the global JS `onGoogleCredentialResponse` (called by GIS)
/// → `window.flutterGoogleSignInCallback` (set here) → [onIdToken].
void registerGoogleSignInCallback(void Function(String idToken) onIdToken) {
  _flutterGoogleSignInCallback = ((JSString jwtToken) {
    onIdToken(jwtToken.toDart);
  }).toJS;
}

/// Initialize GIS with [clientId] and [callbackFunctionName].
/// Call this once before rendering the button.
void initializeGoogleSignIn({
  required String clientId,
  String callbackFunctionName = 'onGoogleCredentialResponse',
}) {
  try {
    _googleAccountsId.initialize({
      'client_id': clientId,
      'callback': callbackFunctionName,
      'auto_select': false,       // Never auto-sign-in silently
      'cancel_on_tap_outside': false,
    }.jsify()! as JSObject);
  } catch (e) {
    debugPrint('GIS: initialize() failed — GIS script may not be loaded yet: $e');
  }
}

/// Render the official Google Sign-In button inside the HTML element with
/// [elementId].  The button is full-width via `width` option.
/// Returns true if the element was found and rendering was attempted.
bool renderGoogleSignInButton({
  required String elementId,
  int width = 400,
}) {
  try {
    // Find the host DOM element by id
    final element = _domGetElementById(elementId);
    if (element == null) {
      debugPrint('GIS: renderButton() skipped — element #$elementId not in DOM yet.');
      return false;
    }

    _googleAccountsId.renderButton(
      element,
      {
        'theme': 'outline',
        'size': 'large',
        'shape': 'pill',
        'width': width,
        'text': 'signin_with',
        'logo_alignment': 'center',
      }.jsify()! as JSObject,
    );
    return true;
  } catch (e) {
    debugPrint('GIS: renderButton() failed: $e');
    return false;
  }
}

/// Call on logout to prevent GIS from auto-selecting a session on next visit.
void disableGoogleAutoSelect() {
  try {
    _googleAccountsId.disableAutoSelect();
  } catch (_) {
    // Safe to ignore — GIS may not have been initialized if user never used it.
  }
}

// ─── Minimal DOM interop ─────────────────────────────────────────────────────

@JS('document.getElementById')
external JSObject? _domGetElementByIdRaw(JSString id);

JSObject? _domGetElementById(String id) => _domGetElementByIdRaw(id.toJS);
