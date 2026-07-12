import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_database.dart';
import '../services/auth_service.dart';
import '../widgets/admin_password_dialog.dart';
import 'finance_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isAdmin;

  const ProfileScreen({super.key, required this.isAdmin});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  void _seDeconnecter() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- CHANGEMENT DE MOT DE PASSE ---
  void _afficherBoiteChangementMotDePasse() {
    final ancienController = TextEditingController();
    final nouveauController = TextEditingController();
    final confirmController = TextEditingController();
    bool isObscurci = true;

    InputDecoration decoration(String label, {Widget? suffix}) =>
        InputDecoration(labelText: label, suffixIcon: suffix);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.primaire, width: 1),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_reset, color: AppColors.primaire),
              SizedBox(width: 10),
              Text('Modifier le mot de passe',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isAdmin)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 15.0),
                    child: Text(
                        'Info : vous pouvez utiliser le mot de passe Maître en cas d\'oubli.',
                        style: TextStyle(
                            color: Colors.orangeAccent, fontSize: 12)),
                  ),
                TextField(
                  controller: ancienController,
                  obscureText: isObscurci,
                  style: const TextStyle(color: Colors.white),
                  decoration: decoration(
                    'Mot de passe actuel',
                    suffix: IconButton(
                      icon: Icon(
                          isObscurci ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white54),
                      onPressed: () =>
                          setStateDialog(() => isObscurci = !isObscurci),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: nouveauController,
                  obscureText: isObscurci,
                  style: const TextStyle(color: Colors.white),
                  decoration: decoration('Nouveau mot de passe'),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: confirmController,
                  obscureText: isObscurci,
                  style: const TextStyle(color: Colors.white),
                  decoration: decoration('Confirmer le nouveau'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaire,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final ancien = ancienController.text.trim();
                final nouveau = nouveauController.text.trim();
                final confirm = confirmController.text.trim();
                final messenger = ScaffoldMessenger.of(context);

                if (ancien.isEmpty || nouveau.isEmpty || confirm.isEmpty) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Veuillez remplir tous les champs.'),
                      backgroundColor: Colors.redAccent));
                  return;
                }
                if (nouveau.length < 4) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text(
                          'Le nouveau mot de passe doit faire au moins 4 caractères.'),
                      backgroundColor: Colors.redAccent));
                  return;
                }
                if (nouveau != confirm) {
                  messenger.showSnackBar(const SnackBar(
                      content:
                          Text('Les nouveaux mots de passe ne correspondent pas.'),
                      backgroundColor: Colors.redAccent));
                  return;
                }

                final navigator = Navigator.of(ctx);
                final ok = await AuthService.changerMotDePasse(
                    isAdmin: widget.isAdmin, ancien: ancien, nouveau: nouveau);

                if (ok) {
                  navigator.pop();
                  messenger.showSnackBar(const SnackBar(
                      content: Text('✅ Mot de passe modifié avec succès !'),
                      backgroundColor: Colors.green));
                } else {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('❌ L\'ancien mot de passe est incorrect.'),
                      backgroundColor: Colors.redAccent));
                }
              },
              child: const Text('VALIDER'),
            ),
          ],
        ),
      ),
    );
  }

  // --- RÉINITIALISATION (protégée par le mot de passe admin) ---
  Future<void> _reinitialiser() async {
    final ok = await demanderMotDePasseAdmin(
      context,
      titre: 'ZONE DE DANGER',
      message:
          'ATTENTION : cette action va effacer TOUT l\'historique des ventes, '
          'les paiements, et remettre le stock à zéro.\n\n'
          'Confirmez avec le mot de passe administrateur :',
      libelleBouton: 'EFFACER TOUT',
    );
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await AppDatabase.reinitialiser();
    messenger.showSnackBar(const SnackBar(
        content: Text('✅ Application remise à zéro avec succès.'),
        backgroundColor: Colors.green));
    _seDeconnecter();
  }

  @override
  Widget build(BuildContext context) {
    final nomUtilisateur = widget.isAdmin ? 'Bienvenue' : 'Profil Secrétaire';
    final role =
        widget.isAdmin ? 'Administrateur Principal' : 'Employé(e) de Caisse';
    final themeColor = widget.isAdmin ? AppColors.primaire : AppColors.succes;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres & Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- EN-TÊTE PROFIL ---
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.carte,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                    color: themeColor.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: themeColor, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: themeColor.withValues(alpha: 0.2),
                      child: Icon(
                        widget.isAdmin
                            ? Icons.admin_panel_settings
                            : Icons.person_outline,
                        size: 50,
                        color: themeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(nomUtilisateur,
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(role.toUpperCase(),
                        style: TextStyle(
                            color: themeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.isAdmin
                        ? 'Accès illimité à la base de données, aux stocks et à la caisse.'
                        : 'Accès restreint. Vos saisies nécessitent la validation de l\'administrateur.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('GESTION DU COMPTE',
                  style: TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
            ),
            const SizedBox(height: 10),
            if (widget.isAdmin) ...[
              _boutonAction(
                titre: 'Tableau de Bord Financier',
                sousTitre: 'Bénéfices, graphiques, top ventes et export Excel',
                icone: Icons.insights,
                couleur: AppColors.primaire,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FinanceScreen())),
              ),
              const SizedBox(height: 15),
            ],
            _boutonAction(
              titre: 'Changer le mot de passe',
              sousTitre: 'Mettre à jour vos identifiants de connexion',
              icone: Icons.lock_outline,
              couleur: AppColors.succes,
              onTap: _afficherBoiteChangementMotDePasse,
            ),
            const SizedBox(height: 15),
            _boutonAction(
              titre: 'Se déconnecter',
              sousTitre: 'Fermer la session actuelle',
              icone: Icons.logout,
              couleur: Colors.orangeAccent,
              onTap: _seDeconnecter,
            ),
            const SizedBox(height: 20),
            if (widget.isAdmin) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('MAINTENANCE SYSTÈME',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 10),
              _boutonAction(
                titre: 'Réinitialiser l\'application',
                sousTitre: 'Effacer l\'historique et purger les stocks',
                icone: Icons.delete_forever_rounded,
                couleur: Colors.redAccent,
                onTap: _reinitialiser,
                isDanger: true,
              ),
            ],
            const SizedBox(height: 40),
            const Text('Dépôt Eau Pro v4.0',
                style: TextStyle(color: Colors.white24, fontSize: 12)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _boutonAction({
    required String titre,
    required String sousTitre,
    required IconData icone,
    required Color couleur,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.carte,
            borderRadius: BorderRadius.circular(16),
            border: isDanger
                ? Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3), width: 1)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icone, color: couleur, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre,
                          style: TextStyle(
                              color:
                                  isDanger ? Colors.redAccent : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(sousTitre,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.2), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
