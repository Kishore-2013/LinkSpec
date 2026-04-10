// Web implementation for URL operations.
// Only imported on platforms where dart:html is available.
import 'package:web/web.dart' as web;

/// Clears the recovery code tokens from the browser address bar.
void clearLocationUrl() {
  final location = web.window.location;
  if (location.href.contains('code=') || location.href.contains('type=recovery')) {
    web.window.history.replaceState(null, '', location.pathname);
  }
}
