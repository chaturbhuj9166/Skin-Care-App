import 'package:flutter/material.dart';

/// Design tokens from the SkinCare App spec.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0A7C6E); // Teal
  static const Color primaryDark = Color(0xFF07584E);
  static const Color primaryLight = Color(0xFFE3F3F1);

  static const Color secondary = Color(0xFF22C55E); // Green
  static const Color secondaryLight = Color(0xFFE6F9EE);

  static const Color accent = Color(0xFFF59E0B); // Amber
  static const Color accentLight = Color(0xFFFEF3E2);

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8FAFC);

  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFDE9E9);
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFE6F9EE);
  static const Color warning = Color(0xFFF59E0B);

  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFEEF2F6);

  // Case status colors
  static const Color statusPending = Color(0xFF94A3B8); // Grey
  static const Color statusAssigned = Color(0xFF3B82F6); // Blue
  static const Color statusInReview = Color(0xFFF59E0B); // Orange/Amber
  static const Color statusSolved = Color(0xFF22C55E); // Green
  static const Color statusClosed = Color(0xFF64748B); // Slate

  static const List<Color> primaryGradient = [Color(0xFF0A7C6E), Color(0xFF0F9C8A)];
  static const List<Color> splashGradient = [Color(0xFFFFFFFF), Color(0xFFDDF2EC), Color(0xFFC9EBE1)];
}
