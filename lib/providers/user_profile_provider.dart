import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../services/supabase_service.dart';
import 'dart:async';

/// Provider for the current user's profile.
/// Uses AsyncNotifier to handle potential loading/error states and 
/// maintains a realtime subscription for instant UI updates.
class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  RealtimeChannel? _subscription;

  @override
  FutureOr<UserProfile?> build() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    // 1. Initial Fetch
    final data = await Supabase.instance.client
        .from('profiles_dim')
        .select()
        .eq('id', userId)
        .single();
    
    final profile = UserProfile.fromJson(data);

    // 2. Setup Realtime Subscription
    _setupSubscription(userId);

    // Ensure subscription is cleaned up when provider is disposed
    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    return profile;
  }

  void _setupSubscription(String userId) {
    _subscription?.unsubscribe();
    _subscription = SupabaseService.subscribeToProfileChanges(userId, (payload) {
      // Important: Use future to merge with existing state if needed, 
      // but here we just refresh or manually update state.
      state = AsyncData(UserProfile.fromJson(payload));
    });
  }

  /// Manually trigger a refresh from the database.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await Supabase.instance.client
          .from('profiles_dim')
          .select()
          .eq('id', userId)
          .single();
      
      return UserProfile.fromJson(data);
    });
  }

  /// Update state manually (useful after a local successful update).
  void updateState(UserProfile profile) {
    state = AsyncData(profile);
  }
}

final userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(() {
  return UserProfileNotifier();
});
