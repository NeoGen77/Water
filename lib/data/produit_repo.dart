import '../models/produit.dart';
import 'app_database.dart';

class ProduitRepo {
  Future<List<Produit>> tous() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('produits', orderBy: 'marque COLLATE NOCASE');
    return rows.map(Produit.fromMap).toList();
  }

  Future<int> creer(Produit p) async {
    final db = await AppDatabase.instance;
    final map = p.toMap()..remove('id');
    return db.insert('produits', map);
  }

  Future<void> modifier(Produit p) async {
    final db = await AppDatabase.instance;
    await db.update('produits', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> supprimer(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('produits', where: 'id = ?', whereArgs: [id]);
  }

  /// Valeur du stock au prix de vente et au prix d'achat.
  Future<Map<String, double>> valeurStock() async {
    final db = await AppDatabase.instance;
    final res = await db.rawQuery('''
      SELECT SUM(quantite * prix_vente) AS valeur_vente,
             SUM(quantite * prix_achat) AS valeur_achat
      FROM produits
    ''');
    return {
      'valeur_vente': (res.first['valeur_vente'] as num?)?.toDouble() ?? 0,
      'valeur_achat': (res.first['valeur_achat'] as num?)?.toDouble() ?? 0,
    };
  }
}
