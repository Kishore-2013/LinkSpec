// Stub for non-web platforms: no-op implementations of web-only helpers.
// dart:ui_web and package:web are not available on Android/iOS.

/// No-op: platform view registry doesn't apply on mobile.
void registerIframeView(String viewId, String url) {}

/// No-op: web window event listeners don't exist on mobile.
Object? addWebMessageListener(String viewId, void Function(String) onMessage) => null;

/// No-op.
void removeWebMessageListener(Object? listener) {}

/// No-op: window.open doesn't apply on mobile.
void openUrlInNewTab(String url) {}
