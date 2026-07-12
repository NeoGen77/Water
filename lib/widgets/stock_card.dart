import 'package:flutter/material.dart';

import '../core/formats.dart';
import '../models/produit.dart';

class StockCard extends StatelessWidget {
  final Produit item;

  const StockCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final enAlerte = item.enAlerte;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: enAlerte
            ? const BorderSide(color: Colors.redAccent, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: enAlerte
                ? Colors.redAccent.withValues(alpha: 0.2)
                : Colors.blueAccent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.water_drop,
            color: enAlerte ? Colors.redAccent : Colors.blueAccent,
            size: 30,
          ),
        ),
        title: Text(
          '${item.marque} - ${item.format}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
              'Vente : ${fmtFcfa(item.prixVente)}  •  Seuil : ${item.seuilAlerte}'),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('En Stock', style: TextStyle(color: Colors.grey)),
            Text(
              '${item.quantite}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: enAlerte ? Colors.redAccent : Colors.greenAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
