import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class SupabaseConfig {
  static String get supabaseUrl => dotenv.get(
    'SUPABASE_URL',
    fallback: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://prghjnknjkrckbiqydgi.supabase.co',
    ),
  );

  static String get supabaseAnonKey => dotenv.get(
    'SUPABASE_ANON_KEY',
    fallback: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByZ2hqbmtuamtyY2tiaXF5Z2dpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDA4MDksImV4cCI6MjA4NjkxNjgwOX0.xJLCs_dNbPX514vHcjQ_FU_CctS22BKTICzHvRoR4HM',
    ),
  );

  static String get apiBaseUrl => dotenv.get(
    'API_BASE_URL',
    fallback: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://link-spec.vercel.app',
    ),
  );

  static String get otpApiUrl => dotenv.get(
    'OTP_API_URL',
    fallback: const String.fromEnvironment(
      'OTP_API_URL',
      defaultValue: 'https://otp-sender-seven.vercel.app',
    ),
  );

  static String get profileBucket => dotenv.get(
    'SUPABASE_PROFILE_BUCKET',
    fallback: const String.fromEnvironment(
      'SUPABASE_PROFILE_BUCKET',
      defaultValue: 'profiles',
    ),
  );

  static String get postBucket => dotenv.get(
    'SUPABASE_POST_BUCKET',
    fallback: const String.fromEnvironment(
      'SUPABASE_POST_BUCKET',
      defaultValue: 'post-images',
    ),
  );

  static String get apiSecretKey => dotenv.get(
    'API_SECRET_KEY',
    fallback: const String.fromEnvironment(
      'API_SECRET_KEY',
      defaultValue: '',
    ),
  );

  static String get ms365TenantId => dotenv.get(
    'MS365_TENANT_ID',
    fallback: const String.fromEnvironment(
      'MS365_TENANT_ID',
      defaultValue: '',
    ),
  );

  static String get ms365ClientId => dotenv.get(
    'MS365_CLIENT_ID',
    fallback: const String.fromEnvironment(
      'MS365_CLIENT_ID',
      defaultValue: '',
    ),
  );

  static String get ms365ClientSecret => dotenv.get(
    'MS365_CLIENT_SECRET',
    fallback: const String.fromEnvironment(
      'MS365_CLIENT_SECRET',
      defaultValue: '',
    ),
  );

  static String get senderEmail => dotenv.get(
    'SENDER_EMAIL',
    fallback: const String.fromEnvironment(
      'SENDER_EMAIL',
      defaultValue: '',
    ),
  );

  /// Google Identity Services (GIS) — OAuth 2.0 Web Client ID
  static String get googleClientId {
    final String? envId = dotenv.maybeGet('GOOGLE_CLIENT_ID');
    if (envId != null && envId.isNotEmpty) return envId;

    if (kIsWeb) {
      // REGISTERED Web Client ID (matches origins in Google Console)
      return '761906978717-tvdv5e4ju6tdc4i12u8e5sepuvhsegla.apps.googleusercontent.com';
    } else {
      // Mobile Client ID (matches Android google-services.json)
      return '997802400886-o01jhgr7c5d6ises1kra9mmnmu4ibrhj.apps.googleusercontent.com';
    }
  }
}
