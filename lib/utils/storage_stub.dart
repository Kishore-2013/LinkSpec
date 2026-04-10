import 'package:supabase_flutter/supabase_flutter.dart';

/// Web stub: returns EmptyLocalStorage so Web behaviour is unchanged.
/// On mobile (dart:io), the real MobileSessionStorage is used via
/// the conditional import in main.dart.
LocalStorage buildSessionStorage() => const EmptyLocalStorage();
