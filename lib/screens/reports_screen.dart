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
      appBar: AppBar(
        title: const Text('Archives Journalières'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade100,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _rapports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('Aucune donnée enregistrée pour le moment.',
                    style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          final jours = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: jours.length,
            itemBuilder: (context, index) {
              final jourDonnees = jours[index];

              String date = jourDonnees['jour'];
              double recettes = (jourDonnees['recettes'] as num?)?.toDouble() ?? 0.0;
              double depenses = (jourDonnees['depenses'] as num?)?.toDouble() ?? 0.0;
              double credits = (jourDonnees['credits'] as num?)?.toDouble() ?? 0.0;
              int operations = jourDonnees['nombre_operations'] as int;

              double benefice = recettes - depenses;
              bool estPositif = benefice >= 0;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête : Date et Nombre d'opérations
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.indigo, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                date,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)),
                            child: Text('$operations actions', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          )
                        ],
                      ),
                      const Divider(height: 25),

                      // Corps : Les chiffres
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLigneChiffre('Recettes (+)', recettes, Colors.green),
                              const SizedBox(height: 5),
                              _buildLigneChiffre('Dépenses (-)', depenses, Colors.redAccent),
                              if (credits > 0) ...[
                                const SizedBox(height: 5),
                                _buildLigneChiffre('Crédits dehors', credits, Colors.orange),
                              ]
                            ],
                          ),

                          // Pastille du Bénéfice (Solde)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: estPositif ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: estPositif ? Colors.green.shade200 : Colors.red.shade200),
                            ),
                            child: Column(
                              children: [
                                Text('Solde Net', style: TextStyle(fontSize: 12, color: estPositif ? Colors.green.shade700 : Colors.red.shade700)),
                                const SizedBox(height: 4),
                                Text(
                                  '${estPositif ? "+" : ""}${benefice.toInt()} F',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: estPositif ? Colors.green : Colors.red
                                  ),
                                ),
                              ],
                            ),
                          )
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

  // Petit widget pour afficher une ligne de chiffre propre
  Widget _buildLigneChiffre(String titre, double montant, Color couleur) {
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: couleur),
        const SizedBox(width: 8),
        Text('$titre : ', style: const TextStyle(color: Colors.black87)),
        Text('${montant.toInt()} F', style: TextStyle(fontWeight: FontWeight.bold, color: couleur)),
      ],
    );
  }
}