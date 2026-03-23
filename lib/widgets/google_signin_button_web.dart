// ignore_for_file: avoid_web_libraries_in_flutter
// This file is only compiled on Flutter Web.

import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../config/supabase_config.dart';
import '../utils/google_gis_interop.dart' as gis;

/// Factory used by google_signin_button.dart
Widget buildGoogleSignInButtonView(void Function(String idToken) onCredential) {
  return _GoogleSignInButtonWeb(onCredential: onCredential);
}

class _GoogleSignInButtonWeb extends StatefulWidget {
  final void Function(String idToken) onCredential;
  const _GoogleSignInButtonWeb({Key? key, required this.onCredential}) : super(key: key);

  @override
  State<_GoogleSignInButtonWeb> createState() => _GoogleSignInButtonWebState();
}

class _GoogleSignInButtonWebState extends State<_GoogleSignInButtonWeb> {
  // Fix 2 & 6: Flags for single execution
  static bool? _isGisInitialized;
  bool _isButtonRendered = false;
  
  late final String _viewType;
  late final String _elementId;

  @override
  void initState() {
    super.initState();
    // Generate unique IDs for this instance
    final int id = identityHashCode(this);
    _viewType = 'google-signin-view-$id';
    _elementId = 'google-signin-btn-$id';

    // FIX 2: Initialize GIS only once
    if (_isGisInitialized != true) {
      gis.registerGoogleSignInCallback(widget.onCredential);
      gis.initializeGoogleSignIn(clientId: SupabaseConfig.googleClientId);
      _isGisInitialized = true;
    }

    // Register the platform view factory for this instance
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = _createHostDiv(_elementId);
      // Modern Flutter Web requires returning as JSObject/Object
      return div as JSObject;
    });

    // FIX 1: Ensure renderButton is called ONLY after DOM is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryRender();
    });
  }

  void _tryRender() {
    if (!mounted) return;
    
    // FIX 6: Prevent multiple render calls
    if (_isButtonRendered) return;

    // FIX 1: Verify element ID exists before calling renderButton (handled inside gis helper)
    final success = gis.renderGoogleSignInButton(
      elementId: _elementId,
      width: 400,
    );

    if (success) {
      _isButtonRendered = true;
    } else {
      // If element not in DOM yet (Fix 1), retry after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _tryRender();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX 5: Ensure stable rendering with HtmlElementView
    return SizedBox(
      width: 400,
      height: 48,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}

// ---------------------------------------------------------------------------
// DOM helpers – create a <div> without dart:html
// ---------------------------------------------------------------------------

@JS('document.createElement')
external JSObject _createElementRaw(JSString tag);

@JS()
@staticInterop
class _HtmlElement {}

extension _HtmlElementExt on _HtmlElement {
  @JS('setAttribute')
  external void setAttribute(JSString name, JSString value);
}

_HtmlElement _createHostDiv(String id) {
  final el = _createElementRaw('div'.toJS) as _HtmlElement;
  el.setAttribute('id'.toJS, id.toJS);
  el.setAttribute('style'.toJS, 'width:100%;height:48px;display:flex;align-items:center;justify-content:center;'.toJS);
  return el;
}
