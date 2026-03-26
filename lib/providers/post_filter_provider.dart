import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/post_service.dart';

final postFilterProvider = StateProvider<PostFilter>((ref) => PostFilter.latest);
