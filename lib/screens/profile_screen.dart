import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isAdmin;

  const ProfileScreen({super.key, required this.isAdmin});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- LE CODE SECRET POUR LA RÉINITIALISATION DE L'APP ---
  final String _codeReset = "78523";

  // --- LE MOT DE PASSE MAÎTRE DE SECOURS (ADMIN) ---
  final String _motDePasseMaitre = "Familydao987";

  // Fonction pour se déconnecter
  void _seDeconnecter() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  // Fonction pour CHANGER LE MOT DE PASSE
  void _afficherBoiteChangementMotDePasse() {
    final TextEditingController ancienController = TextEditingController();
    final TextEditingController nouveauController = TextEditingController();
    final TextEditingController confirmController = TextEditingController();

    bool isObscurci = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1D1E33),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF4C4DDC), width: 1),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: Color(0xFF4C4DDC)),
                  SizedBox(width: 10),
                  Text("Modifier le mot de passe", style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isAdmin)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 15.0),
                        child: Text("Info : Vous pouvez utiliser le mot de passe Maître en cas d'oubli.",
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                      ),

                    // Champ Ancien Mot de passe
                    TextField(
                      controller: ancienController,
                      obscureText: isObscurci,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        labelStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4C4DDC))),
                        suffixIcon: IconButton(
                          icon: Icon(isObscurci ? Icons.visibility_off : Icons.visibility, color: Colors.white54),
                          onPressed: () => setStateDialog(() => isObscurci = !isObscurci),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Champ Nouveau Mot de passe
                    TextField(
                      controller: nouveauController,
                      obscureText: isObscurci,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe',
                        labelStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4C4DDC))),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Champ Confirmer
                    TextField(
                      controller: confirmController,
                      obscureText: isObscurci,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Confirmer le nouveau',
                        labelStyle: const TextStyle(color: Colors.white54),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4C4DDC))),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C4DDC), foregroundColor: Colors.white),
                  onPressed: () async {
                    String ancien = ancienController.text.trim();
                    String nouveau = nouveauController.text.trim();
                    String confirm = confirmController.text.trim();

                    // 1. Vérifications basiques
                    if (ancien.isEmpty || nouveau.isEmpty || confirm.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veuillez remplir tous les champs.'), backgroundColor: Colors.redAccent));
                      return;
                    }
                    if (nouveau != confirm) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Les nouveaux mots de passe ne correspondent pas.'), backgroundColor: Colors.redAccent));
                      return;
                    }

                    // 2. Capture des outils AVANT le await (Parfait !)
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(ctx);

                    // 3. Vérification de l'ancien mot de passe via SharedPreferences
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    String roleCle = widget.isAdmin ? 'mdp_admin' : 'mdp_secretaire';

                    String vraiAncienMdp = prefs.getString(roleCle) ?? (widget.isAdmin ? 'admin' : 'secretaire');

                    bool estAutorise = false;

                    if (widget.isAdmin && ancien == _motDePasseMaitre) {
                      estAutorise = true;
                    } else if (ancien == vraiAncienMdp) {
                      estAutorise = true;
                    }

                    // 4. Sauvegarde et notifications (Nettoyé des doublons)
                    if (estAutorise) {
                      await prefs.setString(roleCle, nouveau);

                      // Utilisation des outils capturés
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('✅ Mot de passe modifié avec succès !'), backgroundColor: Colors.green),
                      );
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('❌ L\'ancien mot de passe est incorrect.'), backgroundColor: Colors.redAccent),
                      );
                    }
                  },
                  child: const Text("VALIDER"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fonction pour afficher la boîte de dialogue de sécurité (Zone de Danger)
  void _afficherBoiteReset() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.redAccent, size: 30),
              SizedBox(width: 10),
              Text("ZONE DE DANGER", style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "ATTENTION : Cette action va effacer TOUT l'historique des ventes et remettre le stock à zéro.",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const Text("Entrez le code administrateur pour confirmer :", style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 10),
              TextField(
                controller: codeController,
                keyboardType: TextInputType.number,
                obscureText: true,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 8, fontSize: 20),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.red.withValues(alpha: 0.1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Annuler", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                if (codeController.text == _codeReset) {
                  Navigator.pop(ctx);
                  await DBHelper().reinitialiserBaseDeDonnees();

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Application remise à zéro avec succès.'), backgroundColor: Colors.green),
                  );
                  _seDeconnecter(); // On déconnecte pour rafraîchir
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Code incorrect. Action refusée.'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text("EFFACER TOUT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String nomUtilisateur = widget.isAdmin ? 'Bienvenue' : 'Profil Secrétaire';
    String role = widget.isAdmin ? 'Administrateur Principal' : 'Employé(e) de Caisse';
    Color themeColor = widget.isAdmin ? const Color(0xFF4C4DDC) : const Color(0xFF00E676);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres & Profil', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- EN-TÊTE PROFIL ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: themeColor.withValues(alpha: 0.3), width: 1.5),
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
                        widget.isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
                        size: 50,
                        color: themeColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    nomUtilisateur,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role.toUpperCase(),
                      style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
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

            // --- SECTION ACTIONS ---
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("GESTION DU COMPTE", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 10),

            // NOUVEAU : Bouton pour changer le mot de passe
            _buildBoutonAction(
              titre: "Changer le mot de passe",
              sousTitre: "Mettre à jour vos identifiants de connexion",
              icone: Icons.lock_outline,
              couleur: const Color(0xFF00E676),
              onTap: _afficherBoiteChangementMotDePasse,
            ),
            const SizedBox(height: 15),

            // Bouton Déconnexion
            _buildBoutonAction(
              titre: "Se déconnecter",
              sousTitre: "Fermer la session actuelle",
              icone: Icons.logout,
              couleur: Colors.orangeAccent,
              onTap: _seDeconnecter,
            ),

            const SizedBox(height: 20),

            // --- ZONE DE DANGER (Uniquement pour l'admin) ---
            if (widget.isAdmin) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("MAINTENANCE SYSTÈME", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
              const SizedBox(height: 10),

              _buildBoutonAction(
                titre: "Réinitialiser l'application",
                sousTitre: "Effacer l'historique et purger les stocks",
                icone: Icons.delete_forever_rounded,
                couleur: Colors.redAccent,
                onTap: _afficherBoiteReset,
                isDanger: true,
              ),
            ],

            const SizedBox(height: 40),
            const Text("WaterStock App v1.0", style: TextStyle(color: Colors.white24, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // Widget personnalisé pour les boutons du menu
  Widget _buildBoutonAction({
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
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(16),
            border: isDanger ? Border.all(color: Colors.redAccent.withValues(alpha: 0.3), width: 1) : null,
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
                      Text(titre, style: TextStyle(color: isDanger ? Colors.redAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(sousTitre, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.2), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}