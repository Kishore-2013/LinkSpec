import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

/// Mobile/Desktop SMTP implementation using the `mailer` package.
/// This file is only compiled on dart:io platforms (mobile, desktop).
///
/// Gmail SMTP settings:
///   Host : smtp.gmail.com
///   Port : 465 (SSL) or 587 (TLS)
///   Auth : Gmail address + 16-char App Password
///          (Generate at: myaccount.google.com → Security → App Passwords)
Future<bool> sendEmail({
  required String senderEmail,
  required String appPassword,
  required String toEmail,
  required String otp,
}) async {
  // gmail() uses smtp.gmail.com:465 with SSL — the mailer package convenience helper.
  final smtpServer = gmail(senderEmail, appPassword);

  final message = Message()
    ..from = Address(senderEmail, 'LinkSpec')
    ..recipients.add(toEmail)
    ..subject = '🔐 Your LinkSpec Verification Code'
    ..html = _buildEmailHtml(otp);

  try {
    final sendReport = await send(message, smtpServer);
    print('MailerService [mobile]: SMTP send report – $sendReport');
    return true;
  } on MailerException catch (e) {
    print('MailerService [mobile]: MailerException – ${e.message}');
    for (final p in e.problems) {
      print('  Problem: ${p.code}: ${p.msg}');
    }
    return false;
  }
}

/// Professional HTML email template for OTP delivery.
String _buildEmailHtml(String otp) => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>LinkSpec Verification Code</title>
</head>
<body style="margin:0;padding:0;background:#F5F5F7;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#F5F5F7;padding:40px 0;">
    <tr>
      <td align="center">
        <table width="480" cellpadding="0" cellspacing="0"
               style="background:#FFFFFF;border-radius:20px;overflow:hidden;
                      box-shadow:0 4px 24px rgba(0,0,0,0.08);">

          <!-- Header -->
          <tr>
            <td style="background:#0066CC;padding:32px;text-align:center;">
              <h1 style="margin:0;color:#FFFFFF;font-size:24px;font-weight:800;
                         letter-spacing:-0.5px;">LinkSpec</h1>
              <p style="margin:8px 0 0;color:rgba(255,255,255,0.8);font-size:14px;">
                Professional Domain Network
              </p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:40px 40px 24px;">
              <h2 style="margin:0 0 12px;color:#1A1A2E;font-size:20px;font-weight:700;">
                Your Verification Code
              </h2>
              <p style="margin:0 0 32px;color:#6B7280;font-size:15px;line-height:1.6;">
                Use the code below to verify your LinkSpec account.
                This code expires in <strong>5 minutes</strong>.
              </p>

              <!-- OTP Box -->
              <div style="background:#F0F6FF;border:2px solid #0066CC;border-radius:16px;
                          padding:24px;text-align:center;margin-bottom:32px;">
                <span style="font-size:42px;font-weight:900;letter-spacing:12px;
                             color:#0066CC;font-family:monospace;">$otp</span>
              </div>

              <p style="margin:0;color:#9CA3AF;font-size:13px;line-height:1.6;">
                🔒 Do <strong>not</strong> share this code with anyone.<br/>
                LinkSpec will never ask for your OTP via phone or email.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#F9FAFB;padding:20px 40px;border-top:1px solid #E5E7EB;">
              <p style="margin:0;color:#9CA3AF;font-size:12px;text-align:center;">
                © 2026 LinkSpec · ApplyWizz Technologies
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
