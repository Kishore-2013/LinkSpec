import 'dart:io';
import 'package:linkSpec/services/email_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // 1. Load the .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('Error loading .env file: $e');
    exit(1);
  }

  final String targetEmail = '22211A1121@gmail.com';
  final String otp = '482931'; // Sample 6-digit OTP

  print('Attempting to send OTP test to $targetEmail...');

  final bool success = await EmailService.sendEmail(
    recipientEmail: targetEmail,
    subject: 'LinkSpec Verification Code: $otp',
    body: 'Your LinkSpec Verification Code is: $otp. This code expires in 5 minutes. Do not share this with anyone.',
  );

  if (success) {
    print('SUCCESS: Email sent to $targetEmail');
    exit(0);
  } else {
    print('FAILURE: Email could not be sent. Check your SMTP configuration and Gmail App Password.');
    exit(1);
  }
}
