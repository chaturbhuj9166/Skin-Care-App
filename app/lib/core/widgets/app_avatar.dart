import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A consistent placeholder avatar (initials on a soft tinted circle) so the
/// app looks polished without depending on network images.
class AppAvatar extends StatelessWidget {
  final String initials;
  final int seed;
  final double size;
  final bool online;
  final String? imageUrl;

  const AppAvatar({
    super.key,
    required this.initials,
    required this.seed,
    this.size = 44,
    this.online = false,
    this.imageUrl,
  });

  static const List<List<Color>> _palettes = [
    [Color(0xFF0A7C6E), Color(0xFF14B8A6)],
    [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    [Color(0xFF6366F1), Color(0xFF818CF8)],
    [Color(0xFFEC4899), Color(0xFFF472B6)],
    [Color(0xFF22C55E), Color(0xFF4ADE80)],
    [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _palettes[seed % _palettes.length];
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: palette, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: hasImage
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => _InitialsText(initials: initials, size: size),
            )
          : _InitialsText(initials: initials, size: size),
    );

    if (!online) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _InitialsText extends StatelessWidget {
  final String initials;
  final double size;
  const _InitialsText({required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.36,
      ),
    );
  }
}
