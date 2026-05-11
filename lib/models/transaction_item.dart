class TransactionItem {
  final int? id;
  final int waterItemId;
  final String marque;
  final String type;
  final int quantite;
  final double montant;
  final String date;
  final bool estPaye;
  final String statut;
  final String? nomClient; // NOUVEAU

  TransactionItem({
    this.id,
    required this.waterItemId,
    required this.marque,
    required this.type,
    required this.quantite,
    required this.montant,
    required this.date,
    required this.estPaye,
    this.statut = 'VALIDEE',
    this.nomClient,
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
      'nom_client': nomClient,
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
      nomClient: map['nom_client'],
    );
  }
}