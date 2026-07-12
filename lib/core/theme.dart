import 'package:flutter/material.dart';

/// Palette centralisée : une seule source de vérité pour toutes les couleurs.
class AppColors {
  static const fond = Color(0xFF0A0E21);
  static const carte = Color(0xFF1D1E33);
  static const primaire = Color(0xFF4C4DDC); // Bleu (Admin, ventes)
  static const succes = Color(0xFF00E676); // Vert (Secrétaire, bénéfices)
  static const danger = Color(0xFFFF5252);
  static const alerte = Colors.orangeAccent;
}

ThemeData buildAppTheme() {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: AppColors.fond,
    cardColor: AppColors.carte,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.fond,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 20,
        letterSpacing: 1.0,
      ),
      iconTheme: IconThemeData(color: Colors.white, size: 26),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.carte,
      selectedItemColor: AppColors.primaire,
      unselectedItemColor: Colors.white38,
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: AppColors.primaire,
      secondary: AppColors.succes,
      error: AppColors.danger,
      brightness: Brightness.dark,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.carte,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.carte,
      labelStyle: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      hintStyle: const TextStyle(color: Colors.white38),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaire, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
    ),
  );
}
