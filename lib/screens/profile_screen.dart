import 'package:flutter/material.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  final bool isAdmin; // On récupère le rôle pour afficher les bonnes infos

  const ProfileScreen({super.key, required this.isAdmin});

  // Fonction magique pour se déconnecter
  void _seDeconnecter(BuildContext context) {
    // On détruit l'historique de navigation et on remet l'écran de Login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    String role = isAdmin ? 'Administrateur' : 'Secrétaire';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // L'Avatar qui change de couleur selon le rôle
            CircleAvatar(
              radius: 60,
              backgroundColor: isAdmin ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.orangeAccent.withValues(alpha: 0.2),
              child: Icon(
                isAdmin ? Icons.admin_panel_settings : Icons.person,
                size: 60,
                color: isAdmin ? Colors.blueAccent : Colors.orangeAccent,
              ),
            ),
            const SizedBox(height: 20),

            // Le nom du rôle
            Text(
              role,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // La description des droits
            Text(
              isAdmin ? 'Accès complet au système de gestion' : 'Accès limité (Saisie des opérations)',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),

            const SizedBox(height: 50),

            // Le gros bouton de déconnexion
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.redAccent, width: 2),
                ),
              ),
              onPressed: () => _seDeconnecter(context),
              icon: const Icon(Icons.logout),
              label: const Text('SE DÉCONNECTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}