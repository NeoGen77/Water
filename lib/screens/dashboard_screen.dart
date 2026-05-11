import 'package:flutter/material.dart';
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
        title: const Text('Supprimer ce produit ?'),
        content: Text('Êtes-vous sûr de vouloir retirer ${item.marque} du catalogue ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Annuler
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Fermer la boite de dialogue
              await DBHelper().deleteWaterItem(item.id!); // Supprimer de la BDD
              _refreshStock(); // Rafraîchir l'écran
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit supprimé !'), backgroundColor: Colors.red));
              }
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
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blueAccent),
                title: const Text('Modifier ce produit'),
                subtitle: const Text('Changer le prix, le nom ou le stock'),
                onTap: () {
                  Navigator.pop(context); // Ferme le menu
                  _ouvrirFormulaire(context, itemAEditer: item); // Ouvre le formulaire pré-rempli
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Supprimer du catalogue'),
                onTap: () {
                  Navigator.pop(context); // Ferme le menu
                  _confirmerSuppression(item); // Ouvre l'alerte
                },
              ),
            ],
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
            return Center(child: Text('Erreur: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Le catalogue est vide. Cliquez sur + pour ajouter un produit.'));
          }

          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: items.length,
            itemBuilder: (context, index) {
              // On enveloppe ta StockCard avec un GestureDetector pour détecter le clic
              return InkWell(
                onTap: () => _montrerOptionsProduit(items[index]), // Ouvre les options au clic !
                child: StockCard(item: items[index]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(context),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau Produit', style: TextStyle(color: Colors.white)),
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
      _prixVenteController.text = widget.itemAEditer!.prixVente.toString();
    }
  }

  void _sauvegarder() async {
    if (_marqueController.text.isNotEmpty && _formatController.text.isNotEmpty) {
      final newItem = WaterItem(
        id: widget.itemAEditer?.id, // On conserve l'ID si on modifie, sinon SQLite s'occupe d'en créer un
        marque: _marqueController.text,
        format: _formatController.text,
        quantite: int.tryParse(_quantiteController.text) ?? 0,
        seuilAlerte: int.tryParse(_seuilController.text) ?? 10,
        prixVente: double.tryParse(_prixVenteController.text) ?? 0.0,
      );

      // Le système détecte si c'est une création ou une modification
      if (widget.itemAEditer == null) {
        await DBHelper().insertWaterItem(newItem);
      } else {
        await DBHelper().updateWaterItem(newItem);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onProduitAjoute();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.itemAEditer == null ? 'Produit créé !' : 'Produit mis à jour !'),
            backgroundColor: Colors.green
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool estModification = widget.itemAEditer != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(estModification ? 'Modifier le produit' : 'Ajouter une marque d\'eau',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _marqueController,
              decoration: const InputDecoration(labelText: 'Marque (ex: Lafi)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _formatController,
              decoration: const InputDecoration(labelText: 'Format (ex: Paquet 24x 500ml)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantiteController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock (Paquets)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _seuilController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Seuil d\'alerte', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _prixVenteController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Prix de Vente (par Paquet)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: estModification ? Colors.orangeAccent : Colors.blueAccent,
                    foregroundColor: Colors.white
                ),
                onPressed: _sauvegarder,
                child: Text(estModification ? 'Enregistrer les modifications' : 'Créer le produit', style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}