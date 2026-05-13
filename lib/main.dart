import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

// Importation de tous tes écrans
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/operations_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // LA ligne POUR SUPABASE

Future<void> main() async {
  // S'assure que les widgets sont prêts avant d'initialiser des bases de données
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation pour Windows/Linux (ton code existant)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialisation de Supabase
  await Supabase.initialize(
    url: 'https://tsjbhknzswlykydvpdgv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRzamJoa256c3dseWt5ZHZwZGd2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg2MjAyODgsImV4cCI6MjA5NDE5NjI4OH0.QdXEE-hyOdfXhQvbKr5nJfjcR82m3eGVIm6_6WRWTeU',            // Remplace par ta vraie clé publique
  );

  runApp(const WaterStockApp());
}

class WaterStockApp extends StatelessWidget {
  const WaterStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Dépôt Eau',
      debugShowCheckedModeBanner: false,

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
          selectedItemColor: Color(0xFF4C4DDC),
          unselectedItemColor: Colors.grey,
        ),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF4C4DDC),
          secondary: const Color(0xFF00E676),
          error: const Color(0xFFFF5252),
          brightness: Brightness.dark,
        ),
      ),
      // ON DÉMARRE SUR LE LOGIN
      home: const LoginScreen(),
    );
  }
}

// --- LE SYSTÈME D'ONGLETS SÉCURISÉ ---
class MainNavigation extends StatefulWidget {
  final bool isAdmin;

  const MainNavigation({super.key, required this.isAdmin});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 1. On construit la liste des écrans selon le rôle
    List<Widget> screens = [
      const DashboardScreen(),
      // LA MODIFICATION EST ICI : On passe la variable isAdmin
      OperationsScreen(isAdmin: widget.isAdmin),
    ];

    // Si c'est l'Admin, on ajoute l'écran Caisse
    if (widget.isAdmin) {
      screens.add(const InvoicesScreen());
    }

    // L'écran Profil est ajouté TOUT À LA FIN (pour Admin et Secrétaire)
    screens.add(ProfileScreen(isAdmin: widget.isAdmin));

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // OBLIGATOIRE quand on a plus de 3 onglets !
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_outlined),
            activeIcon: Icon(Icons.swap_horiz),
            label: 'Opérations',
          ),
          // Le bouton Caisse n'apparaît que pour l'Admin
          if (widget.isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Caisse',
            ),
          // Le bouton Profil est toujours visible
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}