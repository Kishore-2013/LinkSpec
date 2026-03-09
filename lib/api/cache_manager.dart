import 'persistence_layer.dart';

/// Manages secure local storage for OTP and sensitive user data.
class CacheManager {
  // Storage keys
  static const _keyOtp = 'temp_otp';
  static const _keyEmail = 'user_email';
  static const _keyExpiry = 'expiry_time';

  /// Encrypts and saves the OTP, email, and its expiry time.
  static Future<void> saveOtp({
    required String email,
    required String otp,
    required int expiryMinutes,
  }) async {
    final expiryTime = DateTime.now().add(Duration(minutes: expiryMinutes)).toIso8601String();
    
    await PersistenceLayer.saveSecure(_keyOtp, otp);
    await PersistenceLayer.saveSecure(_keyEmail, email);
    await PersistenceLayer.saveSecure(_keyExpiry, expiryTime);
  }

  /// Retrieves cached OTP data.
  static Future<Map<String, String?>> getOtp() async {
    final otp = await PersistenceLayer.readSecure(_keyOtp);
    final email = await PersistenceLayer.readSecure(_keyEmail);
    final expiry = await PersistenceLayer.readSecure(_keyExpiry);
    
    return {
      'otp': otp,
      'email': email,
      'expiry': expiry,
    };
  }

  /// Clears all cached OTP related data.
  static Future<void> clearCache() async {
    await PersistenceLayer.deleteSecure(_keyOtp);
    await PersistenceLayer.deleteSecure(_keyEmail);
    await PersistenceLayer.deleteSecure(_keyExpiry);
  }
}
