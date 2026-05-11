import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_item.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<List<TransactionItem>> _historique;
  String _topProduit = "..."; // Variable pour stocker l'eau la plus vendue

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  void _chargerHistorique() {
    // 1. On charge la liste des transactions
    setState(() {
      _historique = DBHelper().getAllTransactions();
    });

    // 2. On charge la statistique du produit le plus vendu en arrière-plan
    DBHelper().getTopSellingProduct().then((top) {
      if (mounted) {
        setState(() {
          _topProduit = top;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique & Caisse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerHistorique, // Bouton pour rafraîchir manuellement
          )
        ],
      ),
      body: FutureBuilder<List<TransactionItem>>(
        future: _historique,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aucune transaction pour le moment.', style: TextStyle(color: Colors.grey)));
          }

          final transactions = snapshot.data!;

          // --- CALCUL DES TOTAUX FINANCIERS ---
          double argentEntre = 0; // Recettes (Ventes = SORTIE de stock)
          double argentSorti = 0; // Dépenses (Ravitaillement = ENTREE en stock)

          for (var trans in transactions) {
            if (trans.type == 'ENTREE') {
              argentSorti += trans.montant;
            } else {
              argentEntre += trans.montant;
            }
          }

          return Column(
            children: [
              // --- TABLEAU DE BORD FINANCIER (HAUT DE L'ÉCRAN) ---
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTotalCard(
                            titre: 'Dépenses',
                            valeur: '${argentSorti.toInt()} F',
                            couleur: Colors.blueAccent,
                            icone: Icons.arrow_downward,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTotalCard(
                            titre: 'Recettes',
                            valeur: '${argentEntre.toInt()} F',
                            couleur: Colors.greenAccent,
                            icone: Icons.arrow_upward,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Bannière du produit star
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Top Vente : $_topProduit",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Colors.grey),

              // --- LISTE DES FACTURES (BAS DE L'ÉCRAN) ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final trans = transactions[index];
                    bool estEntree = trans.type == 'ENTREE';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: estEntree
                              ? Colors.blueAccent.withValues(alpha: 0.2)
                              : Colors.greenAccent.withValues(alpha: 0.2),
                          child: Icon(
                            estEntree ? Icons.arrow_downward : Icons.arrow_upward,
                            color: estEntree ? Colors.blueAccent : Colors.greenAccent,
                          ),
                        ),
                        title: Text(
                          // Mise à jour du vocabulaire grossiste
                          '${trans.marque} (${estEntree ? "Ravitaillement" : "Vente"})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Date: ${trans.date}'),

                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${trans.montant.toInt()} FCFA',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: estEntree ? Colors.blueAccent : Colors.greenAccent,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                // "articles" remplacé par "paquets"
                                '${estEntree ? "+" : "-"}${trans.quantite} paquets',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                decoration: BoxDecoration(
                                  color: trans.estPaye ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  trans.estPaye ? 'Payé' : 'À crédit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: trans.estPaye ? Colors.green : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGET POUR DESSINER LES CARTES DE TOTAUX ---
  Widget _buildTotalCard({required String titre, required String valeur, required Color couleur, required IconData icone}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icone, color: couleur, size: 24),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: couleur),
          ),
          const SizedBox(height: 2),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}