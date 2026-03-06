import 'session_cache.dart';

/// Stub for non-Web platforms.
/// On mobile, closing the app clears the process — SessionCache dies automatically.
class WebLifecycleHelper {
  static void register() {
    // No-op on mobile — process death clears in-memory state automatically.
  }
}

/// Stub storage that does nothing or uses default.
/// Supabase will ignore this if passed null or another default.
class WebSessionStorage extends LocalStorage {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => false;
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<void> removePersistedSession() async {}
  @override
  Future<void> persistSession(String persistSessionString) async {}
}



