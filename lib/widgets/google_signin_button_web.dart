// ignore_for_file: avoid_web_libraries_in_flutter
// This file is only compiled on Flutter Web.

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../utils/google_gis_interop.dart' as gis;

// Counter to generate unique view-type IDs per button instance.
int _viewCounter = 0;

// ---------------------------------------------------------------------------
// DOM helpers – create a <div> without dart:html
// ---------------------------------------------------------------------------

@JS('document.createElement')
external JSObject _createElementRaw(JSString tag);

@JS()
@staticInterop
class _HtmlElement {}

extension _HtmlElementExt on _HtmlElement {
  external set id(JSString value);
  external set style(JSString value);
}

JSObject _createHostDiv(String id) {
  final el = _createElementRaw('div'.toJS);
  final typed = el as _HtmlElement;
  typed.id = id.toJS;
  typed.style =
      'width:100%;height:48px;display:flex;align-items:center;justify-content:center;'
          .toJS;
  return el;
}

// ---------------------------------------------------------------------------
// Public factory used by google_signin_button.dart
// ---------------------------------------------------------------------------

Widget buildGoogleSignInButtonView(void Function(String idToken) onCredential) {
  // Each button instance needs a unique viewType so Flutter's platform view
  // registry doesn't collide between multiple button instances.
  final int instanceId = _viewCounter++;
  final String viewType = 'google-signin-btn-$instanceId';
  final String elementId = 'google-signin-div-$instanceId';

  // Register the Flutter callback so GIS can reach Dart.
  gis.registerGoogleSignInCallback(onCredential);

  // Register the platform view factory — creates a <div> for GIS to inject into.
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final divElement = _createHostDiv(elementId);

    // Recursive retry function to ensure the element is in DOM before rendering.
    void tryRender(int attempt) {
      if (attempt > 10) {
        debugPrint('GIS: Failed to render button after 10 attempts.');
        return;
      }

      final success = gis.renderGoogleSignInButton(
        elementId: elementId,
        width: 400,
      );

      if (!success) {
        // Retry after a short delay (50ms)
        Future.delayed(const Duration(milliseconds: 50), () => tryRender(attempt + 1));
      }
    }

    // Schedule GIS initialization + recursive render retry.
    Future.microtask(() {
      gis.initializeGoogleSignIn(clientId: SupabaseConfig.googleClientId);
      tryRender(1);
    });

    return divElement;
  });

  return HtmlElementView(viewType: viewType);
}
