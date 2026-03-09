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
}

/// A custom storage implementation for Supabase that uses browser sessionStorage.
/// This fulfills the user requirement: Logout when opening in new window/tab,
/// but keep login state on browser refresh.
class WebSessionStorage extends LocalStorage {
  static const _storageKey = 'supabase.auth.token';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return html.window.sessionStorage.containsKey(_storageKey);
  }

  @override
  Future<String?> accessToken() async {
    return html.window.sessionStorage[_storageKey];
  }

  @override
  Future<void> removePersistedSession() async {
    html.window.sessionStorage.remove(_storageKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    html.window.sessionStorage[_storageKey] = persistSessionString;
  }
}


