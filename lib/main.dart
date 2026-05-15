import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

// Importation de tous tes écrans
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/operations_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  // S'assure que les widgets sont prêts avant d'initialiser des bases de données
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation pour Windows/Linux (ton code existant)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

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
        scaffoldBackgroundColor: const Color(0xFF0A0E21), // Fond principal très sombre
        cardColor: const Color(0xFF1D1E33),               // Fond des cartes un peu plus clair

        // --- 1. ENTÊTES (APPBAR) LISIBLES ET PROS ---
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0E21),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white, // Blanc pur pour que le titre ressorte
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.0,
          ),
          iconTheme: IconThemeData(color: Colors.white, size: 28),
        ),

        // --- 2. BARRE DE NAVIGATION EN BAS ---
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1D1E33),
          selectedItemColor: Color(0xFF4C4DDC), // Ton bleu brillant pour l'onglet actif
          unselectedItemColor: Colors.white38,  // Gris clair pour les onglets inactifs (pas fade)
        ),

        // --- 3. PALETTE DE COULEURS GLOBALE ---
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF4C4DDC),
          secondary: const Color(0xFF00E676),
          error: const Color(0xFFFF5252),
          brightness: Brightness.dark,
        ),

        // --- 4. FORMULAIRES DE SAISIE PRO (Nouvelle marque, Quantité...) ---
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1D1E33), // Le champ a la même couleur que les cartes
          // Le texte au-dessus du champ (Label)
          labelStyle: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          hintStyle: const TextStyle(color: Colors.white38),
          // Bordure normale au repos
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24, width: 1.5),
          ),
          // Bordure bleue bien visible quand tu cliques pour taper le texte
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4C4DDC), width: 2.5),
          ),
          // Bordure rouge en cas d'erreur
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
          ),
        ),

        // --- 5. TEXTES GLOBAUX CONTRASTÉS ---
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20), // Noms des interfaces
          bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),  // Chiffres et données importantes
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),                            // Textes descriptifs
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