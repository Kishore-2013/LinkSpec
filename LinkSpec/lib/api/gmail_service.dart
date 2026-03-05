import 'mailer_service.dart';

/// Gmail OTP sender — now delegates to the unified MailerService.
/// Kept for backward compatibility with RouteHandler.
class GmailService {
  static Future<bool> sendGmailOTP(String email) =>
      MailerService.sendOTP(email);
}
