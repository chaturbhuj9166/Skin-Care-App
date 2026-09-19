import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppRadius {
  AppRadius._();
  static const double card = 12;
  static const double button = 8;
  static const double chip = 999;
}

class AppShadows {
  AppShadows._();
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppDurations {
  AppDurations._();
  static const Duration micro = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 400);
}

class AppTheme {
  AppTheme._();

  static const _poppins = TextStyle(fontFamily: 'Poppins');
  static const _inter = TextStyle(fontFamily: 'Inter');

  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: _poppins.copyWith(fontWeight: FontWeight.w700, color: AppColors.textDark),
      displayMedium: _poppins.copyWith(fontWeight: FontWeight.w700, color: AppColors.textDark),
      headlineLarge: _poppins.copyWith(fontWeight: FontWeight.w700, fontSize: 26, color: AppColors.textDark),
      headlineMedium: _poppins.copyWith(fontWeight: FontWeight.w700, fontSize: 22, color: AppColors.textDark),
      headlineSmall: _poppins.copyWith(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textDark),
      titleLarge: _poppins.copyWith(fontWeight: FontWeight.w600, fontSize: 17, color: AppColors.textDark),
      titleMedium: _poppins.copyWith(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textDark),
      titleSmall: _poppins.copyWith(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textDark),
      bodyLarge: _inter.copyWith(fontSize: 15, color: AppColors.textDark),
      bodyMedium: _inter.copyWith(fontSize: 14, color: AppColors.textLight),
      bodySmall: _inter.copyWith(fontSize: 12, color: AppColors.textLight),
      labelLarge: _inter.copyWith(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textDark),
      labelMedium: _inter.copyWith(fontSize: 12, color: AppColors.textLight),
      labelSmall: _inter.copyWith(fontSize: 11, color: AppColors.textMuted),
    );
  }

  static ThemeData light() {
    final textTheme = _textTheme;
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.background,
      ),
      textTheme: textTheme,
      fontFamily: 'Inter',
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.background,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: _inter.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border),
          textStyle: _inter.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: _inter.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: _inter.copyWith(color: AppColors.textMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button + 4),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button + 4),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button + 4),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button + 4),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        labelStyle: _inter.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
