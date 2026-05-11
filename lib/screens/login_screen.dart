import 'package:flutter/material.dart';
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

  void _seConnecter() {
    String password = _passwordController.text;
    bool isLoginValid = false;
    bool isAdmin = false;

    // --- VÉRIFICATION DES MOTS DE PASSE ---
    if (_roleSelectionne == 'Admin' && password == 'admin123') {
      isLoginValid = true;
      isAdmin = true;
    } else if (_roleSelectionne == 'Secrétaire' && password == 'sec123') {
      isLoginValid = true;
      isAdmin = false;
    }

    // --- NAVIGATION OU ERREUR ---
    if (isLoginValid) {
      // Si c'est bon, on détruit l'écran de login et on ouvre l'appli en envoyant le rôle
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainNavigation(isAdmin: isAdmin)),
      );
    } else {
      // Si c'est faux, on affiche une erreur
      setState(() {
        _errorMessage = 'Mot de passe incorrect pour le profil $_roleSelectionne.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // Même bleu nuit que ton thème
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 10,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo ou Icône de l'appli
                  const Icon(Icons.water_drop, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  const Text(
                    'Dépôt Eau Pro',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 40),

                  // Choix du Profil (Admin ou Secrétaire)
                  DropdownButtonFormField<String>(
                    value: _roleSelectionne,
                    decoration: const InputDecoration(
                      labelText: 'Qui êtes-vous ?',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
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
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
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
                    Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 30),

                  // Bouton Connexion
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _seConnecter,
                      child: const Text('SE CONNECTER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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