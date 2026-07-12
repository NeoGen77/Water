// Une commande regroupe plusieurs lignes (panier) sous un vrai numéro,
// avec des paiements séparés qui permettent le règlement partiel des dettes.

class Commande {
  static const typeVente = 'SORTIE';
  static const typeRavitaillement = 'ENTREE';
  static const statutEnAttente = 'EN_ATTENTE';
  static const statutValidee = 'VALIDEE';

  final int? id;
  final String numero; // ex: VEN-20260712-0003
  final String type; // SORTIE (vente) ou ENTREE (ravitaillement)
  final int? clientId;
  final String? clientNom; // jointure, pour affichage
  final String date; // ISO 8601
  final String statut;
  final double total;
  final double benefice;
  final double totalPaye; // somme des paiements (calculée)
  final bool intentionPaye; // comptant (true) ou crédit, pour les EN_ATTENTE

  const Commande({
    this.id,
    required this.numero,
    required this.type,
    this.clientId,
    this.clientNom,
    required this.date,
    required this.statut,
    required this.total,
    required this.benefice,
    this.totalPaye = 0,
    this.intentionPaye = true,
  });

  bool get estVente => type == typeVente;
  bool get estValidee => statut == statutValidee;
  double get resteAPayer => (total - totalPaye).clamp(0, double.infinity);
  bool get estSoldee => !estVente || resteAPayer <= 0.001;

  factory Commande.fromMap(Map<String, dynamic> map) => Commande(
        id: map['id'] as int?,
        numero: map['numero'] as String,
        type: map['type'] as String,
        clientId: map['client_id'] as int?,
        clientNom: map['client_nom'] as String?,
        date: map['date'] as String,
        statut: map['statut'] as String,
        total: (map['total'] as num?)?.toDouble() ?? 0.0,
        benefice: (map['benefice'] as num?)?.toDouble() ?? 0.0,
        totalPaye: (map['total_paye'] as num?)?.toDouble() ?? 0.0,
        intentionPaye: (map['intention_paye'] as num?)?.toInt() != 0,
      );
}

class LigneCommande {
  final int? id;
  final int? commandeId;
  final int produitId;
  final String marque; // copie du nom au moment de la vente
  final int quantite;
  final double prixUnitaire;
  final double montant;
  final double benefice;

  const LigneCommande({
    this.id,
    this.commandeId,
    required this.produitId,
    required this.marque,
    required this.quantite,
    required this.prixUnitaire,
    required this.montant,
    required this.benefice,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'commande_id': commandeId,
        'produit_id': produitId,
        'marque': marque,
        'quantite': quantite,
        'prix_unitaire': prixUnitaire,
        'montant': montant,
        'benefice': benefice,
      };

  factory LigneCommande.fromMap(Map<String, dynamic> map) => LigneCommande(
        id: map['id'] as int?,
        commandeId: map['commande_id'] as int?,
        produitId: (map['produit_id'] as num).toInt(),
        marque: map['marque'] as String,
        quantite: (map['quantite'] as num).toInt(),
        prixUnitaire: (map['prix_unitaire'] as num?)?.toDouble() ?? 0.0,
        montant: (map['montant'] as num?)?.toDouble() ?? 0.0,
        benefice: (map['benefice'] as num?)?.toDouble() ?? 0.0,
      );
}

class Paiement {
  final int? id;
  final int commandeId;
  final double montant;
  final String date;

  const Paiement({
    this.id,
    required this.commandeId,
    required this.montant,
    required this.date,
  });

  factory Paiement.fromMap(Map<String, dynamic> map) => Paiement(
        id: map['id'] as int?,
        commandeId: (map['commande_id'] as num).toInt(),
        montant: (map['montant'] as num).toDouble(),
        date: map['date'] as String,
      );
}
