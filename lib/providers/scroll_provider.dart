import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to store the global ScrollController instance.
/// This is used to synchronize scroll events across the entire app.
final globalScrollControllerProvider = Provider<ScrollController>((ref) {
  final controller = ScrollController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

/// Provider to track bottom navigation bar visibility.
final navVisibilityProvider = StateProvider<bool>((ref) => true);

/// Provider to force hide the navbar (e.g. on Chat screen).
final navForceHiddenProvider = StateProvider<bool>((ref) => false);
