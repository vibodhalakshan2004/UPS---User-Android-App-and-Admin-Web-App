
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ThemeProvider to manage app theme state across the app
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // Cycle: system -> light -> dark -> system
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  void setSystemTheme() {
    _themeMode = ThemeMode.system;
    notifyListeners();
  }
}

// Colors from the logo
const Color primaryColor = Color(0xFFFBC02D); // Yellow
const Color secondaryColor = Color(0xFF388E3C); // Green
const Color accentColor = Color(0xFFD32F2F); // Red
const Color lightBackgroundColor = Color(0xFFFFFDE7);
const Color darkBackgroundColor = Color(0xFF212121);

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        error: accentColor,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: secondaryColor),
        headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: secondaryColor),
        headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: secondaryColor),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: secondaryColor),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: Colors.black87),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: Colors.black54),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.black87, fontWeight: FontWeight.w600),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: secondaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          elevation: 0,
          shadowColor: secondaryColor.withAlpha(102), // 40% opacity
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
        )
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: secondaryColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: secondaryColor),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: secondaryColor,
        unselectedItemColor: Colors.grey,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        error: accentColor,
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      textTheme: textTheme.copyWith(
        displayLarge: textTheme.displayLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
        headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
        headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: primaryColor),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: Colors.white70),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: Colors.white54),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 4,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: secondaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          elevation: 5,
          shadowColor: secondaryColor.withAlpha(102), // 40% opacity
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        )
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(color: primaryColor),
      ),
      cardTheme: CardThemeData(
        elevation: 8,
        shadowColor: Colors.black.withAlpha(102), // 40% opacity
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.grey[850],
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey[400],
        elevation: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
