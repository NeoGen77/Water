import 'package:flutter/material.dart';
import '../database/db_helper.dart';

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
    _chargerRapports();
  }

  void _chargerRapports() {
    setState(() {
      _rapports = DBHelper().getRapportsJournaliersAutomatiques();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // Fond Dark
      appBar: AppBar(
        title: const Text('Rapports & Bénéfices', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rapports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_chart_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 20),
                  const Text('Aucune donnée enregistrée.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            );
          }

          final jours = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jours.length,
            itemBuilder: (context, index) {
              final jourDonnees = jours[index];

              String date = jourDonnees['jour'];
              double recettes = (jourDonnees['recettes'] as num?)?.toDouble() ?? 0.0;
              double depenses = (jourDonnees['depenses'] as num?)?.toDouble() ?? 0.0;
              double credits = (jourDonnees['credits'] as num?)?.toDouble() ?? 0.0;

              // NOUVEAU : Récupération du vrai bénéfice
              double beneficeNet = (jourDonnees['benefice_net'] as num?)?.toDouble() ?? 0.0;

              int operations = jourDonnees['nombre_operations'] as int;

              // Cash en caisse (Flux de trésorerie)
              double soldeCaisse = recettes - depenses;

              return Card(
                color: const Color(0xFF1D1E33),
                elevation: 8,
                shadowColor: Colors.black45,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- EN-TÊTE ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4C4DDC).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.calendar_today, color: Color(0xFF4C4DDC), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                date,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)
                            ),
                            child: Text('$operations actions', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                          )
                        ],
                      ),
                      const Divider(height: 30, color: Colors.white10),

                      // --- CORPS : FLUX DE TRÉSORERIE ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLigneChiffre('Recettes', recettes, Colors.greenAccent, Icons.arrow_downward),
                              const SizedBox(height: 8),
                              _buildLigneChiffre('Dépenses', depenses, Colors.redAccent, Icons.arrow_upward),
                              const SizedBox(height: 8),
                              _buildLigneChiffre('Crédits', credits, Colors.orangeAccent, Icons.hourglass_empty),
                            ],
                          ),

                          // Pastille du Solde Caisse (Liquidité)
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0E21),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: [
                                const Text('Cash en Caisse', style: TextStyle(fontSize: 11, color: Colors.white54)),
                                const SizedBox(height: 5),
                                Text(
                                  '${soldeCaisse >= 0 ? "+" : ""}${soldeCaisse.toInt()} F',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: soldeCaisse >= 0 ? Colors.white : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 20),

                      // --- NOUVEAU : LE VRAI BÉNÉFICE NET ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF00E676).withValues(alpha: 0.2),
                              const Color(0xFF00E676).withValues(alpha: 0.05)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.trending_up, color: Color(0xFF00E676), size: 20),
                                SizedBox(width: 8),
                                Text('BÉNÉFICE NET', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),
                            Text(
                              '+ ${beneficeNet.toInt()} F',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                            ),
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

  // Petit widget pour afficher une ligne de chiffre propre
  Widget _buildLigneChiffre(String titre, double montant, Color couleur, IconData icone) {
    return Row(
      children: [
        Icon(icone, size: 14, color: couleur),
        const SizedBox(width: 6),
        Text('$titre : ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text('${montant.toInt()} F', style: TextStyle(fontWeight: FontWeight.bold, color: couleur, fontSize: 14)),
      ],
    );
  }
}