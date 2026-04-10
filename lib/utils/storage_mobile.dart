import 'package:supabase_flutter/supabase_flutter.dart';
import 'mobile_session_storage.dart';

/// Mobile (dart:io) side of the conditional import.
/// Returns a SharedPreferences-backed storage so tokens survive app restarts.
LocalStorage buildSessionStorage() => MobileSessionStorage();
