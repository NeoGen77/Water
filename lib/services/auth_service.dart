import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentification : plus aucun mot de passe en clair.
/// Seuls des empreintes SHA-256 salées sont stockées ou comparées.
class AuthService {
  static const roleAdmin = 'admin';
  static const roleSecretaire = 'secretaire';

  static const _sel = 'depot_eau_v4::';

  // Empreinte du mot de passe maître de secours (admin uniquement).
  // Le mot de passe lui-même n'apparaît plus dans le code.
  static const _hashMaitre =
      '2f20bf53f465f84cfc5682419b3b59f09cdc41eb389cbf3909c6f1d7d3304d1e';

  static String _hash(String motDePasse) =>
      sha256.convert(utf8.encode('$_sel$motDePasse')).toString();

  static String _cle(bool isAdmin) =>
      isAdmin ? 'hash_mdp_admin' : 'hash_mdp_secretaire';

  /// Au premier lancement, initialise les mots de passe par défaut
  /// ('admin' et 'secretaire') sous forme hashée.
  static Future<void> initialiser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_cle(true))) {
      await prefs.setString(_cle(true), _hash('admin'));
    }
    if (!prefs.containsKey(_cle(false))) {
      await prefs.setString(_cle(false), _hash('secretaire'));
    }
  }

  static Future<bool> verifier(String motDePasse, {required bool isAdmin}) async {
    final prefs = await SharedPreferences.getInstance();
    final empreinte = _hash(motDePasse);
    if (isAdmin && empreinte == _hashMaitre) return true;
    return empreinte == prefs.getString(_cle(isAdmin));
  }

  static Future<bool> changerMotDePasse({
    required bool isAdmin,
    required String ancien,
    required String nouveau,
  }) async {
    if (!await verifier(ancien, isAdmin: isAdmin)) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle(isAdmin), _hash(nouveau));
    return true;
  }

  /// Redéfinit le mot de passe secrétaire sans connaître l'ancien.
  ///
  /// Contrairement à l'Admin, la Secrétaire n'a pas de mot de passe maître :
  /// c'est l'unique voie de secours en cas d'oubli. L'appelant DOIT avoir
  /// confirmé l'identité de l'Admin au préalable (`demanderMotDePasseAdmin`).
  static Future<void> reinitialiserMotDePasseSecretaire(String nouveau) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cle(false), _hash(nouveau));
  }
}
