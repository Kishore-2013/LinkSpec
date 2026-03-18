import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../services/linkspec_notify.dart';

class WebUtils {
  /// Copies text to clipboard and shows a centered notification.
  static Future<void> copyToClipboard(BuildContext context, String text, {String? message}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      LinkSpecNotify.show(
        context, 
        message ?? 'Copied to clipboard!', 
        LinkSpecNotifyType.success
      );
    }
  }

  /// Returns true if the device is a desktop browser.
  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width > 900;
}
