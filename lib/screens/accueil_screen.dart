import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/formats.dart';
import '../core/theme.dart';
import '../data/commande_repo.dart';
import '../data/produit_repo.dart';
import '../models/produit.dart';
import 'clients_screen.dart';
import 'validations_screen.dart';

/// Prévision de rupture pour un produit, basée sur le rythme de vente
/// des 14 derniers jours.
class PrevisionRupture {
  final Produit produit;
  final double rythmeParJour; // paquets vendus par jour (moyenne 14 j)
  final double? joursRestants; // null si aucune vente récente

  PrevisionRupture(this.produit, this.rythmeParJour)
      : joursRestants =
            rythmeParJour > 0 ? produit.quantite / rythmeParJour : null;

  /// Quantité conseillée pour tenir 7 jours de vente.
  int get quantiteConseillee {
    final besoin = (rythmeParJour * 7 - produit.quantite).ceil();
    return besoin > 0 ? besoin : 0;
  }

  bool get urgent =>
      produit.enAlerte || (joursRestants != null && joursRestants! <= 3);
  bool get aSurveiller => joursRestants != null && joursRestants! <= 7;
}

class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  final _commandeRepo = CommandeRepo();
  final _produitRepo = ProduitRepo();

  bool _isLoading = true;
  double _ventesJour = 0;
  double _encaisseJour = 0;
  double _depensesJour = 0;
  double _beneficeJour = 0;
  int _nbEnAttente = 0;
  double _totalDettes = 0;
  List<PrevisionRupture> _previsions = [];
  List<Map<String, dynamic>> _dettesAnciennes = [];

  static const _seuilRelanceJours = 15;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _isLoading = true);

    final bilan = await _commandeRepo.bilan(filtre: "Aujourd'hui");
    final enAttente = await _commandeRepo.nombreEnAttente();
    final dettes = await _commandeRepo.totalDettes();
    final produits = await _produitRepo.tous();
    final ventes14j = await _commandeRepo.quantitesVenduesParProduit(jours: 14);
    final anciennes =
        await _commandeRepo.dettesAnciennes(joursMin: _seuilRelanceJours);

    // Prévisions : produits en alerte ou dont le stock s'épuise sous 7 jours.
    final previsions = produits
        .map((p) => PrevisionRupture(p, (ventes14j[p.id] ?? 0) / 14.0))
        .where((prev) => prev.urgent || prev.aSurveiller)
        .toList()
      ..sort((a, b) => (a.joursRestants ?? double.infinity)
          .compareTo(b.joursRestants ?? double.infinity));

    if (!mounted) return;
    setState(() {
      _ventesJour = bilan['ventes'] ?? 0;
      _encaisseJour = bilan['encaisse'] ?? 0;
      _depensesJour = bilan['depenses'] ?? 0;
      _beneficeJour = bilan['benefices'] ?? 0;
      _nbEnAttente = enAttente;
      _totalDettes = dettes;
      _previsions = previsions;
      _dettesAnciennes = anciennes;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateDuJour =
        DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.fond,
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _charger),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.succes))
          : RefreshIndicator(
              onRefresh: _charger,
              color: AppColors.succes,
              backgroundColor: AppColors.carte,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    dateDuJour[0].toUpperCase() + dateDuJour.substring(1),
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 16),

                  // --- SAISIES EN ATTENTE (prioritaire si > 0) ---
                  if (_nbEnAttente > 0) ...[
                    _carteAction(
                      icone: Icons.fact_check_outlined,
                      couleur: Colors.orangeAccent,
                      titre:
                          '$_nbEnAttente saisie(s) de la secrétaire à valider',
                      sousTitre: 'Appuyez pour vérifier et valider',
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ValidationsScreen()));
                        _charger();
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- CHIFFRES DU JOUR ---
                  const Text('Aujourd\'hui',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                          child: _carteChiffre('Ventes', _ventesJour,
                              Icons.shopping_bag_outlined, AppColors.primaire)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _carteChiffre('Encaissé', _encaisseJour,
                              Icons.payments_outlined, AppColors.succes)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _carteChiffre('Dépenses', _depensesJour,
                              Icons.shopping_cart, Colors.redAccent)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _carteChiffre('Bénéfice', _beneficeJour,
                              Icons.trending_up, AppColors.succes)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // --- CASH ATTENDU EN CAISSE ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.carte,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: AppColors.succes.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.point_of_sale,
                                color: AppColors.succes, size: 22),
                            SizedBox(width: 10),
                            Text('Cash attendu en caisse ce soir',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          fmtFcfaLong(_encaisseJour - _depensesJour),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: (_encaisseJour - _depensesJour) >= 0
                                ? AppColors.succes
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- CRÉDITS EN COURS ---
                  if (_totalDettes > 0)
                    _carteAction(
                      icone: Icons.hourglass_empty,
                      couleur: Colors.redAccent,
                      titre: '${fmtFcfaLong(_totalDettes)} dehors',
                      sousTitre: 'Voir les clients qui vous doivent de l\'argent',
                      onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ClientsScreen()));
                        _charger();
                      },
                    ),
                  // --- DETTES ANCIENNES À RELANCER ---
                  if (_dettesAnciennes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Dettes à relancer',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    const Text(
                        'Crédits non réglés depuis $_seuilRelanceJours jours ou plus '
                        '— plus une dette vieillit, moins elle est payée',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 12),
                    ..._dettesAnciennes.map(_carteDetteAncienne),
                  ],
                  const SizedBox(height: 24),

                  // --- PRÉVISIONS DE RUPTURE ---
                  const Text('Ravitaillement à prévoir',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text(
                      'Basé sur votre rythme de vente des 14 derniers jours',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(height: 12),
                  if (_previsions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.carte,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: AppColors.succes),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                'Aucune rupture en vue : votre stock couvre '
                                'plus d\'une semaine de ventes.',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._previsions.map(_cartePrevision),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _carteDetteAncienne(Map<String, dynamic> dette) {
    final anciennete = (dette['anciennete'] as num?)?.toInt() ?? 0;
    final reste = (dette['reste'] as num?)?.toDouble() ?? 0;
    final nom = dette['client_nom'] as String? ?? 'Client au comptoir';
    final tresVieille = anciennete >= 30;
    final couleur = tresVieille ? Colors.redAccent : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ClientsScreen()));
          _charger();
        },
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.carte,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: couleur.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.notifications_active_outlined,
                    color: couleur, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(
                        '${dette['numero']} • depuis $anciennete jour(s)',
                        style: TextStyle(
                            color: couleur,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text(fmtFcfa(reste),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _cartePrevision(PrevisionRupture prev) {
    final couleur = prev.urgent ? Colors.redAccent : Colors.orangeAccent;
    final jours = prev.joursRestants;

    final String message;
    if (prev.produit.quantite == 0) {
      message = 'Rupture de stock !';
    } else if (jours == null) {
      message = 'Stock bas (aucune vente récente)';
    } else if (jours < 1) {
      message = 'Rupture aujourd\'hui !';
    } else {
      message = 'Rupture dans ~${jours.floor()} jour(s)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.carte,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(
                prev.urgent ? Icons.warning_amber_rounded : Icons.schedule,
                color: couleur,
                size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prev.produit.marque,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  'Stock : ${prev.produit.quantite}  •  '
                  '~${prev.rythmeParJour.toStringAsFixed(1)} pqt/jour',
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(message,
                    style: TextStyle(
                        color: couleur,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (prev.quantiteConseillee > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('À commander',
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text('${prev.quantiteConseillee} pqt',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const Text('(7 jours)',
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _carteChiffre(
      String titre, double valeur, IconData icone, Color couleur) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.carte,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 22),
          const SizedBox(height: 10),
          FittedBox(
            child: Text(fmtFcfa(valeur),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: couleur)),
          ),
          const SizedBox(height: 4),
          Text(titre,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _carteAction({
    required IconData icone,
    required Color couleur,
    required String titre,
    required String sousTitre,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: couleur.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icone, color: couleur, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: TextStyle(
                            color: couleur,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(sousTitre,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: couleur, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
