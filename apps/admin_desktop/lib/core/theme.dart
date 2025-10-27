import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color primaryColor = Color(0xFFFBC02D); // UPS yellow
const Color secondaryColor = Color(0xFF2F7D32); // municipal green
const Color accentColor = Color(0xFFD32F2F);

class DesktopTheme {
  static ThemeData light() {
    const scaffoldBackground = Color(0xFFF3F6FB);
    const headlineColor = Color(0xFF1A2435);
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: secondaryColor,
      brightness: Brightness.light,
      primary: const Color(0xFF2F7D32),
      secondary: primaryColor,
      tertiary: const Color(0xFF1565C0),
    ).copyWith(
      surface: const Color(0xFFFFFFFF),
      surfaceTint: const Color(0xFFE8F1FF),
      surfaceContainerLowest: const Color(0xFFF7FAFE),
      surfaceContainerLow: const Color(0xFFF1F5FB),
      surfaceContainerHigh: const Color(0xFFE3EAF5),
      surfaceContainerHighest: const Color(0xFFD5DFEE),
      onSurface: const Color(0xFF172033),
      onSurfaceVariant: const Color(0xFF4A556C),
      outline: const Color(0xFFB5C2D3),
      outlineVariant: const Color(0xFFE2E8F1),
    );
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: headlineColor,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
          color: headlineColor,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: colorScheme.onSurface,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shadowColor: const Color(0x0A000000),
        surfaceTintColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      appBarTheme: AppBarTheme(
        surfaceTintColor: Colors.transparent,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
  dialogTheme: DialogThemeData(backgroundColor: colorScheme.surface),
      dividerTheme: DividerThemeData(color: colorScheme.outline.withValues(alpha: 0.6)),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: colorScheme.onSurfaceVariant,
        tileColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.onSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: colorScheme.surface),
      ),
    );
  }

  static ThemeData dark() {
    const scaffoldBackground = Color(0xFF090F18);
    const onSurface = Color(0xEBFFFFFF);
    const onSurfaceVariant = Color(0xB3FFFFFF);
    const headlineColor = Color(0xF0FFFFFF);
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: secondaryColor,
      brightness: Brightness.dark,
      primary: const Color(0xFF58D48C),
      secondary: primaryColor,
      tertiary: const Color(0xFF4DA3FF),
    ).copyWith(
      surface: const Color(0xFF101726),
      surfaceTint: const Color(0xFF1C2540),
      surfaceContainerLowest: const Color(0xFF080C15),
      surfaceContainerLow: const Color(0xFF111827),
      surfaceContainerHigh: const Color(0xFF1A2335),
      surfaceContainerHighest: const Color(0xFF1F2B41),
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: const Color(0xFF3D475D),
      outlineVariant: const Color(0xFF293144),
      shadow: Colors.black,
    );
    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: headlineColor,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
          color: headlineColor,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: colorScheme.onSurface,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        shadowColor: const Color(0x2E000000),
        surfaceTintColor: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      appBarTheme: AppBarTheme(
        surfaceTintColor: Colors.transparent,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
  dialogTheme: DialogThemeData(backgroundColor: colorScheme.surface),
      dividerTheme: DividerThemeData(color: colorScheme.outline.withValues(alpha: 0.6)),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        iconColor: colorScheme.onSurfaceVariant,
        tileColor: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: colorScheme.onSurface),
      ),
    );
  }
}

class AppTheme {
  static ThemeData get lightTheme => DesktopTheme.light();
  static ThemeData get darkTheme => DesktopTheme.dark();
}
