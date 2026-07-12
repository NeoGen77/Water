import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../data/client_repo.dart';
import '../data/commande_repo.dart';
import '../data/produit_repo.dart';
import '../models/client.dart';
import '../models/commande.dart';
import '../models/produit.dart';

class OperationsScreen extends StatefulWidget {
  final bool isAdmin;

  const OperationsScreen({super.key, required this.isAdmin});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  Future<void> _ouvrirFormulaire(BuildContext context, bool estRavitaillement) async {
    final produits = await ProduitRepo().tous();
    final clients = await ClientRepo().tous();
    if (!context.mounted) return;

    if (produits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Créez d\'abord un produit dans l\'onglet Stock.'),
            backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.carte,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: FormulaireCommande(
          produits: produits,
          clients: clients,
          estRavitaillement: estRavitaillement,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        title: const Text('Entrées & Sorties'),
        bottom: !widget.isAdmin
            ? const PreferredSize(
                preferredSize: Size.fromHeight(30),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                      'Mode Secrétaire : les saisies seront en attente de validation',
                      style: TextStyle(color: Colors.orangeAccent)),
                ),
              )
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionCard(
              titre: '📥 Ravitaillement',
              sousTitre: 'Entrée de stock (Grossiste)',
              couleur: AppColors.primaire,
              onTap: () => _ouvrirFormulaire(context, true),
            ),
            const SizedBox(height: 20),
            _buildActionCard(
              titre: '📤 Nouvelle Vente',
              sousTitre: 'Panier et sortie de paquets',
              couleur: AppColors.succes,
              onTap: () => _ouvrirFormulaire(context, false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
      {required String titre,
      required String sousTitre,
      required Color couleur,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: couleur.withValues(alpha: 0.5), width: 2),
        ),
        child: Column(
          children: [
            Text(titre,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: couleur)),
            const SizedBox(height: 10),
            Text(sousTitre, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// --- FORMULAIRE PANIER -> COMMANDE ---
class FormulaireCommande extends StatefulWidget {
  final List<Produit> produits;
  final List<Client> clients;
  final bool estRavitaillement;
  final bool isAdmin;

  const FormulaireCommande({
    super.key,
    required this.produits,
    required this.clients,
    required this.estRavitaillement,
    required this.isAdmin,
  });

  @override
  State<FormulaireCommande> createState() => _FormulaireCommandeState();
}

class _FormulaireCommandeState extends State<FormulaireCommande> {
  final _nomClientController = TextEditingController();
  bool _estPaye = true;
  bool _enregistrementEnCours = false;

  Produit? _produitSelectionne;
  final _quantiteController = TextEditingController();
  final _montantTotalController = TextEditingController();

  final List<LigneCommande> _panier = [];

  double get _totalPanier => _panier.fold(0.0, (s, l) => s + l.montant);

  @override
  void dispose() {
    _nomClientController.dispose();
    _quantiteController.dispose();
    _montantTotalController.dispose();
    super.dispose();
  }

  void _ajouterAuPanier() {
    final produit = _produitSelectionne;
    if (produit == null || _quantiteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner un produit et une quantité.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    final quantite = int.tryParse(_quantiteController.text) ?? 0;
    if (quantite <= 0) return;

    // Contrôle indicatif du stock (le contrôle définitif est refait en base
    // au moment d'enregistrer, pour éviter les données périmées).
    if (!widget.estRavitaillement) {
      final dejaAuPanier = _panier
          .where((l) => l.produitId == produit.id)
          .fold<int>(0, (s, l) => s + l.quantite);
      if (quantite + dejaAuPanier > produit.quantite) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Stock insuffisant ! Il ne reste que ${produit.quantite} ${produit.marque}.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    double montant;
    double benefice = 0;
    double prixUnitaire;

    if (widget.estRavitaillement) {
      montant = double.tryParse(_montantTotalController.text) ?? 0.0;
      prixUnitaire = quantite > 0 ? montant / quantite : 0;
    } else {
      prixUnitaire = produit.prixVente;
      montant = quantite * produit.prixVente;
      benefice = produit.margeUnitaire * quantite;
    }

    setState(() {
      _panier.add(LigneCommande(
        produitId: produit.id!,
        marque: produit.marque,
        quantite: quantite,
        prixUnitaire: prixUnitaire,
        montant: montant,
        benefice: benefice,
      ));
      _quantiteController.clear();
      _montantTotalController.clear();
    });
  }

  Future<void> _validerCommande() async {
    if (_panier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Le panier est vide.'),
            backgroundColor: Colors.orangeAccent),
      );
      return;
    }
    if (_enregistrementEnCours) return;
    setState(() => _enregistrementEnCours = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // Fiche client réelle (créée si nécessaire), uniquement si un nom est saisi.
      int? clientId;
      final nomClient = _nomClientController.text.trim();
      if (nomClient.isNotEmpty) {
        clientId = await ClientRepo().trouverOuCreer(nomClient);
      }

      final numero = await CommandeRepo().creerCommande(
        type: widget.estRavitaillement
            ? Commande.typeRavitaillement
            : Commande.typeVente,
        lignes: _panier,
        clientId: clientId,
        estPayeComptant: _estPaye,
        isAdmin: widget.isAdmin,
      );

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.isAdmin
              ? '✅ Commande $numero enregistrée !'
              : '⏳ Commande envoyée pour vérification'),
          backgroundColor: widget.isAdmin ? Colors.green : Colors.orange,
        ),
      );
    } on StateError catch (e) {
      setState(() => _enregistrementEnCours = false);
      messenger.showSnackBar(
        SnackBar(content: Text('❌ ${e.message}'), backgroundColor: Colors.redAccent),
      );
    } catch (e) {
      setState(() => _enregistrementEnCours = false);
      messenger.showSnackBar(
        SnackBar(
            content: Text('❌ Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor =
        widget.estRavitaillement ? AppColors.primaire : AppColors.succes;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: Column(
        children: [
          Text(
              widget.estRavitaillement
                  ? 'Ravitaillement (Entrée)'
                  : 'Caisse & Panier (Sortie)',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 15),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- 1. CLIENT + MODE DE PAIEMENT ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: Column(
                      children: [
                        Autocomplete<Client>(
                          displayStringForOption: (c) => c.nom,
                          optionsBuilder: (texte) {
                            if (texte.text.isEmpty) {
                              return const Iterable<Client>.empty();
                            }
                            return widget.clients.where((c) => c.nom
                                .toLowerCase()
                                .contains(texte.text.toLowerCase()));
                          },
                          onSelected: (c) => _nomClientController.text = c.nom,
                          fieldViewBuilder:
                              (context, controller, focusNode, onSubmit) {
                            controller.addListener(() {
                              _nomClientController.text = controller.text;
                            });
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'Client / Livreur (optionnel)',
                                prefixIcon:
                                    Icon(Icons.person, color: Colors.white54),
                              ),
                            );
                          },
                        ),
                        if (!widget.estRavitaillement) ...[
                          const SizedBox(height: 10),
                          SwitchListTile(
                            title: Text(
                                _estPaye ? 'Paiement comptant' : 'Vente à crédit',
                                style: TextStyle(
                                    color:
                                        _estPaye ? themeColor : Colors.redAccent,
                                    fontWeight: FontWeight.bold)),
                            value: _estPaye,
                            activeThumbColor: themeColor,
                            inactiveThumbColor: Colors.redAccent,
                            inactiveTrackColor:
                                Colors.redAccent.withValues(alpha: 0.3),
                            onChanged: (val) => setState(() => _estPaye = val),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- 2. SAISIE DU PRODUIT ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<Produit>(
                          dropdownColor: AppColors.carte,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Marque'),
                          items: widget.produits
                              .map((item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(
                                      '${item.marque} (Stock: ${item.quantite})',
                                      style: const TextStyle(fontSize: 14))))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _produitSelectionne = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _quantiteController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Qté'),
                        ),
                      ),
                    ],
                  ),
                  if (widget.estRavitaillement) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _montantTotalController,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Coût total pour cette ligne',
                          prefixText: 'FCFA '),
                    ),
                  ],
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: themeColor,
                          side: BorderSide(color: themeColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Ajouter à la commande'),
                      onPressed: _ajouterAuPanier,
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Divider(color: Colors.white24),

                  // --- 3. LE PANIER ---
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('VOTRE PANIER (${_panier.length})',
                        style: const TextStyle(
                            color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  if (_panier.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('Aucun article ajouté.',
                          style: TextStyle(
                              color: Colors.white38,
                              fontStyle: FontStyle.italic)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _panier.length,
                      itemBuilder: (context, index) {
                        final ligne = _panier[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.05),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            title: Text('${ligne.marque} x${ligne.quantite}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(fmtFcfa(ligne.montant),
                                    style: TextStyle(
                                        color: themeColor,
                                        fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 20),
                                  onPressed: () =>
                                      setState(() => _panier.removeAt(index)),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // --- 4. VALIDATION FINALE ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(fmtFcfaLong(_totalPanier),
                        style: TextStyle(
                            color: themeColor,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor:
                          widget.estRavitaillement ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: _enregistrementEnCours ? null : _validerCommande,
                  child: Text(_enregistrementEnCours ? 'EN COURS...' : 'VALIDER',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
