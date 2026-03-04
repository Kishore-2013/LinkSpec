import 'session_cache.dart';

/// Stub for non-Web platforms.
/// On mobile, closing the app clears the process — SessionCache dies automatically.
class WebLifecycleHelper {
  static void register() {
    // No-op on mobile — process death clears in-memory state automatically.
  }
}
