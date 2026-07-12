import 'package:flutter/material.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../data/commande_repo.dart';
import '../services/export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<Map<String, dynamic>>> _rapports;

  @override
  void initState() {
    super.initState();
    _rapports = CommandeRepo().rapportsJournaliers();
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
        title: const Text('Rapports & Bénéfices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view, color: AppColors.succes),
            tooltip: 'Exporter en Excel',
            onPressed: _exporterExcel,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rapports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.succes));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_chart_outlined,
                      size: 80, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 20),
                  const Text('Aucune donnée enregistrée.',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            );
          }

          final jours = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jours.length,
            itemBuilder: (context, index) {
              final jour = jours[index];
              final date = jour['jour'] as String;
              final ventes = (jour['ventes'] as num?)?.toDouble() ?? 0.0;
              final depenses = (jour['depenses'] as num?)?.toDouble() ?? 0.0;
              final encaisse = (jour['encaisse'] as num?)?.toDouble() ?? 0.0;
              final benefice = (jour['benefice'] as num?)?.toDouble() ?? 0.0;
              final operations = (jour['operations'] as num?)?.toInt() ?? 0;
              final cash = encaisse - depenses;

              return Card(
                color: AppColors.carte,
                elevation: 8,
                shadowColor: Colors.black45,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaire
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.calendar_today,
                                    color: AppColors.primaire, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(date,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text('$operations commande(s)',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.white70)),
                          )
                        ],
                      ),
                      const Divider(height: 30, color: Colors.white10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ligne('Ventes', ventes, AppColors.primaire,
                                  Icons.shopping_bag_outlined),
                              const SizedBox(height: 8),
                              _ligne('Dépenses', depenses, Colors.redAccent,
                                  Icons.shopping_cart),
                              const SizedBox(height: 8),
                              _ligne('Encaissé', encaisse, Colors.orangeAccent,
                                  Icons.payments_outlined),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: AppColors.fond,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: [
                                const Text('Cash en Caisse',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white54)),
                                const SizedBox(height: 5),
                                Text(
                                  '${cash >= 0 ? "+" : ""}${fmtFcfa(cash)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cash >= 0
                                        ? Colors.white
                                        : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.succes.withValues(alpha: 0.2),
                            AppColors.succes.withValues(alpha: 0.05)
                          ]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.succes.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up,
                                    color: AppColors.succes, size: 20),
                                SizedBox(width: 8),
                                Text('BÉNÉFICE NET',
                                    style: TextStyle(
                                        color: AppColors.succes,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                              ],
                            ),
                            Text('+ ${fmtFcfa(benefice)}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.succes)),
                          ],
                        ),
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

  Widget _ligne(String titre, double montant, Color couleur, IconData icone) {
    return Row(
      children: [
        Icon(icone, size: 14, color: couleur),
        const SizedBox(width: 6),
        Text('$titre : ',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(fmtFcfa(montant),
            style: TextStyle(
                fontWeight: FontWeight.bold, color: couleur, fontSize: 14)),
      ],
    );
  }
}
