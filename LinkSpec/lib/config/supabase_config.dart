class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String gmailSenderEmail = String.fromEnvironment(
    'GMAIL_SENDER_EMAIL',
    defaultValue: '',
  );

  static const String gmailAppPassword = String.fromEnvironment(
    'GMAIL_APP_PASSWORD',
    defaultValue: '',
  );

  static const String profileBucket = String.fromEnvironment(
    'SUPABASE_PROFILE_BUCKET',
    defaultValue: 'profiles',
  );

  static const String postBucket = String.fromEnvironment(
    'SUPABASE_POST_BUCKET',
    defaultValue: 'post-images',
  );

  static const String gmailOtpRoute = String.fromEnvironment(
    'GMAIL_OTP_ROUTE',
    defaultValue: '',
  );

  static const String microsoftOtpRoute = String.fromEnvironment(
    'MICROSOFT_OTP_ROUTE',
    defaultValue: '',
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

