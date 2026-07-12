import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../data/commande_repo.dart';
import '../data/produit_repo.dart';
import '../services/export_service.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String _filtreActuel = 'Ce mois-ci';

  double _totalVentes = 0;
  double _totalDepenses = 0;
  double _totalBenefice = 0;
  double _totalEncaisse = 0;
  double _valeurStock = 0;
  double _totalDettes = 0;
  List<Map<String, dynamic>> _topVentes = [];
  List<Map<String, dynamic>> _serieJours = []; // 14 derniers jours

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _isLoading = true);

    final repo = CommandeRepo();
    final bilan = await repo.bilan(filtre: _filtreActuel);
    final top = await repo.topVentes(filtre: _filtreActuel);
    final stock = await ProduitRepo().valeurStock();
    final dettes = await repo.totalDettes();
    final jours = await repo.rapportsJournaliers(limitJours: 14);

    if (!mounted) return;
    setState(() {
      _totalVentes = bilan['ventes'] ?? 0;
      _totalDepenses = bilan['depenses'] ?? 0;
      _totalBenefice = bilan['benefices'] ?? 0;
      _totalEncaisse = bilan['encaisse'] ?? 0;
      _valeurStock = stock['valeur_vente'] ?? 0;
      _totalDettes = dettes;
      _topVentes = top.take(5).toList();
      _serieJours = jours.reversed.toList(); // chronologique
      _isLoading = false;
    });
  }

  Future<void> _exporterExcel() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('Préparation du rapport Excel...'),
        duration: Duration(seconds: 1)));
    final chemin = await ExportService.exporterRapportExcel();
    messenger.showSnackBar(
      chemin != null
          ? SnackBar(
              content: Text('✅ Rapport Excel créé : $chemin'),
              backgroundColor: Colors.green)
          : const SnackBar(
              content: Text('Export annulé ou impossible.'),
              backgroundColor: Colors.orangeAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        title: const Text('Direction Financière'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view, color: AppColors.succes),
            tooltip: 'Exporter en Excel',
            onPressed: _exporterExcel,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range, color: AppColors.succes),
            tooltip: 'Période',
            color: AppColors.carte,
            onSelected: (choix) {
              setState(() => _filtreActuel = choix);
              _charger();
            },
            itemBuilder: (context) =>
                ['Tout', "Aujourd'hui", 'Ce mois-ci'].map((choix) {
              return PopupMenuItem(
                value: choix,
                child: Text(choix,
                    style: TextStyle(
                        color: _filtreActuel == choix
                            ? AppColors.succes
                            : Colors.white,
                        fontWeight: _filtreActuel == choix
                            ? FontWeight.bold
                            : FontWeight.normal)),
              );
            }).toList(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.succes))
          : RefreshIndicator(
              onRefresh: _charger,
              color: AppColors.succes,
              backgroundColor: AppColors.carte,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Période : $_filtreActuel',
                        style: const TextStyle(
                            color: AppColors.primaire,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1)),
                    const SizedBox(height: 20),

                    // --- BLOC BÉNÉFICE ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.succes.withValues(alpha: 0.2),
                            AppColors.fond
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: AppColors.succes.withValues(alpha: 0.5),
                            width: 1.5),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.insights,
                                  color: AppColors.succes, size: 28),
                              SizedBox(width: 10),
                              Text('BÉNÉFICE NET',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 2)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          FittedBox(
                            child: Text('+ ${fmtFcfaLong(_totalBenefice)}',
                                style: const TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.succes)),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              'Marge pure après déduction des prix d\'achat',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white54)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // --- CA / DÉPENSES ---
                    Row(
                      children: [
                        Expanded(
                            child: _carteMetrique(
                                'Chiffre d\'Affaires',
                                fmtFcfa(_totalVentes),
                                Icons.account_balance_wallet,
                                AppColors.primaire)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: _carteMetrique(
                                'Dépenses (Achat)',
                                fmtFcfa(_totalDepenses),
                                Icons.shopping_cart,
                                Colors.redAccent)),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // --- GRAPHIQUE 14 DERNIERS JOURS ---
                    const Text('Évolution (14 derniers jours)',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 15),
                    Container(
                      height: 220,
                      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                      decoration: BoxDecoration(
                        color: AppColors.carte,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: _serieJours.isEmpty
                          ? const Center(
                              child: Text('Pas encore de données.',
                                  style: TextStyle(color: Colors.white38)))
                          : _graphiqueVentes(),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Legende(couleur: AppColors.primaire, texte: 'Ventes'),
                        SizedBox(width: 20),
                        _Legende(couleur: AppColors.succes, texte: 'Bénéfice'),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // --- TOP VENTES ---
                    const Text('Top 5 des produits vendus',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 15),
                    if (_topVentes.isEmpty)
                      const Text('Aucune vente sur cette période.',
                          style: TextStyle(color: Colors.white38))
                    else
                      ..._topVentes.asMap().entries.map((entree) {
                        final rang = entree.key + 1;
                        final ligne = entree.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _tuile(
                            '$rang. ${ligne['marque']}',
                            '${ligne['quantite']} paquets  •  '
                                '+${fmtFcfa((ligne['benefice'] as num?)?.toDouble() ?? 0)} net',
                            rang == 1 ? Icons.star : Icons.water_drop,
                            rang == 1
                                ? Colors.orangeAccent
                                : AppColors.primaire,
                          ),
                        );
                      }),
                    const SizedBox(height: 25),

                    // --- INDICATEURS ---
                    const Text('Indicateurs Stratégiques',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 15),
                    _tuile('Trésorerie réelle (encaissé - dépenses)',
                        fmtFcfaLong(_totalEncaisse - _totalDepenses),
                        Icons.payments,
                        (_totalEncaisse - _totalDepenses) >= 0
                            ? AppColors.succes
                            : Colors.redAccent),
                    const SizedBox(height: 10),
                    _tuile('Crédits en cours (argent dehors)',
                        fmtFcfaLong(_totalDettes), Icons.hourglass_empty,
                        _totalDettes > 0 ? Colors.orangeAccent : AppColors.succes),
                    const SizedBox(height: 10),
                    _tuile('Valeur du stock dormant', fmtFcfaLong(_valeurStock),
                        Icons.inventory_2, Colors.blueAccent),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _graphiqueVentes() {
    final maxY = _serieJours.fold<double>(
        0,
        (max, j) =>
            ((j['ventes'] as num?)?.toDouble() ?? 0) > max
                ? (j['ventes'] as num).toDouble()
                : max);

    return BarChart(
      BarChartData(
        maxY: maxY == 0 ? 10 : maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: Colors.white10, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.fond,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final jour = _serieJours[group.x];
              return BarTooltipItem(
                '${jour['jour']}\n'
                'Ventes : ${fmtFcfa((jour['ventes'] as num?)?.toDouble() ?? 0)}\n'
                'Bénéfice : ${fmtFcfa((jour['benefice'] as num?)?.toDouble() ?? 0)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                NumberFormat.compact(locale: 'fr').format(value),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _serieJours.length) {
                  return const SizedBox.shrink();
                }
                final jour = _serieJours[index]['jour'] as String;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(jour.substring(8), // le jour du mois
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        barGroups: _serieJours.asMap().entries.map((entree) {
          final index = entree.key;
          final jour = entree.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (jour['ventes'] as num?)?.toDouble() ?? 0,
                color: AppColors.primaire,
                width: 6,
                borderRadius: BorderRadius.circular(2),
              ),
              BarChartRodData(
                toY: (jour['benefice'] as num?)?.toDouble() ?? 0,
                color: AppColors.succes,
                width: 6,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _carteMetrique(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.carte,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 15),
          FittedBox(
            child: Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 5),
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _tuile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.carte,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
              child: Text(title,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 14))),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  final Color couleur;
  final String texte;

  const _Legende({required this.couleur, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(texte,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
