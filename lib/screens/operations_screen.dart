import 'package:flutter/material.dart';
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
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => FormulaireOperation(
        produits: produits,
        estRavitaillement: estRavitaillement,
        isAdmin: widget.isAdmin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrées & Sorties'),
        bottom: !widget.isAdmin
            ? const PreferredSize(
          preferredSize: Size.fromHeight(30),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text('Mode Secrétaire : Les saisies seront en attente de validation', style: TextStyle(color: Colors.orangeAccent)),
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
                couleur: Colors.blueAccent,
                onTap: () => _ouvrirFormulaireOperation(context, true)
            ),
            const SizedBox(height: 20),
            _buildActionCard(
                context,
                titre: '📤 Nouvelle Vente',
                sousTitre: 'Sortie de paquets',
                couleur: Colors.greenAccent,
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
            Text(sousTitre, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class FormulaireOperation extends StatefulWidget {
  final List<WaterItem> produits;
  final bool estRavitaillement;
  final bool isAdmin;

  const FormulaireOperation({super.key, required this.produits, required this.estRavitaillement, required this.isAdmin});

  @override
  State<FormulaireOperation> createState() => _FormulaireOperationState();
}

// ... Garde le début du fichier identique (Imports et OperationsScreen) ...

class _FormulaireOperationState extends State<FormulaireOperation> {
  WaterItem? _produitSelectionne;
  final TextEditingController _quantiteController = TextEditingController();
  final TextEditingController _montantTotalController = TextEditingController();
  final TextEditingController _nomClientController = TextEditingController();
  bool _estPaye = true;

  void _validerOperation() async {
    if (_produitSelectionne != null && _quantiteController.text.isNotEmpty) {
      int quantiteSaisie = int.parse(_quantiteController.text);
      double montantCalcule = 0;

      if (widget.estRavitaillement) {
        montantCalcule = double.tryParse(_montantTotalController.text) ?? 0;
      } else {
        montantCalcule = quantiteSaisie * _produitSelectionne!.prixVente;
      }

      String statutOperation = widget.isAdmin ? 'VALIDEE' : 'EN_ATTENTE';

      TransactionItem nouvelleTransaction = TransactionItem(
        waterItemId: _produitSelectionne!.id!,
        marque: _produitSelectionne!.marque,
        type: widget.estRavitaillement ? 'ENTREE' : 'SORTIE',
        quantite: quantiteSaisie,
        montant: montantCalcule,
        date: DateTime.now().toString().substring(0, 16),
        estPaye: _estPaye,
        statut: statutOperation,
        // On enregistre le nom peu importe si c'est payé ou non
        nomClient: _nomClientController.text.isEmpty ? "Client Anonyme" : _nomClientController.text,
      );

      if (widget.isAdmin) {
        await DBHelper().updateStock(_produitSelectionne!.id!, widget.estRavitaillement ? quantiteSaisie : -quantiteSaisie);
      }

      await DBHelper().insertTransaction(nouvelleTransaction);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isAdmin ? 'Enregistré !' : 'Envoyé pour vérification'),
          backgroundColor: widget.isAdmin ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                widget.estRavitaillement ? 'Ravitaillement (Entrée)' : 'Nouvelle Vente (Sortie)',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<WaterItem>(
              decoration: const InputDecoration(labelText: 'Marque', border: OutlineInputBorder()),
              items: widget.produits.map((item) => DropdownMenuItem(value: item, child: Text('${item.marque} - ${item.format}'))).toList(),
              onChanged: (val) => setState(() => _produitSelectionne = val),
            ),
            const SizedBox(height: 15),

            // CHAMP NOM DU CLIENT (TOUJOURS VISIBLE MAINTENANT)
            TextField(
              controller: _nomClientController,
              decoration: const InputDecoration(
                labelText: 'Nom du Client / Livreur',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                hintText: 'Ex: M. Jean',
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _quantiteController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nombre de Paquets', border: OutlineInputBorder()),
            ),

            // ... Reste du build (Montant Total si ravitaillement et Switch Paiement) ...
            if (widget.estRavitaillement) ...[
              const SizedBox(height: 15),
              TextField(
                controller: _montantTotalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Montant Total Payé', border: OutlineInputBorder(), prefixText: 'FCFA '),
              ),
            ],

            SwitchListTile(
              title: const Text('Paiement effectué'),
              value: _estPaye,
              activeColor: Colors.greenAccent,
              onChanged: (val) => setState(() => _estPaye = val),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isAdmin ? (widget.estRavitaillement ? Colors.blueAccent : Colors.greenAccent) : Colors.orangeAccent,
                    foregroundColor: Colors.white
                ),
                onPressed: _validerOperation,
                child: Text(widget.isAdmin ? 'Valider' : 'Envoyer pour vérification', style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}