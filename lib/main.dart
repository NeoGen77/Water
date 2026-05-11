import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Pour SQLite sur Windows
import 'dart:io'; // Pour détecter si on est sur Windows

// Importation de tes 3 écrans
import 'screens/dashboard_screen.dart';
import 'screens/operations_screen.dart';
import 'screens/invoices_screen.dart';

void main() {
  // 1. Initialisation obligatoire des widgets Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialisation de SQLite pour les ordinateurs (Windows/Linux)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 3. Lancement de l'application
  runApp(const WaterStockApp());
}

class WaterStockApp extends StatelessWidget {
  const WaterStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Dépôt Eau',
      debugShowCheckedModeBanner: false, // Enlève le petit bandeau "DEBUG" en haut à droite

      // --- THÈME BLEU NUIT PROFESSIONNEL ---
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        cardColor: const Color(0xFF1D1E33),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E21),
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1D1E33),
          selectedItemColor: Color(0xFF4C4DDC), // Bleu électrique pour l'onglet actif
          unselectedItemColor: Colors.grey,     // Gris pour les autres
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF4C4DDC),
          secondary: const Color(0xFF00E676),
          error: const Color(0xFFFF5252),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

// --- LE SYSTÈME D'ONGLETS (NAVIGATION DU BAS) ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Liste de tes écrans
  final List<Widget> _screens = [
    const DashboardScreen(),
    const OperationsScreen(),
    const InvoicesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Change l'écran affiché
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Opérations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Caisse',
          ),
        ],
      ),
    );
  }
}