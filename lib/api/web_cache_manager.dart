import 'dart:typed_data';
import 'persistence_layer.dart';

class WebCacheManager {
  static const _keyOtp = 'expected_otp';
  static const _keyEmail = 'email_used';
  static const _keyExpiry = 'expiry_time';
  static const _keySavedPosts = 'saved_post_ids';
  static const _keyJobsBadge = 'unread_jobs_count';
  static const _keyLastNotifiedAppId = 'last_notified_app_id';
  static const _keyJobsCache = 'session_jobs_cache';
  static const _keyImagesPrefix = 'img_cache_';

  static final Map<String, dynamic> _memoryCache = {};

  static Future<void> saveToCache({
    required String email,
    required String otp,
    required int expiryMinutes,
  }) async {
    final expiry =
        DateTime.now().add(Duration(minutes: expiryMinutes)).toIso8601String();

    await PersistenceLayer.saveSecure(_keyOtp, otp);
    await PersistenceLayer.saveSecure(_keyEmail, email);
    await PersistenceLayer.saveSecure(_keyExpiry, expiry);
  }

  static Future<Map<String, dynamic>> verifyOtp(String userEntry) async {
    final cachedOtp = await PersistenceLayer.readSecure(_keyOtp);
    final cachedEmail = await PersistenceLayer.readSecure(_keyEmail);
    final expiryStr = await PersistenceLayer.readSecure(_keyExpiry);

    if (cachedOtp == null || expiryStr == null) {
      return {
        'success': false,
        'message': 'No verification code found. Please resend.'
      };
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
      return {
        'success': true,
        'message': 'Verification successful!',
        'email': cachedEmail
      };
    } else {
      return {
        'success': false,
        'message': 'Invalid verification code.',
        'canResend': true
      };
    }
  }

  static Future<void> saveSavedIds(Set<String> ids) async {
    await PersistenceLayer.save(_keySavedPosts, ids.join(','));
  }

  static Future<Set<String>> getSavedIds() async {
    try {
      final cached = await PersistenceLayer.read(_keySavedPosts);
      if (cached == null || cached.trim().isEmpty) return {};
      return cached.split(',').where((s) => s.isNotEmpty).toSet();
    } catch (e) {
      return {};
    }
  }

  static Future<void> resetJobsBadge() async {
    await PersistenceLayer.save(_keyJobsBadge, '0');
  }

  static Future<void> incrementJobsBadge() async {
    final current = await getJobsBadgeCount();
    await PersistenceLayer.save(_keyJobsBadge, (current + 1).toString());
  }

  static Future<int> getJobsBadgeCount() async {
    final cached = await PersistenceLayer.read(_keyJobsBadge);
    return int.tryParse(cached ?? '0') ?? 0;
  }

  static Future<void> setLastNotifiedAppId(String id) async {
    await PersistenceLayer.save(_keyLastNotifiedAppId, id);
  }

  static Future<String?> getLastNotifiedAppId() async {
    return await PersistenceLayer.read(_keyLastNotifiedAppId);
  }

  static Future<void> clearDomainCache() async {
    await PersistenceLayer.delete('current_feed_cache');
    _memoryCache.remove('jobs_fetched');
  }

  static Future<void> cacheJson(String key, String json) async {
    await PersistenceLayer.save(key, json);
    _memoryCache[key] = json;
  }

  static Future<String?> getCachedJson(String key) async {
    if (_memoryCache.containsKey(key)) return _memoryCache[key];
    final cached = await PersistenceLayer.read(key);
    if (cached != null) _memoryCache[key] = cached;
    return cached;
  }

  static Future<void> cacheImage(String url, Uint8List bytes) async {
    final key = '$_keyImagesPrefix${url.hashCode}';
    try {
      final base64String = Uri.encodeComponent(String.fromCharCodes(bytes));
      await PersistenceLayer.save(key, base64String);
    } catch (_) {}
  }

  static Future<Uint8List?> getCachedImage(String url) async {
    final key = '$_keyImagesPrefix${url.hashCode}';
    final cached = await PersistenceLayer.read(key);
    if (cached == null) return null;
    try {
      return Uint8List.fromList(Uri.decodeComponent(cached).codeUnits);
    } catch (_) {
      return null;
    }
  }

  static List<dynamic>? _sessionJobs;

  static void setSessionJobs(List<dynamic> jobs) {
    _sessionJobs = jobs;
  }

  static List<dynamic>? getSessionJobs() {
    return _sessionJobs;
  }

  static Future<void> clearCache() async {
    await PersistenceLayer.deleteSecure(_keyOtp);
    await PersistenceLayer.deleteSecure(_keyEmail);
    await PersistenceLayer.deleteSecure(_keyExpiry);
    await PersistenceLayer.delete(_keySavedPosts);
    await PersistenceLayer.delete(_keyJobsBadge);
    await PersistenceLayer.delete(_keyLastNotifiedAppId);
  }
}
