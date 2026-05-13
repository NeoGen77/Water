import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/transaction_item.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  late Future<List<TransactionItem>> _dettes;
  double _totalDettes = 0;

  @override
  void initState() {
    super.initState();
    _chargerDettes();
  }

  void _chargerDettes() {
    setState(() {
      _dettes = DBHelper().getToutesLesDettes().then((liste) {
        double total = 0;
        for (var item in liste) {
          total += item.montant;
        }
        setState(() {
          _totalDettes = total;
        });
        return liste;
      });
    });
  }

  void _confirmerPaiement(TransactionItem dette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Encaisser la dette', style: TextStyle(color: Colors.green)),
        content: Text(
            'Confirmez-vous que le client "${dette.nomClient}" a bien réglé sa facture de ${dette.montant.toInt()} FCFA (Date: ${dette.date}) ?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check_circle),
            label: const Text('Oui, encaisser'),
            onPressed: () async {
              await DBHelper().solderDette(dette.id!);
              if (mounted) Navigator.pop(ctx);
              _chargerDettes();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Dette de ${dette.nomClient} réglée avec succès !'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des Crédits'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- BANDEAU TOTAL DES IMPAYÉS ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.redAccent, Colors.red.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ]
            ),
            child: Column(
              children: [
                const Text(
                  'TOTAL ARGENT DEHORS',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_totalDettes.toInt()} FCFA',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // --- LISTE DES CLIENTS QUI DOIVENT DE L'ARGENT ---
          Expanded(
            child: FutureBuilder<List<TransactionItem>>(
              future: _dettes,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                          SizedBox(height: 16),
                          Text('Excellente nouvelle !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Aucun crédit client en cours.', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                  );
                }

                final dettes = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: dettes.length,
                  itemBuilder: (context, index) {
                    final dette = dettes[index];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          radius: 25,
                          child: const Icon(Icons.person, color: Colors.redAccent, size: 30),
                        ),
                        title: Text(
                          dette.nomClient ?? "Anonyme",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text('${dette.quantite} paquets de ${dette.marque}'),
                            Text('Date: ${dette.date}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        // CORRECTION ICI : FittedBox + MainAxisSize.min
                        trailing: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min, // <-- Empêche l'overflow vertical
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${dette.montant.toInt()} F',
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4), // J'ai un peu réduit l'espace pour que ce soit plus joli
                              SizedBox(
                                height: 30,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  onPressed: () => _confirmerPaiement(dette),
                                  child: const Text('Encaisser', style: TextStyle(fontSize: 12)),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}