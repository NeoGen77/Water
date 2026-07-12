import 'package:flutter/material.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../data/commande_repo.dart';
import '../data/produit_repo.dart';
import '../models/commande.dart';
import '../services/backup_service.dart';
import '../services/pdf_service.dart';
import '../widgets/admin_password_dialog.dart';
import 'reports_screen.dart';
import 'validations_screen.dart';

class CaisseScreen extends StatefulWidget {
  const CaisseScreen({super.key});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends State<CaisseScreen> {
  final _repo = CommandeRepo();
  final _scrollController = ScrollController();
  final List<Commande> _commandes = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const _limit = 20;

  String _filtreActuel = 'Tout';

  double _totalVentes = 0;
  double _totalDepenses = 0;
  double _totalBenefice = 0;
  double _totalEncaisse = 0;
  double _valeurStock = 0;
  double _totalDettes = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100) {
        _chargerPlus();
      }
    });
    _initialiser();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initialiser() {
    setState(() {
      _commandes.clear();
      _offset = 0;
      _hasMore = true;
    });
    _chargerPlus();
    _chargerStatistiques();
  }

  Future<void> _chargerPlus() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final nouvelles = await _repo.historique(
        filtre: _filtreActuel, limit: _limit, offset: _offset);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (nouvelles.length < _limit) _hasMore = false;
      _commandes.addAll(nouvelles);
      _offset += _limit;
    });
  }

  Future<void> _chargerStatistiques() async {
    final bilan = await _repo.bilan(filtre: _filtreActuel);
    final stock = await ProduitRepo().valeurStock();
    final dettes = await _repo.totalDettes();
    if (!mounted) return;
    setState(() {
      _totalVentes = bilan['ventes'] ?? 0;
      _totalDepenses = bilan['depenses'] ?? 0;
      _totalBenefice = bilan['benefices'] ?? 0;
      _totalEncaisse = bilan['encaisse'] ?? 0;
      _valeurStock = stock['valeur_vente'] ?? 0;
      _totalDettes = dettes;
    });
  }

  Future<void> _annulerCommande(Commande cmd) async {
    final ok = await demanderMotDePasseAdmin(
      context,
      titre: 'Annuler la commande',
      message:
          'Vous êtes sur le point de supprimer la commande ${cmd.numero} '
          '(${fmtFcfaLong(cmd.total)}). Le stock sera corrigé automatiquement.',
      libelleBouton: 'ANNULER LA COMMANDE',
    );
    if (!ok || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.annulerCommande(cmd.id!);
      messenger.showSnackBar(const SnackBar(
          content: Text('✅ Commande annulée et stock restauré !'),
          backgroundColor: Colors.green));
      _initialiser();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('❌ Erreur lors de l\'annulation : $e'),
          backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _exporterFacture(Commande cmd) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('Génération de la facture...'),
        duration: Duration(seconds: 1)));
    final lignes = await _repo.lignesDe(cmd.id!);
    await PdfService.exporterFacture(cmd, lignes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        title: const Text('Historique & Caisse'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.security, color: AppColors.succes),
            tooltip: 'Sécurité et Sauvegardes',
            color: AppColors.carte,
            onSelected: (choix) async {
              final messenger = ScaffoldMessenger.of(context);
              if (choix == 'sauvegarder') {
                final succes = await BackupService.creerCopieLocale();
                if (succes) {
                  messenger.showSnackBar(const SnackBar(
                      content: Text('✅ Sauvegarde créée !'),
                      backgroundColor: Colors.green));
                }
              } else if (choix == 'restaurer') {
                final confirmer = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Attention',
                        style: TextStyle(color: Colors.redAccent)),
                    content: const Text(
                        'Cela remplacera toutes vos données actuelles par le '
                        'fichier de sauvegarde. Voulez-vous continuer ?',
                        style: TextStyle(color: Colors.white)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Annuler',
                              style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Restaurer'),
                      ),
                    ],
                  ),
                );
                if (confirmer == true) {
                  final succes = await BackupService.restaurerCopieLocale();
                  if (succes) {
                    messenger.showSnackBar(const SnackBar(
                        content: Text(
                            '🔄 Données restaurées ! Veuillez relancer l\'application.'),
                        backgroundColor: Colors.blueAccent));
                  }
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'sauvegarder',
                child: Row(children: [
                  Icon(Icons.download, color: AppColors.succes),
                  SizedBox(width: 10),
                  Text('Créer une sauvegarde',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
              PopupMenuItem(
                value: 'restaurer',
                child: Row(children: [
                  Icon(Icons.restore, color: Colors.orangeAccent),
                  SizedBox(width: 10),
                  Text('Restaurer une copie',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: AppColors.primaire),
            tooltip: 'Rapports Journaliers',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white54),
            tooltip: 'Filtrer par date',
            color: AppColors.carte,
            onSelected: (choix) {
              setState(() => _filtreActuel = choix);
              _initialiser();
            },
            itemBuilder: (context) =>
                ['Tout', "Aujourd'hui", 'Ce mois-ci'].map((choix) {
              final actif = _filtreActuel == choix;
              return PopupMenuItem(
                value: choix,
                child: Row(children: [
                  Icon(Icons.calendar_today,
                      size: 18,
                      color: actif ? AppColors.primaire : Colors.white54),
                  const SizedBox(width: 10),
                  Text(choix,
                      style: TextStyle(
                          color: actif ? AppColors.primaire : Colors.white,
                          fontWeight:
                              actif ? FontWeight.bold : FontWeight.normal)),
                ]),
              );
            }).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.fact_check_outlined, color: Colors.redAccent),
            tooltip: 'Saisies en attente',
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ValidationsScreen()));
              _initialiser();
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
              color: AppColors.primaire.withValues(alpha: 0.1),
              child: Text(
                'Affichage : $_filtreActuel',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.primaire,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1),
              ),
            ),

          // --- TABLEAU DE BORD ---
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.carte,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _carteTotal('Dépenses', _totalDepenses,
                            Colors.redAccent, Icons.arrow_downward)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _carteTotal('Ventes', _totalVentes,
                            AppColors.primaire, Icons.shopping_bag_outlined)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _carteTotal('Bénéfice', _totalBenefice,
                            AppColors.succes, Icons.trending_up)),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.fond,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      _ligneSolde(
                          'Encaissé (cash réel) :',
                          _totalEncaisse - _totalDepenses,
                          (_totalEncaisse - _totalDepenses) >= 0
                              ? AppColors.succes
                              : Colors.redAccent),
                      const Divider(height: 15, color: Colors.white10),
                      _ligneSolde('Crédits en cours :', _totalDettes,
                          _totalDettes > 0 ? Colors.orangeAccent : Colors.white70),
                      const Divider(height: 15, color: Colors.white10),
                      _ligneSolde('Valeur du stock :', _valeurStock,
                          AppColors.primaire),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // --- LISTE DES COMMANDES ---
          Expanded(
            child: _commandes.isEmpty && !_isLoading
                ? const Center(
                    child: Text('Aucune commande trouvée.',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12.0),
                    itemCount: _commandes.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _commandes.length) {
                        return const Center(
                            child: Padding(
                                padding: EdgeInsets.all(15.0),
                                child: CircularProgressIndicator(
                                    color: AppColors.succes)));
                      }
                      return _carteCommande(_commandes[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _ligneSolde(String libelle, double montant, Color couleur) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(libelle,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white70)),
        Text(fmtFcfaLong(montant),
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: couleur)),
      ],
    );
  }

  Widget _carteCommande(Commande cmd) {
    final estEntree = !cmd.estVente;
    final couleur = estEntree ? Colors.blueAccent : AppColors.succes;

    final String badge;
    final Color couleurBadge;
    if (estEntree || cmd.estSoldee) {
      badge = 'PAYÉ';
      couleurBadge = AppColors.succes;
    } else if (cmd.totalPaye > 0) {
      badge = 'PARTIEL';
      couleurBadge = Colors.orangeAccent;
    } else {
      badge = 'À CRÉDIT';
      couleurBadge = Colors.redAccent;
    }

    return Card(
      color: AppColors.carte,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onLongPress: () => _annulerCommande(cmd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: couleur.withValues(alpha: 0.15),
                child: Icon(
                    estEntree ? Icons.arrow_downward : Icons.arrow_upward,
                    color: couleur),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cmd.numero,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(fmtDate(cmd.date),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person,
                            size: 14,
                            color: cmd.estSoldee
                                ? Colors.white54
                                : Colors.redAccent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            cmd.clientNom ?? 'Client au comptoir',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: cmd.estSoldee
                                    ? Colors.white70
                                    : Colors.redAccent,
                                fontWeight: cmd.estSoldee
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtFcfa(cmd.total),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: couleur)),
                  const SizedBox(height: 2),
                  if (!estEntree)
                    Text('+ ${fmtFcfa(cmd.benefice)} net',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70)),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: couleurBadge.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: couleurBadge)),
                  ),
                ],
              ),
              if (!estEntree)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf,
                      color: AppColors.primaire),
                  tooltip: 'Exporter la facture',
                  onPressed: () => _exporterFacture(cmd),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteTotal(String titre, double valeur, Color couleur, IconData icone) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: couleur.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Icon(icone, color: couleur, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(fmtFcfa(valeur),
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: couleur)),
          ),
          const SizedBox(height: 4),
          Text(titre,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
