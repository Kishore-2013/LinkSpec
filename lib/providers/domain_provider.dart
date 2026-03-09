import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track the current professional domain filter.
/// Defaults to 'Global' (which shows posts from all domains).
final currentDomainProvider = StateProvider<String>((ref) => 'Global');
