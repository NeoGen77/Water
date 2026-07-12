import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../data/client_repo.dart';
import '../data/commande_repo.dart';
import '../models/commande.dart';
import '../services/pdf_service.dart';

/// Suivi des clients et de leurs crédits, avec paiements partiels.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _clientRepo = ClientRepo();
  final _commandeRepo = CommandeRepo();

  List<Map<String, dynamic>> _clientsEndettes = [];
  double _totalDehors = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _isLoading = true);
    final clients = await _clientRepo.clientsAvecDettes();
    double total = 0;
    for (final c in clients) {
      total += (c['dette'] as num).toDouble();
    }
    if (!mounted) return;
    setState(() {
      _clientsEndettes = clients;
      _totalDehors = total;
      _isLoading = false;
    });
  }

  // --- ENCAISSEMENT (total ou partiel) ---
  Future<void> _encaisser(Commande dette) async {
    final controller =
        TextEditingController(text: dette.resteAPayer.toInt().toString());
    String erreur = '';

    final montant = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Encaisser un paiement',
              style: TextStyle(color: Colors.white, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Facture ${dette.numero}\n'
                  'Reste à payer : ${fmtFcfaLong(dette.resteAPayer)}',
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 15),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Montant reçu',
                  prefixText: 'FCFA ',
                  errorText: erreur.isEmpty ? null : erreur,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Astuce : saisissez un montant plus petit pour un paiement partiel.',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.succes,
                  foregroundColor: Colors.black),
              onPressed: () {
                final saisi = double.tryParse(controller.text) ?? 0;
                if (saisi <= 0) {
                  setStateDialog(() => erreur = 'Montant invalide.');
                  return;
                }
                if (saisi > dette.resteAPayer + 0.001) {
                  setStateDialog(() =>
                      erreur = 'Le montant dépasse le reste à payer.');
                  return;
                }
                Navigator.pop(ctx, saisi);
              },
              child: const Text('ENCAISSER',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (montant == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _commandeRepo.encaisser(dette.id!, montant);
      messenger.showSnackBar(SnackBar(
          content: Text('✅ Paiement de ${fmtFcfa(montant)} encaissé !'),
          backgroundColor: Colors.green));
      _charger();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('❌ $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _exporterReleve(String nomClient, int clientId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
        content: Text('Génération du relevé en cours...'),
        duration: Duration(seconds: 1)));
    final dettes = await _commandeRepo.dettesDuClient(clientId);
    await PdfService.exporterReleveClient(nomClient, dettes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        title: const Text('Clients & Crédits'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _charger),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.redAccent))
          : _clientsEndettes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.thumb_up_alt_outlined,
                          size: 80, color: Colors.white.withValues(alpha: 0.2)),
                      const SizedBox(height: 20),
                      const Text('Excellente nouvelle !',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      const Text('Aucun client ne vous doit de l\'argent.',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 16)),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // --- TOTAL DES IMPAYÉS ---
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent.withValues(alpha: 0.2),
                            AppColors.fond
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.money_off,
                                color: Colors.redAccent, size: 30),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total des impayés',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 14)),
                                Text(fmtFcfaLong(_totalDehors),
                                    style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text('DÉTAIL PAR CLIENT',
                            style: TextStyle(
                                color: Colors.white38,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _clientsEndettes.length,
                        itemBuilder: (context, index) {
                          final client = _clientsEndettes[index];
                          return _carteClient(client);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _carteClient(Map<String, dynamic> client) {
    final clientId = client['id'] as int;
    final nom = client['nom'] as String;
    final dette = (client['dette'] as num).toDouble();
    final nb = (client['nb_commandes'] as num).toInt();

    return Card(
      color: AppColors.carte,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ExpansionTile(
        iconColor: Colors.white,
        collapsedIconColor: Colors.white54,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(nom,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(fmtFcfa(dette),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 16)),
          ],
        ),
        subtitle: Text('$nb facture(s) en cours',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        children: [
          const Divider(color: Colors.white10, height: 1),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.primaire.withValues(alpha: 0.1),
                    foregroundColor: AppColors.primaire,
                    elevation: 0,
                    side: const BorderSide(color: AppColors.primaire),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Relevé de compte PDF',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _exporterReleve(nom, clientId),
              ),
            ),
          ),
          FutureBuilder<List<Commande>>(
            future: _commandeRepo.dettesDuClient(clientId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(15.0),
                  child: CircularProgressIndicator(color: AppColors.succes),
                );
              }
              return Column(
                children: snapshot.data!.map((detteCommande) {
                  final partiel = detteCommande.totalPaye > 0;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 5),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(
                          partiel ? Icons.hourglass_bottom : Icons.hourglass_empty,
                          color: Colors.orangeAccent,
                          size: 20),
                    ),
                    title: Text(detteCommande.numero,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    subtitle: Text(
                        '${fmtDateCourte(detteCommande.date)}'
                        '${partiel ? '  •  déjà réglé : ${fmtFcfa(detteCommande.totalPaye)}' : ''}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(fmtFcfa(detteCommande.resteAPayer),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.payments_outlined,
                              color: AppColors.succes),
                          tooltip: 'Encaisser (total ou partiel)',
                          onPressed: () => _encaisser(detteCommande),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
