class TransactionItem {
  final int? id;
  final int waterItemId;
  final String marque;
  final String type; // 'ENTREE' ou 'SORTIE'
  final int quantite;
  final double montant; // Quantité * Prix (Achat ou Vente selon le type)
  final String date;
  final bool estPaye;

  TransactionItem({
    this.id,
    required this.waterItemId,
    required this.marque,
    required this.type,
    required this.quantite,
    required this.montant,
    required this.date,
    required this.estPaye,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'water_item_id': waterItemId,
      'marque': marque,
      'type': type,
      'quantite': quantite,
      'montant': montant,
      'date': date,
      'est_paye': estPaye ? 1 : 0,
    };
  }

  factory TransactionItem.fromMap(Map<String, dynamic> map) {
    return TransactionItem(
      id: map['id'],
      waterItemId: map['water_item_id'],
      marque: map['marque'],
      type: map['type'],
      quantite: map['quantite'],
      montant: map['montant'],
      date: map['date'],
      estPaye: map['est_paye'] == 1,
    );
  }
}