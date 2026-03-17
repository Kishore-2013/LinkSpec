import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Class to hold additional profile data for Google users in memory.
class GoogleUserProfile {
  final String domain;
  final String? bio;

  GoogleUserProfile({
    required this.domain,
    this.bio,
  });
}

/// Provider to store the Google user's selected domain and bio.
final googleUserProfileProvider = StateProvider<GoogleUserProfile?>((ref) => null);
