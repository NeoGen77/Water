import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_item.dart';
import '../models/water_item.dart';
import 'validations_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  // --- VARIABLES POUR LA PAGINATION ---
  final ScrollController _scrollController = ScrollController();
  List<TransactionItem> _transactions = [];
  bool _isLoading = false;   // Indique si un chargement est en cours
  bool _hasMore = true;      // Indique s'il reste des données dans la base
  int _offset = 0;           // Point de départ pour la requête SQL
  final int _limit = 20;     // Nombre de lignes à charger à la fois

  // --- VARIABLES EXISTANTES ---
  String _topProduit = "...";
  String _filtreActuel = 'Tout';

  // Variables pour les détails du stock
  double _valeurTotaleStock = 0;
  List<Map<String, dynamic>> _detailsStock = [];
  bool _afficherDetailsStock = false;

  // Variables pour les totaux globaux calculés par SQL
  double _totalRecettes = 0;
  double _totalDepenses = 0;

  @override
  void initState() {
    super.initState();

    // Détecteur de défilement : charge la suite quand on arrive en bas
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        _chargerPlusDeTransactions();
      }
    });

    _initialiserEcran();
  }

  @override
  void dispose() {
    _scrollController.dispose(); // Important pour libérer la mémoire
    super.dispose();
  }

  // --- LOGIQUE DE CHARGEMENT OPTIMISÉE ---

  void _initialiserEcran() {
    // On remet tout à zéro (utile quand on change de filtre)
    setState(() {
      _transactions.clear();
      _offset = 0;
      _hasMore = true;
    });

    _chargerPlusDeTransactions();
    _chargerStatistiques();
  }

  Future<void> _chargerPlusDeTransactions() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    // On charge les 20 prochaines lignes
    List<TransactionItem> nouvellesLignes = await DBHelper().getAllTransactions(
        filter: _filtreActuel,
        limit: _limit,
        offset: _offset
    );

    setState(() {
      _isLoading = false;
      if (nouvellesLignes.length < _limit) {
        _hasMore = false; // On a atteint la fin de la base de données
      }
      _transactions.addAll(nouvellesLignes);
      _offset += _limit; // On décale le point de départ pour le prochain scroll
    });
  }

  void _chargerStatistiques() {
    // Top Vente
    DBHelper().getTopSellingProduct().then((top) {
      if (mounted) setState(() => _topProduit = top);
    });

    // Vrais totaux mathématiques (ultra-rapide)
    DBHelper().getBilanFinancier(filter: _filtreActuel).then((bilan) {
      if (mounted) {
        setState(() {
          _totalRecettes = bilan['recettes']!;
          _totalDepenses = bilan['depenses']!;
        });
      }
    });

    // Valeur Globale et détails du Stock
    DBHelper().getAllItems().then((items) {
      double total = 0;
      List<Map<String, dynamic>> details = [];

      for (WaterItem item in items) {
        double valeurItem = item.quantite * item.prixVente;
        total += valeurItem;

        if (item.quantite > 0) {
          details.add({
            'marque': item.marque,
            'format': item.format,
            'quantite': item.quantite,
            'valeur': valeurItem,
          });
        }
      }

      if (mounted) {
        setState(() {
          _valeurTotaleStock = total;
          _detailsStock = details;
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.blueAccent),
            tooltip: 'Filtrer par date',
            onSelected: (String choix) {
              setState(() {
                _filtreActuel = choix;
              });
              _initialiserEcran(); // Recharge tout avec le nouveau filtre
            },
            itemBuilder: (BuildContext context) {
              return ['Tout', 'Aujourd\'hui', 'Ce mois-ci'].map((String choix) {
                return PopupMenuItem<String>(
                  value: choix,
                  child: Row(
                    children: [
                      Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: _filtreActuel == choix ? Colors.blueAccent : Colors.grey
                      ),
                      const SizedBox(width: 10),
                      Text(
                          choix,
                          style: TextStyle(
                              color: _filtreActuel == choix ? Colors.blueAccent : Theme.of(context).textTheme.bodyMedium?.color,
                              fontWeight: _filtreActuel == choix ? FontWeight.bold : FontWeight.normal
                          )
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined, color: Colors.orangeAccent),
            tooltip: 'Saisies en attente',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ValidationsScreen()),
              );
              _initialiserEcran(); // Actualise si une transaction a été validée
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filtreActuel != 'Tout')
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              width: double.infinity,
              color: Colors.blueAccent.withValues(alpha: 0.1),
              child: Text(
                'Affichage : $_filtreActuel',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),

          // --- TABLEAU DE BORD FIXE ---
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
                        valeur: '${_totalDepenses.toInt()} F',
                        couleur: Colors.blueAccent,
                        icone: Icons.arrow_downward,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTotalCard(
                        titre: 'Recettes',
                        valeur: '${_totalRecettes.toInt()} F',
                        couleur: Colors.greenAccent,
                        icone: Icons.arrow_upward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Solde de Caisse :", style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(
                            "${(_totalRecettes - _totalDepenses).toInt()} FCFA",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (_totalRecettes - _totalDepenses) >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 10),

                      InkWell(
                        onTap: () {
                          setState(() {
                            _afficherDetailsStock = !_afficherDetailsStock;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Text("Valeur du Stock :", style: TextStyle(fontWeight: FontWeight.w500)),
                                  Icon(
                                      _afficherDetailsStock ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                      color: Colors.blueAccent
                                  ),
                                ],
                              ),
                              Text(
                                "${_valeurTotaleStock.toInt()} FCFA",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_afficherDetailsStock) ...[
                        const SizedBox(height: 8),
                        ..._detailsStock.map((detail) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 10, right: 5, bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    "• ${detail['marque']} ${detail['format']} (${detail['quantite']} pqt)",
                                    style: const TextStyle(fontSize: 12, color: Colors.black87)
                                ),
                                Text(
                                    "${detail['valeur'].toInt()} F",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black54)
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),

          // --- LISTE DÉFILANTE (PAGINATION) ---
          Expanded(
            child: _transactions.isEmpty && !_isLoading
                ? const Center(child: Text('Aucune transaction trouvée.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              controller: _scrollController, // Attache le détecteur de scroll
              padding: const EdgeInsets.all(8.0),
              // Ajoute +1 pour afficher l'indicateur de chargement en bas si nécessaire
              itemCount: _transactions.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {

                // Affiche le spinner de chargement si on est tout en bas
                if (index == _transactions.length) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(15.0),
                          child: CircularProgressIndicator()
                      )
                  );
                }

                final trans = _transactions[index];
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
                      '${trans.marque} (${estEntree ? "Ravitaillement" : "Vente"})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: ${trans.date}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                                Icons.person,
                                size: 14,
                                color: trans.estPaye ? Colors.grey : Colors.redAccent
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trans.nomClient ?? "Client Anonyme",
                              style: TextStyle(
                                  color: trans.estPaye ? Colors.grey : Colors.redAccent,
                                  fontWeight: trans.estPaye ? FontWeight.normal : FontWeight.bold,
                                  fontSize: 13
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
      ),
    );
  }

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