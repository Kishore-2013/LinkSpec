import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stores the selected UI language (display name, e.g. "Hindi")
final languageProvider = StateProvider<String>((ref) => 'English');
