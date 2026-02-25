import 'package:flutter/material.dart';

class ClayContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color color;
  final double depth;
  final bool emboss;
  final bool spread;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ClayContainer({
    Key? key,
    required this.child,
    this.borderRadius = 30,
    this.color = const Color(0xFFE3F2FF), // Lighter azure for better contrast
    this.depth = 12,
    this.emboss = false,
    this.spread = true,
    this.width,
    this.height,
    this.padding,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    
    // Calculate shadow colors based on HSL for high-fidelity accuracy
    final Color darkShadowColor = hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0))
        .toColor();
    
    final Color lightShadowColor = hsl
        .withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0))
        .toColor();

    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: emboss
            ? [
                // Inner shadows for embossed effect
                BoxShadow(
                  color: darkShadowColor.withOpacity(0.5),
                  offset: Offset(depth / 2, depth / 2),
                  blurRadius: depth.abs(), // Fix: Ensure blurRadius is non-negative
                  spreadRadius: -depth / 2,
                ),
                BoxShadow(
                  color: lightShadowColor,
                  offset: Offset(-depth / 2, -depth / 2),
                  blurRadius: depth.abs(), // Fix: Ensure blurRadius is non-negative
                  spreadRadius: -depth / 2,
                ),
              ]
            : [
                // Main soft shadows to create the "Clay" look
                BoxShadow(
                  color: darkShadowColor.withOpacity(0.6),
                  offset: Offset(depth, depth),
                  blurRadius: (depth * 2.5).abs(), // Fix: Ensure blurRadius is non-negative
                  spreadRadius: spread ? 1 : 0,
                ),
                BoxShadow(
                  color: Colors.white, // Pure white for that high-light pop
                  offset: Offset(-depth, -depth),
                  blurRadius: (depth * 2.5).abs(), // Fix: Ensure blurRadius is non-negative
                  spreadRadius: spread ? 1 : 0,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      ),
    );
  }
}
