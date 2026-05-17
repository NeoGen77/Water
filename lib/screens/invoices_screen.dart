import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_item.dart';
import '../models/water_item.dart';
import '../services/backup_service.dart';
import 'validations_screen.dart';
import 'reports_screen.dart';
import 'debts_screen.dart';
import '../services/pdf_service.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  // --- VARIABLES POUR LA PAGINATION ---
  final ScrollController _scrollController = ScrollController();
  final List<TransactionItem> _transactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  // --- VARIABLES EXISTANTES ---
  String _filtreActuel = 'Tout';

  double _valeurTotaleStock = 0;
  List<Map<String, dynamic>> _detailsStock = [];
  bool _afficherDetailsStock = false;

  double _totalVentes = 0;
  double _totalDepenses = 0;
  double _totalBenefice = 0; // NOUVEAU

  // Code secret de sécurité
  final String _codeSecret = "98521";

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
          _totalVentes = bilan['ventes']!;
          _totalDepenses = bilan['depenses']!;
          _totalBenefice = bilan['benefices'] ?? 0; // Sécurité si null
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

  // --- FONCTION D'ANNULATION ---
  void _afficherBoiteAnnulation(BuildContext context, TransactionItem trans) {
    final TextEditingController codeController = TextEditingController();

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1D1E33),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
                Text("Annuler la saisie", style: TextStyle(color: Colors.redAccent, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Vous êtes sur le point de supprimer cette ${trans.type == 'SORTIE' ? 'vente' : 'entrée'} de ${trans.quantite} ${trans.marque}.",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                    "Le montant sera retiré de la caisse et le stock d'eau sera corrigé automatiquement.",
                    style: TextStyle(fontSize: 13, color: Colors.white54)
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Code administrateur',
                    labelStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Fermer", style: TextStyle(color: Colors.white54))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(ctx);

                  if (codeController.text == _codeSecret) {
                    navigator.pop(); // On ferme d'abord la boite
                    bool succes = await DBHelper().annulerTransaction(trans.id!);

                    if (succes) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('✅ Transaction annulée et stock restauré !'), backgroundColor: Colors.green),
                      );
                      _initialiserEcran();
                    } else {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('❌ Erreur lors de l\'annulation.'), backgroundColor: Colors.redAccent),
                      );
                    }
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('❌ Code incorrect. Action refusée.'), backgroundColor: Colors.redAccent),
                    );
                  }
                },
                child: const Text("Confirmer"),
              ),
            ],
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Historique & Caisse', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        actions: [
          // BOUTON : Sauvegarde & Restauration Locale
          PopupMenuButton<String>(
            icon: const Icon(Icons.security, color: Color(0xFF00E676)),
            tooltip: 'Sécurité et Sauvegardes',
            color: const Color(0xFF1D1E33),
            onSelected: (String choix) async {
              final messenger = ScaffoldMessenger.of(context);

              if (choix == 'sauvegarder') {
                bool succes = await BackupService.creerCopieLocale();
                if (succes) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('✅ Sauvegarde créée dans vos dossiers !'), backgroundColor: Colors.green),
                  );
                }
              } else if (choix == 'restaurer') {
                final navigator = Navigator.of(context);
                bool? confirmer = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1D1E33),
                    title: const Text("Attention", style: TextStyle(color: Colors.redAccent)),
                    content: const Text("Cela remplacera toutes vos données actuelles par le fichier de sauvegarde. Voulez-vous continuer ?", style: TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler", style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Restaurer"),
                      ),
                    ],
                  ),
                );

                if (confirmer == true) {
                  bool succes = await BackupService.restaurerCopieLocale();
                  if (succes) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('🔄 Données restaurées ! Veuillez relancer l\'application.'), backgroundColor: Colors.blueAccent),
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
                      Icon(Icons.download, color: Color(0xFF00E676)),
                      SizedBox(width: 10),
                      Text('Créer une sauvegarde', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'restaurer',
                  child: Row(
                    children: [
                      Icon(Icons.restore, color: Colors.orangeAccent),
                      SizedBox(width: 10),
                      Text('Restaurer une copie', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ];
            },
          ),

          // BOUTON : Accès aux Rapports Journaliers
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Color(0xFF4C4DDC)),
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
            icon: const Icon(Icons.menu_book, color: Colors.orangeAccent),
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
            icon: const Icon(Icons.filter_list, color: Colors.white54),
            tooltip: 'Filtrer par date',
            color: const Color(0xFF1D1E33),
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
                          color: _filtreActuel == choix ? const Color(0xFF4C4DDC) : Colors.white54
                      ),
                      const SizedBox(width: 10),
                      Text(
                          choix,
                          style: TextStyle(
                              color: _filtreActuel == choix ? const Color(0xFF4C4DDC) : Colors.white,
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
            icon: const Icon(Icons.fact_check_outlined, color: Colors.redAccent),
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
              padding: const EdgeInsets.symmetric(vertical: 6),
              width: double.infinity,
              color: const Color(0xFF4C4DDC).withValues(alpha: 0.1),
              child: Text(
                'Affichage : $_filtreActuel',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF4C4DDC), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
              ),
            ),

          // --- TABLEAU DE BORD FIXE ---
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFF1D1E33),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5)),
                ]
            ),
            child: Column(
              children: [
                // --- LES 3 CARTES (DÉPENSES, VENTES, BÉNÉFICE) ---
                Row(
                  children: [
                    Expanded(
                      child: _buildTotalCard(
                        titre: 'Dépenses',
                        valeur: '${_totalDepenses.toInt()} F',
                        couleur: Colors.redAccent,
                        icone: Icons.arrow_downward,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTotalCard(
                        titre: 'Ventes',
                        valeur: '${_totalVentes.toInt()} F',
                        couleur: const Color(0xFF4C4DDC),
                        icone: Icons.shopping_bag_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTotalCard(
                        titre: 'Bénéfice',
                        valeur: '${_totalBenefice.toInt()} F',
                        couleur: const Color(0xFF00E676),
                        icone: Icons.trending_up,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E21),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Solde de Caisse :", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                          Text(
                            "${(_totalVentes - _totalDepenses).toInt()} FCFA",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: (_totalVentes - _totalDepenses) >= 0 ? const Color(0xFF00E676) : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 15, color: Colors.white10),

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
                                  const Text("Valeur du Stock :", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                                  Icon(
                                      _afficherDetailsStock ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                      color: const Color(0xFF4C4DDC)
                                  ),
                                ],
                              ),
                              Text(
                                "${_valeurTotaleStock.toInt()} FCFA",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4C4DDC)),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_afficherDetailsStock) ...[
                        const SizedBox(height: 10),
                        ..._detailsStock.map((detail) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 10, right: 5, bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    "• ${detail['marque']} ${detail['format']} (${detail['quantite']} pqt)",
                                    style: const TextStyle(fontSize: 12, color: Colors.white54)
                                ),
                                Text(
                                    "${detail['valeur'].toInt()} F",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white38)
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
          const Divider(height: 1, color: Colors.white10),

          // --- LISTE DÉFILANTE (PAGINATION) ---
          Expanded(
            child: _transactions.isEmpty && !_isLoading
                ? const Center(child: Text('Aucune transaction trouvée.', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12.0),
              itemCount: _transactions.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {

                if (index == _transactions.length) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(15.0),
                          child: CircularProgressIndicator(color: Color(0xFF00E676))
                      )
                  );
                }

                final trans = _transactions[index];
                bool estEntree = trans.type == 'ENTREE';

                return Card(
                  color: const Color(0xFF1D1E33),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                  ),
                  // CORRECTION DU BOTTOM OVERFLOWED ICI : Utilisation d'un InkWell et Row
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onLongPress: () => _afficherBoiteAnnulation(context, trans),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Un peu plus d'espace vertical
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // --- 1. L'ICÔNE (Leading) ---
                          CircleAvatar(
                            backgroundColor: estEntree
                                ? Colors.blueAccent.withValues(alpha: 0.15)
                                : const Color(0xFF00E676).withValues(alpha: 0.15),
                            child: Icon(
                              estEntree ? Icons.arrow_downward : Icons.arrow_upward,
                              color: estEntree ? Colors.blueAccent : const Color(0xFF00E676),
                            ),
                          ),
                          const SizedBox(width: 15),

                          // --- 2. LE TEXTE CENTRAL (Title & Subtitle) ---
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${trans.marque} ${estEntree ? "(Ravitaillement)" : ""}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                Text(trans.date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                        Icons.person,
                                        size: 14,
                                        color: trans.estPaye ? Colors.white54 : Colors.redAccent
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      trans.nomClient ?? "Client Anonyme",
                                      style: TextStyle(
                                          color: trans.estPaye ? Colors.white70 : Colors.redAccent,
                                          fontWeight: trans.estPaye ? FontWeight.normal : FontWeight.bold,
                                          fontSize: 13
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // --- 3. LES MONTANTS ET BOUTONS (Trailing) ---
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${trans.montant.toInt()} F',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: estEntree ? Colors.blueAccent : const Color(0xFF00E676),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // AFFICHAGE DU BÉNÉFICE (Uniquement pour les ventes)
                                  if (!estEntree)
                                    Text(
                                      '+ ${trans.benefice.toInt()} F net',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                                    ),
                                  if (estEntree)
                                    Text(
                                      '+ ${trans.quantite} paquets',
                                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                                    ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: trans.estPaye
                                          ? const Color(0xFF00E676).withValues(alpha: 0.1)
                                          : Colors.redAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      trans.estPaye ? 'PAYÉ' : 'À CRÉDIT',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: trans.estPaye ? const Color(0xFF00E676) : Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Bouton PDF
                              if (!estEntree) ...[
                                const SizedBox(width: 5),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF4C4DDC)),
                                  tooltip: 'Exporter la facture',
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('Génération de la facture...'), duration: Duration(seconds: 1)),
                                    );
                                    await PdfService.exporterFacture(trans);
                                  },
                                ),
                              ],
                            ],
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Padding légèrement réduit pour que les 3 rentrent bien
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: couleur.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icone, color: couleur, size: 24), // Taille de l'icône ajustée
          const SizedBox(height: 6),
          Text(
            valeur,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: couleur), // Police un peu plus fine pour tenir sur une ligne
          ),
          const SizedBox(height: 4),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}