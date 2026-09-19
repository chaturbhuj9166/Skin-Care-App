import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;
  const NavItem({required this.icon, required this.activeIcon, required this.label, this.badgeCount = 0});
}

/// Bottom navigation bar with a raised circular center action button,
/// matching the Home / Profile screen mockups (Home, Cases, +, Tips, Profile).
class AppBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCenterTap;
  final IconData centerIcon;

  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.onCenterTap,
    this.centerIcon = Icons.add_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final left = items.sublist(0, 2);
    final right = items.sublist(2, 4);

    Widget buildItem(NavItem item, int index) {
      final active = index == currentIndex;
      return Expanded(
        child: InkWell(
          onTap: () => onTap(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active ? item.activeIcon : item.icon,
                    color: active ? AppColors.primary : AppColors.textMuted, size: 24),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            child: PhysicalShape(
              color: AppColors.background,
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.08),
              clipper: _NotchClipper(),
              child: Row(
                children: [
                  ...List.generate(left.length, (i) => buildItem(left[i], i)),
                  const Expanded(child: SizedBox()),
                  ...List.generate(right.length, (i) => buildItem(right[i], i + 2)),
                ],
              ),
            ),
          ),
          Positioned(
            top: -22,
            child: GestureDetector(
              onTap: onCenterTap,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: AppColors.primaryGradient),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Icon(centerIcon, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const notchRadius = 36.0;
    final center = size.width / 2;
    path.moveTo(0, 0);
    path.lineTo(center - notchRadius - 14, 0);
    path.quadraticBezierTo(center - notchRadius, 0, center - notchRadius + 6, 14);
    path.arcToPoint(
      Offset(center + notchRadius - 6, 14),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.quadraticBezierTo(center + notchRadius, 0, center + notchRadius + 14, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Simple flat bottom nav (used by the Doctor app - 5 equal items, no center FAB).
class FlatBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FlatBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == currentIndex;
              final item = items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: AppDurations.micro,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: active ? AppColors.primaryLight : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Icon(active ? item.activeIcon : item.icon,
                                color: active ? AppColors.primary : AppColors.textMuted, size: 22),
                          ),
                          if (item.badgeCount > 0)
                            Positioned(
                              top: -2,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                constraints: const BoxConstraints(minWidth: 16),
                                decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                child: Text(
                                  item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(item.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active ? AppColors.primary : AppColors.textMuted,
                          )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
