import 'package:flutter/material.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../data/commande_repo.dart';
import '../models/commande.dart';

/// Validation par l'admin des saisies faites par la secrétaire.
class ValidationsScreen extends StatefulWidget {
  const ValidationsScreen({super.key});

  @override
  State<ValidationsScreen> createState() => _ValidationsScreenState();
}

class _ValidationsScreenState extends State<ValidationsScreen> {
  final _repo = CommandeRepo();
  late Future<List<Commande>> _enAttente;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  void _charger() {
    final futur = _repo.enAttente();
    setState(() {
      _enAttente = futur;
    });
  }

  Future<void> _approuver(Commande cmd) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.validerCommande(cmd.id!);
      _charger();
      messenger.showSnackBar(const SnackBar(
          content: Text('✅ Commande validée ! Stock mis à jour.'),
          backgroundColor: Colors.green));
    } on StateError catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Validation impossible',
              style: TextStyle(color: Colors.redAccent)),
          content:
              Text(e.message, style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compris')),
          ],
        ),
      );
    }
  }

  Future<void> _rejeter(Commande cmd) async {
    final messenger = ScaffoldMessenger.of(context);
    await _repo.rejeterCommande(cmd.id!);
    _charger();
    messenger.showSnackBar(const SnackBar(
        content: Text('❌ Commande rejetée et supprimée.'),
        backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification Secrétaire')),
      body: FutureBuilder<List<Commande>>(
        future: _enAttente,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 80, color: AppColors.succes),
                  const SizedBox(height: 20),
                  Text('Tout est à jour !',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Text('Aucune saisie en attente.',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          final commandes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: commandes.length,
            itemBuilder: (context, index) => _carteCommande(commandes[index]),
          );
        },
      ),
    );
  }

  Widget _carteCommande(Commande cmd) {
    final estEntree = !cmd.estVente;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.orangeAccent, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: estEntree
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                      child: Icon(estEntree ? Icons.download : Icons.upload,
                          color: estEntree ? Colors.blue : Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cmd.numero,
                            style: Theme.of(context).textTheme.bodyLarge),
                        Text(fmtDate(cmd.date),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtFcfa(cmd.total),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orangeAccent)),
                    if (!estEntree)
                      Text('+ ${fmtFcfa(cmd.benefice)} net',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.succes)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Détail des lignes du panier
            FutureBuilder<List<LigneCommande>>(
              future: _repo.lignesDe(cmd.id!),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                return Column(
                  children: snapshot.data!
                      .map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('📦 ${l.marque} x${l.quantite}',
                                    style: const TextStyle(
                                        color: Colors.white70)),
                                Text(fmtFcfa(l.montant),
                                    style: const TextStyle(
                                        color: Colors.white54)),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (cmd.clientNom != null)
                  Expanded(
                    child: Text('👤 ${cmd.clientNom}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  )
                else
                  const SizedBox.shrink(),
                if (cmd.estVente)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cmd.intentionPaye
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      cmd.intentionPaye ? 'COMPTANT' : 'À CRÉDIT',
                      style: TextStyle(
                          color: cmd.intentionPaye
                              ? Colors.green
                              : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const Divider(height: 30, color: Colors.white10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    onPressed: () => _rejeter(cmd),
                    icon: const Icon(Icons.close),
                    label: const Text('REJETER'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.succes,
                      foregroundColor: Colors.black,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _approuver(cmd),
                    icon: const Icon(Icons.check),
                    label: const Text('VALIDER'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
