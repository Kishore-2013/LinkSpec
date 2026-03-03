import 'persistence_layer.dart';

/// Specialist cache manager for Web/Session storage logic.
class WebCacheManager {
  static const _keyOtp = 'expected_otp';
  static const _keyEmail = 'email_used';
  static const _keyExpiry = 'expiry_time';

  /// Saves verification data to persistent storage.
  static Future<void> saveToCache({
    required String email,
    required String otp,
    required int expiryMinutes,
  }) async {
    final expiry = DateTime.now().add(Duration(minutes: expiryMinutes)).toIso8601String();
    
    await PersistenceLayer.saveSecure(_keyOtp, otp);
    await PersistenceLayer.saveSecure(_keyEmail, email);
    await PersistenceLayer.saveSecure(_keyExpiry, expiry);
  }

  /// Verifies user input against the cached code.
  static Future<Map<String, dynamic>> verifyOtp(String userEntry) async {
    final cachedOtp = await PersistenceLayer.readSecure(_keyOtp);
    final cachedEmail = await PersistenceLayer.readSecure(_keyEmail);
    final expiryStr = await PersistenceLayer.readSecure(_keyExpiry);

    if (cachedOtp == null || expiryStr == null) {
      return {'success': false, 'message': 'No verification code found. Please resend.'};
    }

    final expiry = DateTime.parse(expiryStr);
    if (DateTime.now().isAfter(expiry)) {
      return {
        'success': false, 
        'message': 'Code has expired.', 
        'canResend': true
      };
    }

    if (userEntry == cachedOtp) {
      return {'success': true, 'message': 'Verification successful!', 'email': cachedEmail};
    } else {
      return {
        'success': false, 
        'message': 'Invalid verification code.', 
        'canResend': true
      };
    }
  }

  /// Clears the cache.
  static Future<void> clearCache() async {
    await PersistenceLayer.deleteSecure(_keyOtp);
    await PersistenceLayer.deleteSecure(_keyEmail);
    await PersistenceLayer.deleteSecure(_keyExpiry);
  }
}
