import 'package:flutter/material.dart';

import 'accueil_screen.dart';
import 'caisse_screen.dart';
import 'clients_screen.dart';
import 'dashboard_screen.dart';
import 'operations_screen.dart';
import 'profile_screen.dart';

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
    final screens = <Widget>[
      if (widget.isAdmin) const AccueilScreen(),
      const DashboardScreen(),
      OperationsScreen(isAdmin: widget.isAdmin),
      if (widget.isAdmin) const CaisseScreen(),
      if (widget.isAdmin) const ClientsScreen(),
      ProfileScreen(isAdmin: widget.isAdmin),
    ];

    return Scaffold(
      // Chaque changement d'onglet recrée l'écran : les données (ventes,
      // dettes, stock) sont donc toujours rechargées depuis la base.
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          if (widget.isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil',
            ),
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
          if (widget.isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Caisse',
            ),
          if (widget.isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Clients',
            ),
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
