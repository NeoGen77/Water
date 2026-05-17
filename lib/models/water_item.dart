class WaterItem {
  final int? id;
  final String marque;
  final String format;
  final int quantite; // Toujours en nombre de paquets
  final int seuilAlerte;
  final double prixAchat; // NOUVEAU : Le prix d'achat/coûtant chez le grossiste
  final double prixVente; // Prix de vente fixe par paquet

  WaterItem({
    this.id,
    required this.marque,
    required this.format,
    required this.quantite,
    required this.seuilAlerte,
    required this.prixAchat, // NOUVEAU
    required this.prixVente,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'marque': marque,
      'format': format,
      'quantite': quantite,
      'seuil_alerte': seuilAlerte,
      'prix_achat': prixAchat, // NOUVEAU
      'prix_vente': prixVente,
    };
  }

  factory WaterItem.fromMap(Map<String, dynamic> map) {
    return WaterItem(
      id: map['id'],
      marque: map['marque'],
      format: map['format'],
      quantite: map['quantite'],
      seuilAlerte: map['seuil_alerte'],
      // Le "??" permet d'éviter un crash si la base de données ne contient pas encore cette info
      prixAchat: map['prix_achat'] ?? 0.0, // NOUVEAU
      prixVente: map['prix_vente'],
    );
  }
}