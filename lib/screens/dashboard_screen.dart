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

  // Fonction pour ouvrir le formulaire d'ajout d'une nouvelle marque
  void _ouvrirFormulaireAjout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FormulaireNouveauProduit(onProduitAjoute: _refreshStock);
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
            return const Center(child: Text('Le catalogue est vide.'));
          }

          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // De l'espace pour ne pas cacher le bouton flottant
            itemCount: items.length,
            itemBuilder: (context, index) {
              return StockCard(item: items[index]);
            },
          );
        },
      ),
      // LE NOUVEAU BOUTON AJOUTER
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaireAjout(context),
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau Produit', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// --- LE FORMULAIRE DE CRÉATION DE PRODUIT ---
class FormulaireNouveauProduit extends StatefulWidget {
  final VoidCallback onProduitAjoute;

  const FormulaireNouveauProduit({super.key, required this.onProduitAjoute});

  @override
  State<FormulaireNouveauProduit> createState() => _FormulaireNouveauProduitState();
}

class _FormulaireNouveauProduitState extends State<FormulaireNouveauProduit> {
  final _marqueController = TextEditingController();
  final _formatController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _seuilController = TextEditingController();

  // --- SEUL LE PRIX DE VENTE EST NÉCESSAIRE MAINTENANT ---
  final _prixVenteController = TextEditingController();

  void _sauvegarder() async {
    if (_marqueController.text.isNotEmpty && _formatController.text.isNotEmpty) {
      final newItem = WaterItem(
        marque: _marqueController.text,
        format: _formatController.text,
        quantite: int.tryParse(_quantiteController.text) ?? 0,
        seuilAlerte: int.tryParse(_seuilController.text) ?? 10, // 10 par défaut
        // --- PARSAGE DU PRIX DE VENTE UNIQUEMENT ---
        prixVente: double.tryParse(_prixVenteController.text) ?? 0.0,
      );

      await DBHelper().insertWaterItem(newItem);

      if (!mounted) return;
      Navigator.pop(context); // Ferme le formulaire
      widget.onProduitAjoute(); // Rafraîchit la liste derrière

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit ajouté au catalogue !'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ajouter une marque d\'eau', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    decoration: const InputDecoration(labelText: 'Stock initial (Paquets)', border: OutlineInputBorder()),
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

            // --- LE CHAMP PRIX DE VENTE PREND TOUTE LA LARGEUR ---
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                onPressed: _sauvegarder,
                child: const Text('Sauvegarder le produit', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}