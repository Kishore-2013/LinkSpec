import 'package:flutter/material.dart';

/// Global Notification Service for LinkSpec.
/// Replaces harsh error messages with soothing, comfortable popups.
class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Displays a soothing warning popup.
  static void showWarning(dynamic error, {bool isInfo = false}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final message = _mapSoothingMessage(error.toString());
    _showOverlay(context, message, isInfo: isInfo);
  }

  /// Maps technical errors to a 'requesting' and 'comfortable' tone.
  static String _mapSoothingMessage(String raw) {
    if (raw.contains('same_password') || raw.contains('New password should be different')) {
      return "We noticed this is your previous password. Could you please try a fresh one to keep your LinkSpec account extra secure?";
    }
    if (raw.contains('invalid_grant') || raw.contains('Microsoft login')) {
      return "It seems there was a small hiccup with the Microsoft login. Would you mind trying to sign in again?";
    }
    if (raw.contains('Network') || raw.contains('Timeout')) {
      return "We’re having a little trouble reaching the server. Could you please check your connection and try again in a moment?";
    }
    if (raw.contains('invalid_credentials') || raw.contains('Invalid login credentials')) {
      return "The details entered don't seem to match our records. Could you please double-check them for us?";
    }
    if (raw.contains('429') || raw.contains('too many requests')) {
      return "To keep things running smoothly, we have to limit requests briefly. Would you mind waiting a few seconds and trying again?";
    }
    
    // Default fallback in the same soothing tone
    return "We encountered a small unexpected step. Could you please try that again for us? We're here to help.";
  }

  static void _showOverlay(BuildContext context, String message, {bool isInfo = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _SoothingPopupWidget(
        message: message,
        isInfo: isInfo,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }
}

class _SoothingPopupWidget extends StatefulWidget {
  final String message;
  final bool isInfo;
  final VoidCallback onDismiss;

  const _SoothingPopupWidget({
    required this.message,
    required this.isInfo,
    required this.onDismiss,
  });

  @override
  State<_SoothingPopupWidget> createState() => _SoothingPopupWidgetState();
}

class _SoothingPopupWidgetState extends State<_SoothingPopupWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

    _ctrl.forward();

    // Start fade out before removing
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: widget.isInfo ? const Color(0xFFE3F2FD) : const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: widget.isInfo ? const Color(0xFFBBDEFB) : const Color(0xFFFFECB3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isInfo ? Icons.info_outline : Icons.lightbulb_outline,
                        color: widget.isInfo ? const Color(0xFF1E88E5) : const Color(0xFFFFA000),
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: widget.isInfo ? const Color(0xFF0D47A1) : const Color(0xFF795548),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
