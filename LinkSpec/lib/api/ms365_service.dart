import 'mailer_service.dart';

/// Organization email OTP sender — delegates to unified MailerService.
/// Uses the same SMTP/Supabase path as GmailService.
/// Kept for backward compatibility with RouteHandler.
class MS365Service {
  static Future<bool> sendOrganizationOTP(String email) =>
      MailerService.sendOTP(email);
}
