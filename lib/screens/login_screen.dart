import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String _roleSelectionne = 'Secrétaire';
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isPasswordVisible = false;
  bool _enCours = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Veuillez entrer un mot de passe.');
      return;
    }

    setState(() => _enCours = true);
    final isAdmin = _roleSelectionne == 'Admin';
    final valide = await AuthService.verifier(password, isAdmin: isAdmin);
    if (!mounted) return;
    setState(() => _enCours = false);

    if (valide) {
      _passwordController.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainNavigation(isAdmin: isAdmin)),
      );
    } else {
      setState(() =>
          _errorMessage = 'Mot de passe incorrect pour le profil $_roleSelectionne.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor =
        _roleSelectionne == 'Admin' ? AppColors.primaire : AppColors.succes;

    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              color: AppColors.carte,
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
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1),
                    ),
                    const SizedBox(height: 40),
                    DropdownButtonFormField<String>(
                      initialValue: _roleSelectionne,
                      dropdownColor: AppColors.carte,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Qui êtes-vous ?',
                        prefixIcon: Icon(Icons.person, color: themeColor),
                      ),
                      items: ['Admin', 'Secrétaire']
                          .map((role) =>
                              DropdownMenuItem(value: role, child: Text(role)))
                          .toList(),
                      onChanged: (newValue) => setState(() {
                        _roleSelectionne = newValue!;
                        _errorMessage = '';
                      }),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _seConnecter(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: Icon(Icons.lock, color: themeColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white54),
                          onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                    ),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(_errorMessage,
                            style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                      ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: _roleSelectionne == 'Admin'
                              ? Colors.white
                              : Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _enCours ? null : _seConnecter,
                        child: _enCours
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('SE CONNECTER',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
