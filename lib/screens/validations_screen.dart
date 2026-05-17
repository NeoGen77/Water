import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_item.dart';
import '../models/water_item.dart';

class ValidationsScreen extends StatefulWidget {
  const ValidationsScreen({super.key});

  @override
  State<ValidationsScreen> createState() => _ValidationsScreenState();
}

class _ValidationsScreenState extends State<ValidationsScreen> {
  late Future<List<TransactionItem>> _transactionsEnAttente;

  @override
  void initState() {
    super.initState();
    _chargerEnAttente();
  }

  void _chargerEnAttente() {
    setState(() {
      _transactionsEnAttente = DBHelper().getTransactionsEnAttente();
    });
  }

  // Fonction pour APPROUVER une saisie
  void _approuver(TransactionItem trans) async {
    // 1. Capture du messenger AVANT les await pour éviter les Async Gaps
    final messenger = ScaffoldMessenger.of(context);

    // --- SÉCURITÉ OPTION A : VÉRIFICATION DU STOCK AVANT VALIDATION ---
    if (trans.type == 'SORTIE') {
      List<WaterItem> produits = await DBHelper().getAllItems();
      WaterItem produitConcerne = produits.firstWhere((p) => p.id == trans.waterItemId);

      if (trans.quantite > produitConcerne.quantite) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Stock Insuffisant", style: TextStyle(color: Colors.redAccent)),
            content: Text(
                "Impossible de valider : la secrétaire a saisi ${trans.quantite} paquets, mais il n'en reste que ${produitConcerne.quantite} en stock de ${trans.marque}."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Compris"),
              ),
            ],
          ),
        );
        return; // On bloque la validation
      }
    }

    // 2. Validation en base de données
    await DBHelper().validerTransaction(trans.id!);

    // 3. Mise à jour du stock
    int variation = trans.type == 'ENTREE' ? trans.quantite : -trans.quantite;
    await DBHelper().updateStock(trans.waterItemId, variation);

    // 4. Rafraîchissement et Notification via le messenger capturé
    _chargerEnAttente();
    messenger.showSnackBar(
      const SnackBar(content: Text('✅ Opération validée ! Stock mis à jour.'), backgroundColor: Colors.green),
    );
  }

  // Fonction pour REJETER une saisie
  void _rejeter(TransactionItem trans) async {
    // 1. Capture du messenger
    final messenger = ScaffoldMessenger.of(context);

    // 2. Suppression en base
    await DBHelper().supprimerTransaction(trans.id!);

    // 3. Rafraîchissement et Notification
    _chargerEnAttente();
    messenger.showSnackBar(
      const SnackBar(content: Text('❌ Opération rejetée et supprimée.'), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification Secrétaire'),
      ),
      body: FutureBuilder<List<TransactionItem>>(
        future: _transactionsEnAttente,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFF00E676)),
                  const SizedBox(height: 20),
                  Text('Tout est à jour !', style: Theme.of(context).textTheme.titleLarge),
                  const Text('Aucune saisie en attente.', style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          final transactions = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final trans = transactions[index];
              bool estEntree = trans.type == 'ENTREE';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.orangeAccent, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: estEntree
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : Colors.green.withValues(alpha: 0.2),
                                child: Icon(
                                  estEntree ? Icons.download : Icons.upload,
                                  color: estEntree ? Colors.blue : Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(trans.marque, style: Theme.of(context).textTheme.bodyLarge),
                                  Text(trans.date, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${trans.montant.toInt()} F',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                              ),
                              // NOUVEAU : Affichage du bénéfice uniquement pour les sorties (ventes)
                              if (!estEntree)
                                Text(
                                  '+ ${trans.benefice.toInt()} F net',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('📦 Quantité : ${trans.quantite} paquets', style: const TextStyle(color: Colors.white70)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: trans.estPaye ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              trans.estPaye ? 'PAYÉ' : 'À CRÉDIT',
                              style: TextStyle(
                                color: trans.estPaye ? Colors.green : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (trans.nomClient != null && trans.nomClient != "Client Anonyme")
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text('👤 Client : ${trans.nomClient}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        ),
                      const Divider(height: 30, color: Colors.white10),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                              onPressed: () => _rejeter(trans),
                              icon: const Icon(Icons.close),
                              label: const Text('REJETER'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E676),
                                foregroundColor: Colors.black,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => _approuver(trans),
                              icon: const Icon(Icons.check),
                              label: const Text('VALIDER'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}