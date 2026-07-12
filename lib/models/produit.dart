class Produit {
  final int? id;
  final String marque;
  final String format;
  final int quantite; // en nombre de paquets
  final int seuilAlerte;
  final double prixAchat;
  final double prixVente;

  const Produit({
    this.id,
    required this.marque,
    required this.format,
    required this.quantite,
    required this.seuilAlerte,
    required this.prixAchat,
    required this.prixVente,
  });

  double get margeUnitaire => prixVente - prixAchat;
  bool get enAlerte => quantite <= seuilAlerte;

  Map<String, dynamic> toMap() => {
        'id': id,
        'marque': marque,
        'format': format,
        'quantite': quantite,
        'seuil_alerte': seuilAlerte,
        'prix_achat': prixAchat,
        'prix_vente': prixVente,
      };

  factory Produit.fromMap(Map<String, dynamic> map) => Produit(
        id: map['id'] as int?,
        marque: map['marque'] as String,
        format: map['format'] as String,
        quantite: (map['quantite'] as num).toInt(),
        seuilAlerte: (map['seuil_alerte'] as num?)?.toInt() ?? 10,
        prixAchat: (map['prix_achat'] as num?)?.toDouble() ?? 0.0,
        prixVente: (map['prix_vente'] as num?)?.toDouble() ?? 0.0,
      );
}
