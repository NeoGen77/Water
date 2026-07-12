import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/auth_service.dart';

/// Boîte de dialogue de confirmation par mot de passe administrateur.
/// Remplace les anciens codes secrets codés en dur.
/// Retourne true si le mot de passe admin (ou maître) est correct.
Future<bool> demanderMotDePasseAdmin(
  BuildContext context, {
  required String titre,
  required String message,
  String libelleBouton = 'CONFIRMER',
  Color couleur = Colors.redAccent,
}) async {
  final controller = TextEditingController();
  String erreur = '';

  final resultat = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setStateDialog) => AlertDialog(
        backgroundColor: AppColors.carte,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: couleur, width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: couleur),
            const SizedBox(width: 8),
            Expanded(
                child: Text(titre, style: TextStyle(color: couleur, fontSize: 18))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Mot de passe administrateur',
                prefixIcon: const Icon(Icons.key, color: Colors.white54),
                errorText: erreur.isEmpty ? null : erreur,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: couleur, foregroundColor: Colors.white),
            onPressed: () async {
              final ok =
                  await AuthService.verifier(controller.text, isAdmin: true);
              if (ok) {
                if (ctx.mounted) Navigator.pop(ctx, true);
              } else {
                setStateDialog(() => erreur = 'Mot de passe incorrect.');
              }
            },
            child: Text(libelleBouton),
          ),
        ],
      ),
    ),
  );
  return resultat ?? false;
}
