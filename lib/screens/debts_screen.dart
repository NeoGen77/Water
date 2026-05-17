import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_item.dart';
import '../services/pdf_service.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  late Future<List<TransactionItem>> _dettesFuture;

  @override
  void initState() {
    super.initState();
    _chargerDettes();
  }

  void _chargerDettes() {
    setState(() {
      _dettesFuture = DBHelper().getToutesLesDettes();
    });
  }

  // Fonction pour solder une dette précise
  void _solderDette(TransactionItem dette) async {
    final messenger = ScaffoldMessenger.of(context);

    await DBHelper().solderDette(dette.id!);
    _chargerDettes(); // Rafraîchir la liste

    messenger.showSnackBar(
      SnackBar(
        content: Text('✅ Paiement de ${dette.montant.toInt()} F encaissé !'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // --- LOGIQUE DE REGROUPEMENT PAR CLIENT ---
  Map<String, List<TransactionItem>> _grouperParClient(List<TransactionItem> dettes) {
    Map<String, List<TransactionItem>> dettesParClient = {};
    for (var dette in dettes) {
      String nom = dette.nomClient ?? "Client Anonyme";
      if (!dettesParClient.containsKey(nom)) {
        dettesParClient[nom] = [];
      }
      dettesParClient[nom]!.add(dette);
    }
    return dettesParClient;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Suivi des Crédits', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
      ),
      body: FutureBuilder<List<TransactionItem>>(
        future: _dettesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.thumb_up_alt_outlined, size: 80, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(height: 20),
                  const Text('Excellente nouvelle !', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('Aucun client ne vous doit de l\'argent.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                ],
              ),
            );
          }

          final dettesNonGroupees = snapshot.data!;

          // Calcul du total global dehors
          double totalDehors = 0;
          for (var d in dettesNonGroupees) {
            totalDehors += d.montant;
          }

          // On regroupe les dettes par nom de client
          final dettesParClient = _grouperParClient(dettesNonGroupees);

          return Column(
            children: [
              // --- EN-TÊTE : TOTAL DE L'ARGENT DEHORS ---
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.redAccent.withValues(alpha: 0.2), const Color(0xFF0A0E21)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.money_off, color: Colors.redAccent, size: 30),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total des impayés', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(
                            '${totalDehors.toInt()} FCFA',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text("DÉTAIL PAR CLIENT", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),

              // --- LISTE DES CLIENTS ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: dettesParClient.keys.length,
                  itemBuilder: (context, index) {
                    String nomClient = dettesParClient.keys.elementAt(index);
                    List<TransactionItem> dettesDuClient = dettesParClient[nomClient]!;

                    // Calcul du total pour ce client
                    double totalClient = 0;
                    for (var d in dettesDuClient) {
                      totalClient += d.montant;
                    }

                    return Card(
                      color: const Color(0xFF1D1E33),
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      // On utilise ExpansionTile pour pouvoir dérouler et voir le détail
                      child: ExpansionTile(
                        iconColor: Colors.white,
                        collapsedIconColor: Colors.white54,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                nomClient,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${totalClient.toInt()} F',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16),
                            ),
                          ],
                        ),
                        subtitle: Text('${dettesDuClient.length} opération(s) en attente', style: const TextStyle(color: Colors.white54, fontSize: 12)),

                        // --- LES DÉTAILS DÉROULANTS ---
                        children: [
                          const Divider(color: Colors.white10, height: 1),

                          // BOUTON GÉNÉRER LE RELEVÉ PDF
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4C4DDC).withValues(alpha: 0.1),
                                    foregroundColor: const Color(0xFF4C4DDC),
                                    elevation: 0,
                                    side: const BorderSide(color: Color(0xFF4C4DDC)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                                ),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text("Envoyer le relevé de compte au client", style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Génération du relevé en cours...'), duration: Duration(seconds: 1)),
                                  );
                                  // APPEL MAGIQUE VERS TON NOUVEAU SERVICE PDF
                                  await PdfService.exporterReleveClient(nomClient, dettesDuClient);
                                },
                              ),
                            ),
                          ),

                          // LISTE DES FACTURES INDIVIDUELLES
                          ...dettesDuClient.map((dette) {
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.orangeAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8)
                                ),
                                child: const Icon(Icons.hourglass_empty, color: Colors.orangeAccent, size: 20),
                              ),
                              title: Text('${dette.marque} (${dette.quantite} pqt)', style: const TextStyle(color: Colors.white, fontSize: 14)),
                              subtitle: Text(dette.date, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${dette.montant.toInt()} F', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 10),
                                  // BOUTON ENCAISSER
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: Color(0xFF00E676)),
                                    tooltip: 'Marquer comme payé',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: const Color(0xFF1D1E33),
                                          title: const Text('Encaisser cette dette ?', style: TextStyle(color: Colors.white)),
                                          content: Text('Confirmez-vous avoir reçu ${dette.montant.toInt()} F pour cette vente de ${dette.marque} ?', style: const TextStyle(color: Colors.white70)),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676), foregroundColor: Colors.black),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                _solderDette(dette);
                                              },
                                              child: const Text('Oui, Encaisser', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                        ],
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
}