import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A platform-agnostic persistence layer.
/// Switches between Secure Storage (Mobile) and Shared Preferences/Web Storage (Web)
/// where appropriate, or ensures the existing plugins are used correctly for the platform.
class PersistenceLayer {
  static const _secureStorage = FlutterSecureStorage();
  
  /// Saves sensitive data. 
  /// On Web, flutter_secure_storage uses localStorage by default.
  static Future<void> saveSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// Reads sensitive data.
  static Future<String?> readSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  /// Deletes sensitive data.
  static Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  /// Saves non-sensitive data using SharedPreferences.
  static Future<void> save(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  /// Reads non-sensitive data.
  static Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Clears all non-sensitive cached data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
