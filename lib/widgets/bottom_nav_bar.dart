import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/scroll_provider.dart';

/// A modern, LinkedIn-style floating bottom navigation bar.
class BottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int? unreadMessages;
  final int? unreadNotifications;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.unreadMessages,
    this.unreadNotifications,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(navVisibilityProvider);
    final isForceHidden = ref.watch(navForceHiddenProvider);
    final bool effectiveVisible = isVisible && !isForceHidden;

    return AnimatedSlide(
      offset: effectiveVisible ? Offset.zero : const Offset(0, 2),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNavItem(0, Icons.home_rounded, 'Home'),
          _buildNavItem(1, Icons.search_rounded, 'Search'),
          _buildNavItem(2, Icons.groups_rounded, 'Network'),
          _buildNavItem(3, Icons.add_circle_outline_rounded, 'Post'),
          _buildNavItem(4, Icons.mail_rounded, 'Messages', badge: unreadMessages),
          _buildNavItem(5, Icons.business_center_rounded, 'Jobs'),
        ],
      ),
    ));
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int? badge}) {
    final bool isSelected = currentIndex == index;
    final color = isSelected ? const Color(0xFF0066CC) : Colors.grey[600];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(index),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: color,
                      size: 26,
                    ),
                    if (badge != null && badge > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(
                            child: Text(
                              badge > 9 ? '9+' : '$badge',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
