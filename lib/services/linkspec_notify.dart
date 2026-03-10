import 'package:flutter/material.dart';

enum LinkSpecNotifyType { warning, info, success }

/// Global Notification System with a 'Supportive Assistant' tone.
class LinkSpecNotify {
  /// Displays a floating, top-center notification card.
  static void show(BuildContext context, String message, LinkSpecNotifyType type) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _NotifyCard(
        message: message,
        type: type,
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  /// Maps technical errors to 'Supportive Assistant' strings.
  static String mapError(dynamic error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('same_password') || raw.contains('new password should be different')) {
      return "Ohh! no, it looks like that password was already used! For your safety, could you please select a brand-new one?";
    }
    if (raw.contains('mismatch') || raw.contains('not match')) {
      return "Oops! The passwords don’t quite match up. Would you mind double-checking them for us?";
    }
    if (raw.contains('empty') || raw.contains('required')) {
      return "Wait a second! We need a few more details to get you started. Could you please fill those in?";
    }
    if (raw.contains('invalid_grant') || raw.contains('microsoft')) {
      return "Hiccup alert! There was a small issue with Microsoft login. Would you mind trying once more for us?";
    }
    if (raw.contains('network') || raw.contains('timeout')) {
      return "Slow down! We’re having a little trouble reaching the server. Could you please check your connection and try again?";
    }
    if (raw.contains('429')) {
      return "Deep breath! We're moving a bit too fast. Could you please wait a few seconds before trying again?";
    }

    return "Oh dear! We encountered a small unexpected step. Could you please try that again for us?";
  }
}

class _NotifyCard extends StatefulWidget {
  final String message;
  final LinkSpecNotifyType type;
  final VoidCallback onDismiss;

  const _NotifyCard({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_NotifyCard> createState() => _NotifyCardState();
}

class _NotifyCardState extends State<_NotifyCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

    _ctrl.forward();

    // Start fade out before removal
    Future.delayed(const Duration(milliseconds: 3600), () {
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
    // Supportive Assistant Palette
    final bgColor = {
      LinkSpecNotifyType.warning: const Color(0xFFFFE4D6), // Light Peach
      LinkSpecNotifyType.info: const Color(0xFFE0F2FE),    // Pale Blue
      LinkSpecNotifyType.success: const Color(0xFFDCFCE7), // Soft Mint
    }[widget.type];

    final icon = {
      LinkSpecNotifyType.warning: Icons.lightbulb_outline,
      LinkSpecNotifyType.info: Icons.info_outline,
      LinkSpecNotifyType.success: Icons.check_circle_outline,
    }[widget.type];

    final color = {
      LinkSpecNotifyType.warning: const Color(0xFF9A3412),
      LinkSpecNotifyType.info: const Color(0xFF075985),
      LinkSpecNotifyType.success: const Color(0xFF166534),
    }[widget.type];

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
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
