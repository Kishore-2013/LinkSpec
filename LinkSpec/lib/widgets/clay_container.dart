import 'package:flutter/material.dart';

/// Isometric-style 3D block container.
/// It creates a "thick slab" look with a hard bottom shadow and a soft outer shadow.
class ClayContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  /// Ignored — kept for API compatibility.
  final Color color;

  /// Depth controls the "thickness" of the 3D slab.
  final double depth;

  /// Emboss = inset / sunken look (text-field wells).
  final bool emboss;

  /// Kept for API compatibility.
  final bool spread;

  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  /// When true, children are clipped to the rounded rect (default true).
  final bool clipContent;

  const ClayContainer({
    Key? key,
    required this.child,
    this.borderRadius = 10,
    this.color = Colors.white,
    this.depth = 4,
    this.emboss = false,
    this.spread = true,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.clipContent = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (emboss) {
      return Container(
        width: width,
        height: height,
        padding: padding,
        margin: margin,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFCFD9E5), width: 1.5),
        ),
        child: clipContent
            ? ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: child,
              )
            : child,
      );
    }

    // ── Isometric 3D Slab Look ──────────────────────────────
    // - Face: white
    // - "Edge": a slightly darker hard shadow directly below
    // - Shadow: soft shadow below the edge
    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFEBEEF2), width: 1),
        boxShadow: [
          // The "3D thickness" edge
          BoxShadow(
            color: const Color(0xFFD1D9E6),
            offset: Offset(0, depth.clamp(0.0, 6.0)),
            blurRadius: 0,
          ),
          // The soft floating shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            offset: Offset(0, depth + 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: clipContent
          ? ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: child,
            )
          : child,
    );
  }
}
