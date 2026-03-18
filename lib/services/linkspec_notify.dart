import 'dart:ui';
import 'package:flutter/material.dart';

enum LinkSpecNotifyType { warning, info, success, error }

/// Global Notification System with a 'Supportive Assistant' tone.
class LinkSpecNotify {
  /// Displays a floating, centered notification card.
  static void show(BuildContext context, String message, LinkSpecNotifyType type) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

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

  /// Displays a modal dialog for important sequential steps.
  static void showDialog(
    BuildContext context, 
    String message, 
    LinkSpecNotifyType type, 
    {required VoidCallback onConfirm}
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      pageBuilder: (context, _, __) => _NotifyDialog(
        message: message,
        type: type,
        onConfirm: onConfirm,
      ),
    );
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
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.backOut);

    _ctrl.forward();

    // Start fade out before removal
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
    // Supportive Assistant Palette with transparency for glassmorphism
    final bgColor = {
      LinkSpecNotifyType.warning: const Color(0xFFFFE4D6).withOpacity(0.85),
      LinkSpecNotifyType.info: const Color(0xFFE0F2FE).withOpacity(0.85),
      LinkSpecNotifyType.success: const Color(0xFFDCFCE7).withOpacity(0.85),
      LinkSpecNotifyType.error: const Color(0xFFFEE2E2).withOpacity(0.85),
    }[widget.type];

    final icon = {
      LinkSpecNotifyType.warning: Icons.lightbulb_outline,
      LinkSpecNotifyType.info: Icons.info_outline,
      LinkSpecNotifyType.success: Icons.check_circle_outline,
      LinkSpecNotifyType.error: Icons.error_outline,
    }[widget.type];

    final color = {
      LinkSpecNotifyType.warning: const Color(0xFF9A3412),
      LinkSpecNotifyType.info: const Color(0xFF075985),
      LinkSpecNotifyType.success: const Color(0xFF166534),
      LinkSpecNotifyType.error: const Color(0xFF991B1B),
    }[widget.type];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320, minWidth: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withOpacity(0.1), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 28),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.message,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            height: 1.4,
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
      ),
    );
  }
}

class _NotifyDialog extends StatelessWidget {
  final String message;
  final LinkSpecNotifyType type;
  final VoidCallback onConfirm;

  const _NotifyDialog({
    required this.message,
    required this.type,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final color = {
      LinkSpecNotifyType.warning: const Color(0xFF9A3412),
      LinkSpecNotifyType.info: const Color(0xFF075985),
      LinkSpecNotifyType.success: const Color(0xFF166534),
    }[type];

    final bgColor = {
      LinkSpecNotifyType.warning: const Color(0xFFFFE4D6),
      LinkSpecNotifyType.info: const Color(0xFFE0F2FE),
      LinkSpecNotifyType.success: const Color(0xFFDCFCE7),
    }[type];

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  type == LinkSpecNotifyType.success 
                      ? Icons.celebration_outlined 
                      : Icons.lightbulb_outline, 
                  color: color, 
                  size: 32
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1C1C1E),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Okay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

