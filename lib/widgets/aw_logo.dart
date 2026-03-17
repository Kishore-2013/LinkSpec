import 'package:flutter/material.dart';

/// AWLogo — Reusable ApplyWizz logo widget.
///
/// displays the official `apply_wizz_logo.jpg` asset inside a premium
/// rounded container that matches the brand's design language.
///
/// Parameters:
///   [size]         — width/height of the logo container (default 80).
///   [showAppName]  — render the "ApplyWizz" label below the badge.
///   [showTagline]  — render the tagline (only when [showAppName] is true).
class AWLogo extends StatelessWidget {
  const AWLogo({
    Key? key,
    this.size = 80,
    this.showAppName = false,
    this.showTagline = false,
  }) : super(key: key);

  final double size;
  final bool showAppName;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final badge = _buildBadge();

    if (!showAppName) return badge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(height: 16),
        Text(
          'ApplyWizz',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1C1C1E),
                letterSpacing: 0.5,
              ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 6),
          Text(
            'The Better Side Of Recruitment',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildBadge() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A66C2).withOpacity(0.25),
            blurRadius: size * 0.28,
            spreadRadius: size * 0.07,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/apply_wizz_logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
