import 'package:flutter/material.dart';
import '../models/water_item.dart';

class StockCard extends StatelessWidget {
  final WaterItem item;

  // 4. Correction : Utilisation du 'super parameter' (syntaxe moderne de Dart)
  const StockCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    bool enAlerte = item.quantite <= item.seuilAlerte;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // 1. Correction : Un seul paramètre 'shape' avec la condition intégrée
      shape: enAlerte
          ? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Colors.redAccent, width: 1.5),
      )
          : RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            // 3. Correction : Remplacement de .withOpacity() par .withValues(alpha: ...)
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
          // 2. Correction : C'est EdgeInsets.only(top: ...) et non EdgeInsets.top()
          padding: const EdgeInsets.only(top: 8.0),
          child: Text('Seuil critique : ${item.seuilAlerte}'),
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