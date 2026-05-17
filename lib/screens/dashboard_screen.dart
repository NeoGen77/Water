import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // NOUVEAU : Nécessaire pour FilteringTextInputFormatter
import '../database/db_helper.dart';
import '../models/water_item.dart';
import '../widgets/stock_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<WaterItem>> stockList;

  @override
  void initState() {
    super.initState();
    _refreshStock();
  }

  void _refreshStock() {
    setState(() {
      stockList = DBHelper().getAllItems();
    });
  }

  // Fonction pour ouvrir le formulaire (Sert pour l'AJOUT et la MODIFICATION)
  void _ouvrirFormulaire(BuildContext context, {WaterItem? itemAEditer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FormulaireProduit(
          onProduitAjoute: _refreshStock,
          itemAEditer: itemAEditer, // On passe l'item s'il y en a un à modifier
        );
      },
    );
  }

  // Fonction pour demander confirmation avant de supprimer
  void _confirmerSuppression(WaterItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce produit ?', style: TextStyle(color: Colors.redAccent)),
        content: Text('Êtes-vous sûr de vouloir retirer ${item.marque} du catalogue ? Cette action est irréversible et supprimera le produit de l\'inventaire.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Annuler
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Fermer la boite de dialogue

              // Capture du messenger AVANT l'action asynchrone (Correction Async Gap)
              final messenger = ScaffoldMessenger.of(context);

              await DBHelper().deleteWaterItem(item.id!); // Supprimer de la BDD

              _refreshStock(); // Rafraîchir l'écran

              // Utilisation du messenger capturé
              messenger.showSnackBar(
                const SnackBar(content: Text('Produit supprimé avec succès !'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Oui, Supprimer'),
          ),
        ],
      ),
    );
  }

  // Fonction qui affiche le petit menu flottant quand on clique sur une carte
  void _montrerOptionsProduit(WaterItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFF4C4DDC)),
                  title: const Text('Modifier ce produit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Changer les prix, le nom ou le stock', style: TextStyle(color: Colors.white54)),
                  onTap: () {
                    Navigator.pop(context); // Ferme le menu
                    _ouvrirFormulaire(context, itemAEditer: item); // Ouvre le formulaire pré-rempli
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text('Supprimer du catalogue', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context); // Ferme le menu
                    _confirmerSuppression(item); // Ouvre l'alerte
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire Global'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStock,
          )
        ],
      ),
      body: FutureBuilder<List<WaterItem>>(
        future: stockList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 20),
                  const Text('Le catalogue est vide.', style: TextStyle(fontSize: 18, color: Colors.white70)),
                  const Text('Cliquez sur + pour ajouter un produit.', style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () => _montrerOptionsProduit(items[index]), // Ouvre les options au clic
                child: StockCard(item: items[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(context),
        backgroundColor: const Color(0xFF4C4DDC),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau Produit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- LE FORMULAIRE MIXTE (CRÉATION ET MODIFICATION) ---
class FormulaireProduit extends StatefulWidget {
  final VoidCallback onProduitAjoute;
  final WaterItem? itemAEditer; // Si ce paramètre n'est pas nul, on est en mode MODIFICATION

  const FormulaireProduit({super.key, required this.onProduitAjoute, this.itemAEditer});

  @override
  State<FormulaireProduit> createState() => _FormulaireProduitState();
}

class _FormulaireProduitState extends State<FormulaireProduit> {
  final _marqueController = TextEditingController();
  final _formatController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _seuilController = TextEditingController();
  final _prixAchatController = TextEditingController(); // NOUVEAU
  final _prixVenteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Si on modifie un produit, on pré-remplit les cases avec ses données !
    if (widget.itemAEditer != null) {
      _marqueController.text = widget.itemAEditer!.marque;
      _formatController.text = widget.itemAEditer!.format;
      _quantiteController.text = widget.itemAEditer!.quantite.toString();
      _seuilController.text = widget.itemAEditer!.seuilAlerte.toString();

      // On convertit les doubles en entiers s'ils sont ronds pour éviter les ".0" à l'affichage
      _prixAchatController.text = widget.itemAEditer!.prixAchat == widget.itemAEditer!.prixAchat.toInt()
          ? widget.itemAEditer!.prixAchat.toInt().toString()
          : widget.itemAEditer!.prixAchat.toString();

      _prixVenteController.text = widget.itemAEditer!.prixVente == widget.itemAEditer!.prixVente.toInt()
          ? widget.itemAEditer!.prixVente.toInt().toString()
          : widget.itemAEditer!.prixVente.toString();
    }
  }

  void _sauvegarder() async {
    if (_marqueController.text.isNotEmpty && _formatController.text.isNotEmpty && _prixVenteController.text.isNotEmpty) {

      // Parsing sécurisé
      double pAchat = double.tryParse(_prixAchatController.text) ?? 0.0;
      double pVente = double.tryParse(_prixVenteController.text) ?? 0.0;

      // Alerte si on vend moins cher qu'on a acheté
      if (pVente < pAchat) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Attention : Le prix de vente est inférieur au prix d\'achat !'), backgroundColor: Colors.orangeAccent),
        );
      }

      final newItem = WaterItem(
        id: widget.itemAEditer?.id, // On conserve l'ID si on modifie, sinon SQLite s'occupe d'en créer un
        marque: _marqueController.text,
        format: _formatController.text,
        quantite: int.tryParse(_quantiteController.text) ?? 0,
        seuilAlerte: int.tryParse(_seuilController.text) ?? 10,
        prixAchat: pAchat, // NOUVEAU
        prixVente: pVente,
      );

      // Capture des outils avant le await
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      // Le système détecte si c'est une création ou une modification
      if (widget.itemAEditer == null) {
        await DBHelper().insertWaterItem(newItem);
      } else {
        await DBHelper().updateWaterItem(newItem);
      }

      widget.onProduitAjoute();
      navigator.pop(); // Ferme le formulaire

      messenger.showSnackBar(
        SnackBar(
            content: Text(widget.itemAEditer == null ? '✅ Produit créé !' : '✅ Produit mis à jour !'),
            backgroundColor: Colors.green
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir la marque, le format et le prix de vente.'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool estModification = widget.itemAEditer != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 25,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(estModification ? Icons.edit_note : Icons.add_box, color: const Color(0xFF4C4DDC), size: 30),
                const SizedBox(width: 10),
                Text(estModification ? 'Modifier le produit' : 'Nouveau produit',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 25),

            TextField(
              controller: _marqueController,
              decoration: const InputDecoration(
                  labelText: 'Marque (ex: Lafi)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop_outlined)
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _formatController,
              decoration: const InputDecoration(
                  labelText: 'Format (ex: Paquet 24x 500ml)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_drink_outlined)
              ),
            ),
            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantiteController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Stock actuel', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _seuilController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Seuil Alerte', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const Divider(height: 40, color: Colors.white24),

            // NOUVEAU : Zone de tarification
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("TARIFICATION (FCFA)", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _prixAchatController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Prix d\'Achat',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shopping_cart_outlined, color: Colors.orangeAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _prixVenteController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Prix de Vente',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sell_outlined, color: Colors.greenAccent),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: estModification ? Colors.orangeAccent : const Color(0xFF4C4DDC),
                    foregroundColor: estModification ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: _sauvegarder,
                child: Text(
                    estModification ? 'ENREGISTRER' : 'CRÉER LE PRODUIT',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}