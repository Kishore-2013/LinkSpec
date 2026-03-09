import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class WebUtils {
  /// Copies text to clipboard and shows a snackbar.
  static Future<void> copyToClipboard(BuildContext context, String text, {String? message}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          width: 280,
        ),
      );
    }
  }

  /// Returns true if the device is a desktop browser.
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width > 900;
}
