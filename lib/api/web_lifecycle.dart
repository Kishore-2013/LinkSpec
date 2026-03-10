// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_cache.dart';


/// Web implementation — registers window.beforeunload to clear SessionCache.
class WebLifecycleHelper {
  static void register() {
    // For Wasm compatibility, use package:web. 
    // Note: window.onBeforeUnload is not directly available in the same way,
    // we use addEventListener for broad compatibility.
    web.window.addEventListener('beforeunload', (web.Event e) {
       SessionCache.clearAll();
    }.toJS);
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
    return web.window.sessionStorage.getItem(_storageKey) != null;
  }

  @override
  Future<String?> accessToken() async {
    return web.window.sessionStorage.getItem(_storageKey);
  }

  @override
  Future<void> removePersistedSession() async {
    web.window.sessionStorage.removeItem(_storageKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    web.window.sessionStorage.setItem(_storageKey, persistSessionString);
  }
}


