import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waterstock/main.dart';
// REMPLACE "votre_nom_de_projet" par le nom réel de ton projet (voir ton pubspec.yaml)

void main() {
  testWidgets('Vérification du démarrage sur l\'écran de Login', (WidgetTester tester) async {
    // 1. Charger l'application
    await tester.pumpWidget(const WaterStockApp());

    // 2. Vérifier que le titre "Dépôt Eau Pro" est présent
    expect(find.text('Dépôt Eau Pro'), findsOneWidget);

    // 3. Vérifier que le bouton de connexion existe
    expect(find.text('SE CONNECTER'), findsOneWidget);

    // 4. Vérifier que le champ de sélection du rôle est présent par défaut
    expect(find.text('Secrétaire'), findsOneWidget);
  });

  testWidgets('Vérification des champs de saisie', (WidgetTester tester) async {
    await tester.pumpWidget(const WaterStockApp());

    // Vérifier la présence des icônes de profil et de cadenas
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });
}