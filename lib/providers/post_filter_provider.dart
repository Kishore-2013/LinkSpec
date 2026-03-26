import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/post_service.dart';

final postFilterProvider = StateProvider<PostFilter>((ref) => PostFilter.home);

/// Signal to the Home Screen to reset the feed and scroll to top.
final homeRefreshProvider = StateProvider<int>((ref) => 0);

