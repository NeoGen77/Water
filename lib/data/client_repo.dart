import '../models/client.dart';
import '../core/formats.dart';
import 'app_database.dart';

class ClientRepo {
  Future<List<Client>> tous() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('clients', orderBy: 'nom COLLATE NOCASE');
    return rows.map(Client.fromMap).toList();
  }

  /// Retrouve un client par nom (insensible à la casse) ou le crée.
  Future<int> trouverOuCreer(String nom, {String? telephone}) async {
    final db = await AppDatabase.instance;
    final existant = await db.query(
      'clients',
      where: 'nom = ? COLLATE NOCASE',
      whereArgs: [nom.trim()],
      limit: 1,
    );
    if (existant.isNotEmpty) return existant.first['id'] as int;
    return db.insert('clients', {
      'nom': nom.trim(),
      'telephone': telephone,
      'created_at': nowIso(),
    });
  }

  Future<void> modifier(Client c) async {
    final db = await AppDatabase.instance;
    await db.update('clients', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  /// Clients avec leur dette totale (ventes validées non soldées).
  Future<List<Map<String, dynamic>>> clientsAvecDettes() async {
    final db = await AppDatabase.instance;
    return db.rawQuery('''
      SELECT c.id, c.nom, c.telephone,
             SUM(cmd.total - COALESCE(p.paye, 0)) AS dette,
             COUNT(cmd.id) AS nb_commandes
      FROM clients c
      JOIN commandes cmd ON cmd.client_id = c.id
        AND cmd.type = 'SORTIE' AND cmd.statut = 'VALIDEE'
      LEFT JOIN (
        SELECT commande_id, SUM(montant) AS paye FROM paiements GROUP BY commande_id
      ) p ON p.commande_id = cmd.id
      GROUP BY c.id
      HAVING dette > 0.001
      ORDER BY dette DESC
    ''');
  }
}
