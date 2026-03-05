import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

/// A production-ready service for sending emails via Gmail SMTP.
class EmailService {
  /// Sends an email using Gmail SMTP and an App Password.
  /// 
  /// Returns [true] if the email was sent successfully, [false] otherwise.
  static Future<bool> sendEmail({
    required String recipientEmail,
    required String subject,
    required String body,
  }) async {
    final String gmailEmail = dotenv.env['GMAIL_SENDER_EMAIL'] ?? '';
    final String appPassword = dotenv.env['GMAIL_APP_PASSWORD'] ?? '';

    if (gmailEmail.isEmpty || appPassword.isEmpty) {
      developer.log('EmailService: Missing Gmail credentials in .env file', name: 'EmailService');
      return false;
    }

    // Configure Gmail SMTP server (Port 465 with SSL - standard mailer helper)
    final smtpServer = gmail(gmailEmail, appPassword);

    // Create the message
    final message = Message()
      ..from = Address(gmailEmail, 'LinkSpec Support')
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..text = body;
      // You can also use ..html = '<h1>Hello</h1>' for HTML emails.

    try {
      final sendReport = await send(message, smtpServer);
      developer.log('EmailService: Message sent: $sendReport', name: 'EmailService');
      return true;
    } on MailerException catch (e) {
      developer.log('EmailService: Message not sent. \n${e.toString()}', name: 'EmailService', error: e);
      for (var p in e.problems) {
        developer.log('EmailService: Problem: ${p.code}: ${p.msg}', name: 'EmailService');
      }
      return false;
    } catch (e) {
      developer.log('EmailService: Unexpected error: $e', name: 'EmailService', error: e);
      return false;
    }
  }
}
