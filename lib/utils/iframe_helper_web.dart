// Web implementation of IFrame helpers.
// Only imported via conditional import when dart.library.html is available.
import 'dart:ui_web' as ui;
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Registers an IFrame platform view for displaying the verification URL on web.
void registerIframeView(String viewId, String url) {
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = web.HTMLIFrameElement()
      ..src = url
      ..setAttribute('allow', 'fullscreen');
    iframe.style.border = 'none';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    return iframe;
  });
}

/// Adds a window 'message' event listener and returns a handle for later removal.
Object? addWebMessageListener(String viewId, void Function(String) onMessage) {
  final listener = (web.MessageEvent event) {
    onMessage(event.data.toString());
  }.toJS as web.EventListener;
  web.window.addEventListener('message', listener);
  return listener;
}

/// Removes a previously added message listener.
void removeWebMessageListener(Object? listener) {
  if (listener != null) {
    web.window.removeEventListener('message', listener as web.EventListener);
  }
}

/// Opens a URL in a new browser tab.
void openUrlInNewTab(String url) {
  web.window.open(url, '_blank');
}
