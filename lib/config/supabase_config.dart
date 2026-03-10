class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://prghjnknjkrckbiqydgi.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByZ2hqbmtuamtyY2tiaXF5Z2dpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDA4MDksImV4cCI6MjA4NjkxNjgwOX0.xJLCs_dNbPX514vHcjQ_FU_CctS22BKTICzHvRoR4HM',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://link-spec.vercel.app',
  );

  static const String otpApiUrl = String.fromEnvironment(
    'OTP_API_URL',
    defaultValue: 'https://otp-sender-seven.vercel.app',
  );

  static const String profileBucket = String.fromEnvironment(
    'SUPABASE_PROFILE_BUCKET',
    defaultValue: 'profiles',
  );

  static const String postBucket = String.fromEnvironment(
    'SUPABASE_POST_BUCKET',
    defaultValue: 'post-images',
  );

  static const String apiSecretKey = String.fromEnvironment(
    'API_SECRET_KEY',
    defaultValue: '',
  );

  static const String ms365TenantId = String.fromEnvironment(
    'MS365_TENANT_ID',
    defaultValue: '',
  );

  static const String ms365ClientId = String.fromEnvironment(
    'MS365_CLIENT_ID',
    defaultValue: '',
  );

  static const String ms365ClientSecret = String.fromEnvironment(
    'MS365_CLIENT_SECRET',
    defaultValue: '',
  );

  static const String senderEmail = String.fromEnvironment(
    'SENDER_EMAIL',
    defaultValue: '',
  );
}
