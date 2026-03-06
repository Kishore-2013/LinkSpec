// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_cache.dart';


/// Web implementation — registers window.beforeunload to clear SessionCache.
class WebLifecycleHelper {
  static void register() {
    html.window.onBeforeUnload.listen((_) {
      SessionCache.clearAll();
    });
  }

  static Future<void> checkSession() async {
    if (html.window.sessionStorage['ls_session_active'] == null) {
      // New tab/window! Force sign out to clear localStorage persistent session.
      await Supabase.instance.client.auth.signOut();
      html.window.sessionStorage['ls_session_active'] = 'true';
    }
  }
}

