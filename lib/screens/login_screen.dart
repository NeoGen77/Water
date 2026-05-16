import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Indispensable pour lire la mémoire
import '../main.dart'; // Permet d'accéder à ton écran principal (MainNavigation)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _roleSelectionne = 'Secrétaire'; // Le rôle par défaut
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isPasswordVisible = false;

  // --- LE MOT DE PASSE MAÎTRE DE SECOURS (ADMIN) ---
  final String _motDePasseMaitre = "Familydao987";

  void _seConnecter() async {
    String password = _passwordController.text.trim();

    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez entrer un mot de passe.';
      });
      return;
    }

    // 1. Récupération des mots de passe depuis la mémoire du téléphone
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Si l'application vient d'être installée, il n'y a pas encore de mot de passe.
    // On définit donc 'admin' et 'secretaire' par défaut.
    String mdpAdmin = prefs.getString('mdp_admin') ?? 'admin';
    String mdpSecretaire = prefs.getString('mdp_secretaire') ?? 'secretaire';

    bool isLoginValid = false;
    bool isAdmin = false;

    // 2. Vérification selon le rôle
    if (_roleSelectionne == 'Admin') {
      // L'admin peut se connecter avec son mot de passe normal OU le mot de passe maître
      if (password == mdpAdmin || password == _motDePasseMaitre) {
        isLoginValid = true;
        isAdmin = true;
      }
    } else if (_roleSelectionne == 'Secrétaire') {
      // La secrétaire ne peut se connecter qu'avec son propre mot de passe
      if (password == mdpSecretaire) {
        isLoginValid = true;
        isAdmin = false;
      }
    }

    if (!mounted) return; // Sécurité pour les méthodes async

    // 3. Navigation ou Erreur
    if (isLoginValid) {
      // Nettoyage pour des raisons de sécurité
      _passwordController.clear();
      _errorMessage = '';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainNavigation(isAdmin: isAdmin)),
      );
    } else {
      setState(() {
        _errorMessage = 'Mot de passe incorrect pour le profil $_roleSelectionne.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Les couleurs pour s'adapter à notre thème dynamique
    Color themeColor = _roleSelectionne == 'Admin' ? const Color(0xFF4C4DDC) : const Color(0xFF00E676);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // Fond principal très sombre
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: const Color(0xFF1D1E33), // Fond de la carte
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(color: themeColor.withValues(alpha: 0.3), width: 1.5),
            ),
            elevation: 10,
            shadowColor: themeColor.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo ou Icône de l'appli
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: themeColor.withValues(alpha: 0.1),
                    ),
                    child: Icon(Icons.water_drop, size: 70, color: themeColor),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Dépôt Eau Pro',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                  ),
                  const SizedBox(height: 40),

                  // Choix du Profil (Admin ou Secrétaire)
                  DropdownButtonFormField<String>(
                    initialValue: _roleSelectionne,
                    dropdownColor: const Color(0xFF1D1E33),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Qui êtes-vous ?',
                      labelStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.person, color: themeColor),
                    ),
                    items: ['Admin', 'Secrétaire'].map((String role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _roleSelectionne = newValue!;
                        _errorMessage = ''; // Réinitialise l'erreur si on change de profil
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Champ Mot de passe
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      labelStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: themeColor, width: 2),
                      ),
                      prefixIcon: Icon(Icons.lock, color: themeColor),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.white54),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Affichage de l'erreur en rouge
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),

                  const SizedBox(height: 30),

                  // Bouton Connexion
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: _roleSelectionne == 'Admin' ? Colors.white : Colors.black, // Le texte ressort mieux en noir sur le vert de la secrétaire
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _seConnecter,
                      child: const Text('SE CONNECTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}