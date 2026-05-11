class TransactionItem {
  final int? id;
  final int waterItemId;
  final String marque;
  final String type; // 'ENTREE' ou 'SORTIE'
  final int quantite;
  final double montant;
  final String date;
  final bool estPaye;
  final String statut; // NOUVEAU : 'VALIDEE' ou 'EN_ATTENTE'

  TransactionItem({
    this.id,
    required this.waterItemId,
    required this.marque,
    required this.type,
    required this.quantite,
    required this.montant,
    required this.date,
    required this.estPaye,
    this.statut = 'VALIDEE', // Par défaut, on considère que c'est validé
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
      'statut': statut,
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
      statut: map['statut'] ?? 'VALIDEE',
    );
  }
}