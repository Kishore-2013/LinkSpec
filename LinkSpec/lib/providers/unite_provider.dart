import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';

/// Tracks connection (Unite) status by User ID.
/// Statuses: 'none', 'pending_sent', 'pending_received', 'connected'
final uniteProvider = StateNotifierProvider<UniteNotifier, Map<String, String>>((ref) {
  return UniteNotifier();
});

class UniteNotifier extends StateNotifier<Map<String, String>> {
  UniteNotifier() : super({});

  void setUniteStatus(String userId, String status) {
    state = {...state, userId: status};
  }

  Future<void> loadStatus(String userId) async {
    final status = await SupabaseService.getConnectionRequestStatus(userId);
    setUniteStatus(userId, status);
  }

  Future<void> sendRequest(String userId) async {
    await SupabaseService.sendUniteRequest(userId);
    setUniteStatus(userId, 'pending_sent');
  }

  Future<void> withdrawRequest(String userId) async {
    await SupabaseService.withdrawUniteRequest(userId);
    setUniteStatus(userId, 'none');
  }

  Future<void> acceptRequest(String userId) async {
    await SupabaseService.acceptUniteRequest(userId);
    setUniteStatus(userId, 'connected');
  }
}
