import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import '../data/produit_repo.dart';
import '../models/produit.dart';
import '../widgets/stock_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _repo = ProduitRepo();
  late Future<List<Produit>> _stockList;

  @override
  void initState() {
    super.initState();
    _refreshStock();
  }

  void _refreshStock() {
    final futur = _repo.tous();
    setState(() {
      _stockList = futur;
    });
  }

  void _ouvrirFormulaire(BuildContext context, {Produit? itemAEditer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.carte,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FormulaireProduit(
        onProduitAjoute: _refreshStock,
        itemAEditer: itemAEditer,
      ),
    );
  }

  void _confirmerSuppression(Produit item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce produit ?',
            style: TextStyle(color: Colors.redAccent)),
        content: Text(
            'Êtes-vous sûr de vouloir retirer ${item.marque} du catalogue ? '
            'Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              await _repo.supprimer(item.id!);
              _refreshStock();
              messenger.showSnackBar(
                const SnackBar(
                    content: Text('Produit supprimé.'),
                    backgroundColor: Colors.red),
              );
            },
            child: const Text('Oui, Supprimer'),
          ),
        ],
      ),
    );
  }

  void _montrerOptionsProduit(Produit item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.carte,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
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
                leading: const Icon(Icons.edit, color: AppColors.primaire),
                title: const Text('Modifier ce produit',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Changer les prix, le nom ou le stock',
                    style: TextStyle(color: Colors.white54)),
                onTap: () {
                  Navigator.pop(ctx);
                  _ouvrirFormulaire(context, itemAEditer: item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: const Text('Supprimer du catalogue',
                    style: TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmerSuppression(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventaire Global'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshStock),
        ],
      ),
      body: FutureBuilder<List<Produit>>(
        future: _stockList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Erreur: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 80, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 20),
                  const Text('Le catalogue est vide.',
                      style: TextStyle(fontSize: 18, color: Colors.white70)),
                  const Text('Cliquez sur + pour ajouter un produit.',
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            );
          }

          final items = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, top: 10),
            itemCount: items.length,
            itemBuilder: (context, index) => InkWell(
              onTap: () => _montrerOptionsProduit(items[index]),
              child: StockCard(item: items[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(context),
        backgroundColor: AppColors.primaire,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau Produit',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- FORMULAIRE DE CRÉATION / MODIFICATION ---
class FormulaireProduit extends StatefulWidget {
  final VoidCallback onProduitAjoute;
  final Produit? itemAEditer;

  const FormulaireProduit(
      {super.key, required this.onProduitAjoute, this.itemAEditer});

  @override
  State<FormulaireProduit> createState() => _FormulaireProduitState();
}

class _FormulaireProduitState extends State<FormulaireProduit> {
  final _repo = ProduitRepo();
  final _marqueController = TextEditingController();
  final _formatController = TextEditingController();
  final _quantiteController = TextEditingController();
  final _seuilController = TextEditingController();
  final _prixAchatController = TextEditingController();
  final _prixVenteController = TextEditingController();

  String _sansDecimalesInutiles(double valeur) =>
      valeur == valeur.toInt() ? valeur.toInt().toString() : valeur.toString();

  @override
  void initState() {
    super.initState();
    final item = widget.itemAEditer;
    if (item != null) {
      _marqueController.text = item.marque;
      _formatController.text = item.format;
      _quantiteController.text = item.quantite.toString();
      _seuilController.text = item.seuilAlerte.toString();
      _prixAchatController.text = _sansDecimalesInutiles(item.prixAchat);
      _prixVenteController.text = _sansDecimalesInutiles(item.prixVente);
    }
  }

  @override
  void dispose() {
    _marqueController.dispose();
    _formatController.dispose();
    _quantiteController.dispose();
    _seuilController.dispose();
    _prixAchatController.dispose();
    _prixVenteController.dispose();
    super.dispose();
  }

  Future<void> _sauvegarder() async {
    if (_marqueController.text.isEmpty ||
        _formatController.text.isEmpty ||
        _prixVenteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Veuillez remplir la marque, le format et le prix de vente.'),
            backgroundColor: Colors.redAccent),
      );
      return;
    }

    final pAchat = double.tryParse(_prixAchatController.text) ?? 0.0;
    final pVente = double.tryParse(_prixVenteController.text) ?? 0.0;

    if (pVente < pAchat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                '⚠️ Attention : le prix de vente est inférieur au prix d\'achat !'),
            backgroundColor: Colors.orangeAccent),
      );
    }

    final item = Produit(
      id: widget.itemAEditer?.id,
      marque: _marqueController.text.trim(),
      format: _formatController.text.trim(),
      quantite: int.tryParse(_quantiteController.text) ?? 0,
      seuilAlerte: int.tryParse(_seuilController.text) ?? 10,
      prixAchat: pAchat,
      prixVente: pVente,
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (widget.itemAEditer == null) {
      await _repo.creer(item);
    } else {
      await _repo.modifier(item);
    }

    widget.onProduitAjoute();
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
          content: Text(widget.itemAEditer == null
              ? '✅ Produit créé !'
              : '✅ Produit mis à jour !'),
          backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estModification = widget.itemAEditer != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 25,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(estModification ? Icons.edit_note : Icons.add_box,
                    color: AppColors.primaire, size: 30),
                const SizedBox(width: 10),
                Text(estModification ? 'Modifier le produit' : 'Nouveau produit',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 25),
            TextField(
              controller: _marqueController,
              decoration: const InputDecoration(
                  labelText: 'Marque (ex: Lafi)',
                  prefixIcon: Icon(Icons.water_drop_outlined)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _formatController,
              decoration: const InputDecoration(
                  labelText: 'Format (ex: Paquet 24x 500ml)',
                  prefixIcon: Icon(Icons.local_drink_outlined)),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantiteController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Stock actuel'),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _seuilController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Seuil Alerte'),
                  ),
                ),
              ],
            ),
            const Divider(height: 40, color: Colors.white24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('TARIFICATION (FCFA)',
                  style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
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
                      prefixIcon: Icon(Icons.shopping_cart_outlined,
                          color: Colors.orangeAccent),
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
                      prefixIcon:
                          Icon(Icons.sell_outlined, color: Colors.greenAccent),
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
                    backgroundColor: estModification
                        ? Colors.orangeAccent
                        : AppColors.primaire,
                    foregroundColor:
                        estModification ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: _sauvegarder,
                child: Text(estModification ? 'ENREGISTRER' : 'CRÉER LE PRODUIT',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
