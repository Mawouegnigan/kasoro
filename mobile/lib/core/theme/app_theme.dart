import 'package:flutter/material.dart';

/// Thème centralisé. Palette provisoire — à affiner avec l'identité
/// visuelle définitive de Kasoro (le nom vient du yoruba "jẹ́ ká sọ̀rọ̀").
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF1E7A5F); // vert profond, chaleureux
  static const Color secondary = Color(0xFFE8A33D); // ocre
  static const Color background = Color(0xFFFAF7F2);

  static ThemeData get light {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
