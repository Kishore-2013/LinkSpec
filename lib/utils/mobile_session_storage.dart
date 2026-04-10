// ignore_for_file: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SharedPreferences-backed [LocalStorage] for Supabase auth tokens on Android/iOS.
/// Keeps users logged in across app restarts on mobile.
/// Used via conditional import in main.dart — never imported directly on Web.
class MobileSessionStorage extends LocalStorage {
  static const _key = 'supabase.session';

  @override
  Future<void> initialize() async {
    // SharedPreferences initializes lazily — nothing to do here.
  }

  @override
  Future<String?> accessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<bool> hasAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
