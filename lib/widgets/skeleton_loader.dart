import 'package:flutter/material.dart';
import '../widgets/aw_logo.dart';

/// Animated shimmer skeleton that mirrors the home feed layout.
/// Shown while posts are loading.
class HomeSkeletonLoader extends StatefulWidget {
  const HomeSkeletonLoader({Key? key}) : super(key: key);

  @override
  State<HomeSkeletonLoader> createState() => _HomeSkeletonLoaderState();
}

class _HomeSkeletonLoaderState extends State<HomeSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Stack(
          children: [
            SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildSkeletonPostCard(),
                  _buildSkeletonPostCard(hasImage: true),
                  _buildSkeletonPostCard(),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: 0.12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        AWLogo(size: 56, showAppName: false),
                        SizedBox(height: 8),
                        Text(
                          'LinkSpec',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF003366),
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSkeletonPostCard({bool hasImage = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF93C5FD).withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _bone(w: 44, h: 44, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bone(w: 130, h: 13),
                    const SizedBox(height: 6),
                    _bone(w: 90, h: 10),
                  ],
                ),
              ),
              _bone(w: 24, h: 24, radius: 4),
            ],
          ),
          const SizedBox(height: 16),
          _bone(h: 12, radius: 4),
          const SizedBox(height: 8),
          _bone(h: 12, w: 280, radius: 4),
          if (hasImage) ...[
            const SizedBox(height: 16),
            _bone(h: 140, radius: 12),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _bone(w: 56, h: 24, radius: 12),
              const SizedBox(width: 8),
              _bone(w: 56, h: 24, radius: 12),
              const SizedBox(width: 8),
              _bone(w: 56, h: 24, radius: 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bone({double? w, double h = 12, double radius = 6}) {
    return Container(
      width: w ?? double.infinity,
      height: h,
      decoration: BoxDecoration(
        color: Color.lerp(
          const Color(0xFFE2E8F0),
          const Color(0xFFF1F5F9),
          _shimmer.value,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
