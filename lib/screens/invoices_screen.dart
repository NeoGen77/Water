import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_item.dart';
import '../models/water_item.dart';
import '../services/backup_service.dart'; // NOUVEAU : Import de la sauvegarde locale
import 'validations_screen.dart';
import 'reports_screen.dart';
import 'debts_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  // --- VARIABLES POUR LA PAGINATION ---
  final ScrollController _scrollController = ScrollController();
  final List<TransactionItem> _transactions = []; // CORRECTION : rendu "final"
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  // --- VARIABLES EXISTANTES ---
  String _filtreActuel = 'Tout';

  double _valeurTotaleStock = 0;
  List<Map<String, dynamic>> _detailsStock = [];
  bool _afficherDetailsStock = false;

  double _totalRecettes = 0;
  double _totalDepenses = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        _chargerPlusDeTransactions();
      }
    });
    _initialiserEcran();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE CHARGEMENT OPTIMISÉE ---
  void _initialiserEcran() {
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

    List<TransactionItem> nouvellesLignes = await DBHelper().getAllTransactions(
        filter: _filtreActuel,
        limit: _limit,
        offset: _offset
    );

    setState(() {
      _isLoading = false;
      if (nouvellesLignes.length < _limit) {
        _hasMore = false;
      }
      _transactions.addAll(nouvellesLignes);
      _offset += _limit;
    });
  }

  void _chargerStatistiques() {
    DBHelper().getBilanFinancier(filter: _filtreActuel).then((bilan) {
      if (mounted) {
        setState(() {
          _totalRecettes = bilan['recettes']!;
          _totalDepenses = bilan['depenses']!;
        });
      }
    });

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
          // NOUVEAU BOUTON : Sauvegarde & Restauration Locale
          PopupMenuButton<String>(
            icon: const Icon(Icons.security, color: Colors.greenAccent),
            tooltip: 'Sécurité et Sauvegardes',
            onSelected: (String choix) async {
              // On capture le ScaffoldMessenger avant le await pour éviter l'erreur Async Gap
              final messenger = ScaffoldMessenger.of(context);

              if (choix == 'sauvegarder') {
                bool succes = await BackupService.creerCopieLocale();
                if (!mounted) return;
                if (succes) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('✅ Sauvegarde créée dans vos dossiers !'), backgroundColor: Colors.green),
                  );
                }
              } else if (choix == 'restaurer') {
                // Demande de confirmation avant d'écraser la base
                bool? confirmer = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Attention", style: TextStyle(color: Colors.red)),
                    content: const Text("Cela remplacera toutes vos données actuelles par le fichier de sauvegarde. Voulez-vous continuer ?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Restaurer"),
                      ),
                    ],
                  ),
                );

                if (confirmer == true) {
                  bool succes = await BackupService.restaurerCopieLocale();
                  if (!mounted) return;
                  if (succes) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('🔄 Données restaurées ! Veuillez relancer l\'application.'), backgroundColor: Colors.blue),
                    );
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'sauvegarder',
                  child: Row(
                    children: [
                      Icon(Icons.download, color: Colors.green),
                      SizedBox(width: 10),
                      Text('Créer une sauvegarde'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'restaurer',
                  child: Row(
                    children: [
                      Icon(Icons.restore, color: Colors.orange),
                      SizedBox(width: 10),
                      Text('Restaurer une copie'),
                    ],
                  ),
                ),
              ];
            },
          ),

          // BOUTON : Accès aux Rapports Journaliers
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.indigo),
            tooltip: 'Rapports Journaliers',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsScreen()),
              );
            },
          ),

          // BOUTON : Accès direct à l'écran des dettes
          IconButton(
            icon: const Icon(Icons.menu_book, color: Colors.redAccent),
            tooltip: 'Suivi des Crédits / Dettes',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebtsScreen()),
              );
              _initialiserEcran();
            },
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.blueAccent),
            tooltip: 'Filtrer par date',
            onSelected: (String choix) {
              setState(() {
                _filtreActuel = choix;
              });
              _initialiserEcran();
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
              _initialiserEcran();
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
                        couleur: Colors.redAccent, // Mis en rouge pour contraster avec recettes
                        icone: Icons.arrow_downward,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTotalCard(
                        titre: 'Recettes',
                        valeur: '${_totalRecettes.toInt()} F',
                        couleur: Colors.green,
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
                              fontSize: 16,
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
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _transactions.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {

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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
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
                              color: estEntree ? Colors.blueAccent : Colors.green,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${estEntree ? "+" : "-"}${trans.quantite} paquets',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: trans.estPaye ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              trans.estPaye ? 'Payé' : 'À crédit',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: couleur),
          ),
          const SizedBox(height: 2),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}