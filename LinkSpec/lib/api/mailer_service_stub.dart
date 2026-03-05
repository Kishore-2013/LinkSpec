/// Web stub for the SMTP mailer.
/// On web, dart:io is unavailable so SMTP is not possible.
/// MailerService automatically uses Supabase on web, so this is never called.
Future<bool> sendEmail({
  required String senderEmail,
  required String appPassword,
  required String toEmail,
  required String otp,
}) async {
  // Should never be reached on web — MailerService routes to Supabase instead.
  throw UnsupportedError('Gmail SMTP is not supported on Flutter Web.');
}
