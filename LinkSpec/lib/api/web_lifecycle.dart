// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'session_cache.dart';

/// Web implementation — registers window.beforeunload to clear SessionCache.
class WebLifecycleHelper {
  static void register() {
    html.window.onBeforeUnload.listen((_) {
      SessionCache.clearAll();
    });
  }
}
