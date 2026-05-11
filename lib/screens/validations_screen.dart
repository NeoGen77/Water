import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_item.dart';

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
    // 1. On change le statut en 'VALIDEE'
    await DBHelper().validerTransaction(trans.id!);

    // 2. On met à jour le stock (C'est SEULEMENT maintenant que le stock bouge !)
    int variation = trans.type == 'ENTREE' ? trans.quantite : -trans.quantite;
    await DBHelper().updateStock(trans.waterItemId, variation);

    // 3. On rafraîchit l'écran et on notifie
    _chargerEnAttente();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opération validée ! Stock mis à jour.'), backgroundColor: Colors.green),
      );
    }
  }

  // Fonction pour REJETER une saisie (erreur de la secrétaire)
  void _rejeter(TransactionItem trans) async {
    // On supprime purement et simplement le brouillon
    await DBHelper().supprimerTransaction(trans.id!);

    _chargerEnAttente();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opération rejetée et supprimée.'), backgroundColor: Colors.redAccent),
      );
    }
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.greenAccent),
                  SizedBox(height: 20),
                  Text('Tout est à jour !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Aucune saisie en attente.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final transactions = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final trans = transactions[index];
              bool estEntree = trans.type == 'ENTREE';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: const BorderSide(color: Colors.orangeAccent, width: 1), // Bordure orange pour "En attente"
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(estEntree ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: estEntree ? Colors.blueAccent : Colors.greenAccent),
                              const SizedBox(width: 8),
                              Text(
                                trans.marque,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Text(
                            '${trans.montant.toInt()} FCFA',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Quantité : ${trans.quantite} paquets', style: const TextStyle(color: Colors.grey)),
                          Text(trans.estPaye ? 'Paiement: Réglé' : 'Paiement: À crédit',
                              style: TextStyle(color: trans.estPaye ? Colors.green : Colors.redAccent, fontSize: 12)),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Bouton Rejeter
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            onPressed: () => _rejeter(trans),
                            icon: const Icon(Icons.close),
                            label: const Text('REJETER'),
                          ),
                          // Bouton Approuver
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            onPressed: () => _approuver(trans),
                            icon: const Icon(Icons.check),
                            label: const Text('VALIDER'),
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