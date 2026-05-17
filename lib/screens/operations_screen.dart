import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../models/water_item.dart';
import '../models/transaction_item.dart';

class OperationsScreen extends StatefulWidget {
  final bool isAdmin;

  const OperationsScreen({super.key, required this.isAdmin});

  @override
  State<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends State<OperationsScreen> {
  void _ouvrirFormulaireOperation(BuildContext context, bool estRavitaillement) async {
    List<WaterItem> produits = await DBHelper().getAllItems();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D1E33), // Adaptation au thème Dark
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.85, // Prend 85% de l'écran pour avoir de la place pour le panier
        child: FormulaireOperation(
          produits: produits,
          estRavitaillement: estRavitaillement,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Entrées & Sorties', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        bottom: !widget.isAdmin
            ? const PreferredSize(
          preferredSize: Size.fromHeight(30),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text('Mode Secrétaire : Les saisies seront en attente', style: TextStyle(color: Colors.orangeAccent)),
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
                context,
                titre: '📥 Ravitaillement',
                sousTitre: 'Entrée de stock (Grossiste)',
                couleur: const Color(0xFF4C4DDC),
                onTap: () => _ouvrirFormulaireOperation(context, true)
            ),
            const SizedBox(height: 20),
            _buildActionCard(
                context,
                titre: '📤 Nouvelle Vente',
                sousTitre: 'Panier et Sortie de paquets',
                couleur: const Color(0xFF00E676),
                onTap: () => _ouvrirFormulaireOperation(context, false)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String titre, required String sousTitre, required Color couleur, required VoidCallback onTap}) {
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
            Text(titre, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: couleur)),
            const SizedBox(height: 10),
            Text(sousTitre, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// --- LE FORMULAIRE AVEC SYSTÈME DE PANIER ---
class FormulaireOperation extends StatefulWidget {
  final List<WaterItem> produits;
  final bool estRavitaillement;
  final bool isAdmin;

  const FormulaireOperation({super.key, required this.produits, required this.estRavitaillement, required this.isAdmin});

  @override
  State<FormulaireOperation> createState() => _FormulaireOperationState();
}

class _FormulaireOperationState extends State<FormulaireOperation> {
  // Informations globales de la commande
  final TextEditingController _nomClientController = TextEditingController();
  bool _estPaye = true;

  // Saisie du produit en cours
  WaterItem? _produitSelectionne;
  final TextEditingController _quantiteController = TextEditingController();
  final TextEditingController _montantTotalController = TextEditingController();

  // Le Panier
  List<TransactionItem> _panier = [];
  double _montantTotalPanier = 0.0;

  // Ajouter un produit au panier
  void _ajouterAuPanier() {
    if (_produitSelectionne == null || _quantiteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un produit et une quantité.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    int quantiteSaisie = int.parse(_quantiteController.text);
    if (quantiteSaisie <= 0) return;

    // --- SÉCURITÉ 1 : BLOCAGE DU STOCK NÉGATIF ---
    if (!widget.estRavitaillement) {
      // On calcule combien de ce produit sont DÉJÀ dans le panier
      int quantiteDejaAuPanier = _panier
          .where((item) => item.waterItemId == _produitSelectionne!.id)
          .fold(0, (sum, item) => sum + item.quantite);

      if (quantiteSaisie + quantiteDejaAuPanier > _produitSelectionne!.quantite) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Stock insuffisant ! Il ne reste que ${_produitSelectionne!.quantite} ${_produitSelectionne!.marque}.'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    double montantCalcule = 0.0;
    double beneficeCalcule = 0.0;

    if (widget.estRavitaillement) {
      montantCalcule = double.tryParse(_montantTotalController.text) ?? 0.0;
    } else {
      montantCalcule = quantiteSaisie * _produitSelectionne!.prixVente;
      beneficeCalcule = (_produitSelectionne!.prixVente - _produitSelectionne!.prixAchat) * quantiteSaisie;
    }

    // On crée l'item temporaire pour le panier
    TransactionItem itemPanier = TransactionItem(
      waterItemId: _produitSelectionne!.id!,
      marque: _produitSelectionne!.marque,
      type: widget.estRavitaillement ? 'ENTREE' : 'SORTIE',
      quantite: quantiteSaisie,
      montant: montantCalcule,
      benefice: beneficeCalcule,
      date: DateTime.now().toString().substring(0, 16),
      estPaye: _estPaye, // Sera mis à jour globalement à la validation
      statut: widget.isAdmin ? 'VALIDEE' : 'EN_ATTENTE',
    );

    setState(() {
      _panier.add(itemPanier);
      _montantTotalPanier += montantCalcule;

      // On réinitialise les champs de saisie, mais on garde le client et le dropdown
      _quantiteController.clear();
      _montantTotalController.clear();
    });
  }

  // Retirer un produit du panier
  void _retirerDuPanier(int index) {
    setState(() {
      _montantTotalPanier -= _panier[index].montant;
      _panier.removeAt(index);
    });
  }

  // Valider TOUTE la commande
  void _validerCommande() async {
    if (_panier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le panier est vide.'), backgroundColor: Colors.orangeAccent),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // On fige la date exacte et le nom du client pour toute la commande
    String dateCommune = DateTime.now().toString().substring(0, 16);
    String clientCommun = _nomClientController.text.isEmpty ? "Client Anonyme" : _nomClientController.text;

    // On parcourt le panier et on enregistre chaque ligne en BDD
    for (var item in _panier) {
      TransactionItem transactionFinale = TransactionItem(
        waterItemId: item.waterItemId,
        marque: item.marque,
        type: item.type,
        quantite: item.quantite,
        montant: item.montant,
        benefice: item.benefice,
        date: dateCommune, // Date identique pour lier la commande
        estPaye: _estPaye, // Appliqué à tout le panier
        statut: item.statut,
        nomClient: clientCommun, // Appliqué à tout le panier
      );

      if (widget.isAdmin) {
        await DBHelper().updateStock(transactionFinale.waterItemId, widget.estRavitaillement ? transactionFinale.quantite : -transactionFinale.quantite);
      }
      await DBHelper().insertTransaction(transactionFinale);
    }

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(widget.isAdmin ? '✅ Commande validée avec succès !' : '⏳ Commande envoyée pour vérification'),
        backgroundColor: widget.isAdmin ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = widget.estRavitaillement ? const Color(0xFF4C4DDC) : const Color(0xFF00E676);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20
      ),
      child: Column(
        children: [
          // En-tête
          Text(
              widget.estRavitaillement ? 'Ravitaillement (Entrée)' : 'Caisse & Panier (Sortie)',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
          ),
          const SizedBox(height: 15),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- 1. INFOS GLOBALES DE LA COMMANDE ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1))
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _nomClientController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Client / Livreur',
                            labelStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person, color: Colors.white54),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: Text('Paiement comptant', style: TextStyle(color: _estPaye ? themeColor : Colors.redAccent, fontWeight: FontWeight.bold)),
                          value: _estPaye,
                          activeColor: themeColor,
                          inactiveThumbColor: Colors.redAccent,
                          inactiveTrackColor: Colors.redAccent.withValues(alpha: 0.3),
                          onChanged: (val) => setState(() => _estPaye = val),
                        ),
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
                        child: DropdownButtonFormField<WaterItem>(
                          dropdownColor: const Color(0xFF1D1E33),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Marque', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
                          items: widget.produits.map((item) => DropdownMenuItem(
                              value: item,
                              child: Text('${item.marque} (Stock: ${item.quantite})', style: const TextStyle(fontSize: 14))
                          )).toList(),
                          onChanged: (val) => setState(() => _produitSelectionne = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _quantiteController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Qté', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(labelText: 'Coût total pour cette ligne', labelStyle: TextStyle(color: Colors.white54), border: OutlineInputBorder(), prefixText: 'FCFA '),
                    ),
                  ],

                  const SizedBox(height: 15),

                  // BOUTON AJOUTER AU PANIER
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: themeColor,
                          side: BorderSide(color: themeColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
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
                    child: Text('VOTRE PANIER (${_panier.length})', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),

                  if (_panier.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("Aucun article ajouté.", style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), // Empêche le conflit de scroll
                      itemCount: _panier.length,
                      itemBuilder: (context, index) {
                        final item = _panier[index];
                        return Card(
                          color: Colors.white.withValues(alpha: 0.05),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            dense: true,
                            title: Text('${item.marque} x${item.quantite}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${item.montant.toInt()} F', style: TextStyle(color: themeColor, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  onPressed: () => _retirerDuPanier(index),
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

          // --- 4. VALIDATION FINALE (Fixée en bas) ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white10))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total à payer', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('${_montantTotalPanier.toInt()} FCFA', style: TextStyle(color: themeColor, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: widget.estRavitaillement ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _validerCommande,
                  child: const Text('VALIDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}