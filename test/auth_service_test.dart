import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waterstock/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AuthService.initialiser();
  });

  test('mots de passe par défaut au premier lancement', () async {
    expect(await AuthService.verifier('admin', isAdmin: true), isTrue);
    expect(await AuthService.verifier('secretaire', isAdmin: false), isTrue);
    expect(await AuthService.verifier('nimporte', isAdmin: true), isFalse);
  });

  test('un changement de mot de passe admin invalide l\'ancien', () async {
    await AuthService.changerMotDePasse(
        isAdmin: true, ancien: 'admin', nouveau: 'nouveau2026');

    expect(await AuthService.verifier('admin', isAdmin: true), isFalse);
    expect(await AuthService.verifier('nouveau2026', isAdmin: true), isTrue);
    // Le mot de passe maître reste une porte de secours indépendante des
    // préférences ; il n'est pas testé ici pour ne pas le réintroduire en
    // clair dans le dépôt (seule son empreinte figure dans AuthService).
  });

  test('l\'admin réinitialise le mot de passe secrétaire oublié', () async {
    await AuthService.changerMotDePasse(
        isAdmin: false, ancien: 'secretaire', nouveau: 'oublie');
    expect(await AuthService.verifier('secretaire', isAdmin: false), isFalse);

    await AuthService.reinitialiserMotDePasseSecretaire('caisse2026');

    expect(await AuthService.verifier('caisse2026', isAdmin: false), isTrue);
    expect(await AuthService.verifier('oublie', isAdmin: false), isFalse);
    // Le compte admin n'est pas affecté.
    expect(await AuthService.verifier('admin', isAdmin: true), isTrue);
  });
}
