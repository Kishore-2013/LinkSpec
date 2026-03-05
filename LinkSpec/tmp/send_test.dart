import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

void main() async {
  final String gmailEmail = 'ch.kishoryadav.03@gmail.com';
  final String appPassword = 'pptdjfvvbsswzxhc';
  final String targetEmail = '22211A1121@gmail.com';
  final String otp = '482931';

  print('Testing SMTP direct send to $targetEmail...');

  // Use the standard gmail() helper which uses smtp.gmail.com:465 with SSL
  final smtpServer = gmail(gmailEmail, appPassword);
  
  final message = Message()
    ..from = Address(gmailEmail, 'LinkSpec Support')
    ..recipients.add(targetEmail)
    ..subject = '🔐 Your LinkSpec Verification Code: $otp'
    ..text = 'Your LinkSpec Verification Code is: $otp. This code expires in 5 minutes. Do not share this with anyone.';

  try {
    final sendReport = await send(message, smtpServer);
    print('SUCCESS: Message sent to $targetEmail. Report: $sendReport');
    exit(0);
  } catch (e) {
    print('FAILURE: Error sending email: $e');
    exit(1);
  }
}
