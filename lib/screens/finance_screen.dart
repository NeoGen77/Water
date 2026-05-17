import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/water_item.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String _filtreActuel = 'Ce mois-ci'; // Par défaut, on regarde le mois

  double _totalVentes = 0;
  double _totalDepenses = 0;
  double _totalBenefice = 0;

  String _produitPhare = "...";
  double _valeurStock = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerDonneesFinancieres();
  }

  void _chargerDonneesFinancieres() async {
    setState(() => _isLoading = true);

    // 1. Récupération des finances
    final bilan = await DBHelper().getBilanFinancier(filter: _filtreActuel);

    // 2. Récupération du top vente
    final top = await DBHelper().getTopSellingProduct();

    // 3. Récupération de la valeur du stock dormant
    final items = await DBHelper().getAllItems();
    double totalStock = 0;
    for (WaterItem item in items) {
      totalStock += item.quantite * item.prixVente;
    }

    if (mounted) {
      setState(() {
        _totalVentes = bilan['ventes'] ?? 0;
        _totalDepenses = bilan['depenses'] ?? 0;
        _totalBenefice = bilan['benefices'] ?? 0;
        _produitPhare = top;
        _valeurStock = totalStock;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Direction Financière', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0A0E21),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range, color: Color(0xFF00E676)),
            tooltip: 'Période',
            color: const Color(0xFF1D1E33),
            onSelected: (String choix) {
              setState(() => _filtreActuel = choix);
              _chargerDonneesFinancieres();
            },
            itemBuilder: (BuildContext context) {
              return ['Tout', 'Aujourd\'hui', 'Ce mois-ci'].map((String choix) {
                return PopupMenuItem<String>(
                  value: choix,
                  child: Text(
                      choix,
                      style: TextStyle(
                          color: _filtreActuel == choix ? const Color(0xFF00E676) : Colors.white,
                          fontWeight: _filtreActuel == choix ? FontWeight.bold : FontWeight.normal
                      )
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : RefreshIndicator(
        onRefresh: () async => _chargerDonneesFinancieres(),
        color: const Color(0xFF00E676),
        backgroundColor: const Color(0xFF1D1E33),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Période : $_filtreActuel',
                style: const TextStyle(color: Color(0xFF4C4DDC), fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
              ),
              const SizedBox(height: 20),

              // --- LE GROS BLOC BÉNÉFICE ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF00E676).withValues(alpha: 0.2), const Color(0xFF0A0E21)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2)
                    ]
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insights, color: Color(0xFF00E676), size: 28),
                        SizedBox(width: 10),
                        Text("BÉNÉFICE NET", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      '+ ${_totalBenefice.toInt()} FCFA',
                      style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                    ),
                    const SizedBox(height: 8),
                    const Text("Marge pure après déduction des prix d'achat", style: TextStyle(fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- CHIFFRES D'AFFAIRES ET DÉPENSES ---
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard("Chiffre d'Affaires", '${_totalVentes.toInt()} F', Icons.account_balance_wallet, const Color(0xFF4C4DDC)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildMetricCard("Dépenses (Achat)", '${_totalDepenses.toInt()} F', Icons.shopping_cart, Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // --- AUTRES INDICATEURS CLÉS ---
              const Text("Indicateurs Stratégiques", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 15),

              _buildListTile(
                  "Produit le plus rentable",
                  _produitPhare,
                  Icons.star,
                  Colors.orangeAccent
              ),
              const SizedBox(height: 10),
              _buildListTile(
                  "Valeur du stock dormant",
                  '${_valeurStock.toInt()} FCFA',
                  Icons.inventory_2,
                  Colors.blueAccent
              ),
              const SizedBox(height: 10),
              _buildListTile(
                  "Trésorerie Actuelle (Cash)",
                  '${(_totalVentes - _totalDepenses).toInt()} FCFA',
                  Icons.payments,
                  (_totalVentes - _totalDepenses) >= 0 ? const Color(0xFF00E676) : Colors.redAccent
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 15),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildListTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}