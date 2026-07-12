class Client {
  final int? id;
  final String nom;
  final String? telephone;
  final String createdAt;

  const Client({
    this.id,
    required this.nom,
    this.telephone,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nom': nom,
        'telephone': telephone,
        'created_at': createdAt,
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as int?,
        nom: map['nom'] as String,
        telephone: map['telephone'] as String?,
        createdAt: map['created_at'] as String? ?? '',
      );
}
