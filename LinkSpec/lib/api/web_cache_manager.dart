import 'persistence_layer.dart';

/// Specialist cache manager for Web/Session storage logic.
class WebCacheManager {
  static const _keyOtp = 'expected_otp';
  static const _keyEmail = 'email_used';
  static const _keyExpiry = 'expiry_time';
  static const _keySavedPosts = 'saved_post_ids';
  static const _keyJobsBadge = 'unread_jobs_count';
  static const _keyLastNotifiedAppId = 'last_notified_app_id';

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

  /// Temporarily caches the set of saved post IDs to ensure UI consistency 
  /// across tab navigations/refreshes before DB sync completes.
  static Future<void> saveSavedIds(Set<String> ids) async {
    await PersistenceLayer.save(_keySavedPosts, ids.join(','));
  }

  /// Retrieves the temporarily cached set of saved post IDs.
  static Future<Set<String>> getSavedIds() async {
    try {
      final cached = await PersistenceLayer.read(_keySavedPosts);
      if (cached == null || cached.trim().isEmpty) return {};
      return cached.split(',').where((s) => s.isNotEmpty).toSet();
    } catch (e) {
      return {};
    }
  }

  /// Resets the jobs badge count to 0.
  static Future<void> resetJobsBadge() async {
    await PersistenceLayer.save(_keyJobsBadge, '0');
  }

  /// Increments the jobs badge count.
  static Future<void> incrementJobsBadge() async {
    final current = await getJobsBadgeCount();
    await PersistenceLayer.save(_keyJobsBadge, (current + 1).toString());
  }

  /// Gets the current jobs badge count.
  static Future<int> getJobsBadgeCount() async {
    final cached = await PersistenceLayer.read(_keyJobsBadge);
    return int.tryParse(cached ?? '0') ?? 0;
  }

  /// Sets the ID of the last notified application.
  static Future<void> setLastNotifiedAppId(String id) async {
    await PersistenceLayer.save(_keyLastNotifiedAppId, id);
  }

  /// Gets the ID of the last notified application.
  static Future<String?> getLastNotifiedAppId() async {
    return await PersistenceLayer.read(_keyLastNotifiedAppId);
  }

  /// Specialist hook for domain-switching: clears any domain-bound transient data.
  static Future<void> clearDomainCache() async {
    // Currently placeholders, but ensures old domain states don't leak.
    await PersistenceLayer.delete('current_feed_cache');
  }

  /// Clears the cache.
  static Future<void> clearCache() async {
    await PersistenceLayer.deleteSecure(_keyOtp);
    await PersistenceLayer.deleteSecure(_keyEmail);
    await PersistenceLayer.deleteSecure(_keyExpiry);
    await PersistenceLayer.delete(_keySavedPosts);
    await PersistenceLayer.delete(_keyJobsBadge);
    await PersistenceLayer.delete(_keyLastNotifiedAppId);
  }
}
