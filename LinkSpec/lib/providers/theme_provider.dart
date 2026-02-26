import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeProvider = StateProvider<bool>((ref) => false);

/// Stores the selected UI language (display name, e.g. "Hindi")
final languageProvider = StateProvider<String>((ref) => 'English');
