import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/water_item.dart';
import '../models/transaction_item.dart';

class DBHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    // PASSAGE EN V6 POUR LA GESTION DES CRÉDITS ET NOMS CLIENTS
    _database = await _initDB('water_stock_v6.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE water_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        marque TEXT NOT NULL,
        format TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        seuil_alerte INTEGER NOT NULL,
        prix_vente REAL NOT NULL
      )
    ''');

    // AJOUT DE LA COLONNE nom_client
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        water_item_id INTEGER NOT NULL,
        marque TEXT NOT NULL,
        type TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        montant REAL NOT NULL,
        date TEXT NOT NULL,
        est_paye INTEGER NOT NULL,
        statut TEXT NOT NULL,
        nom_client TEXT 
      )
    ''');
  }

  // ==========================================
  // MÉTHODES POUR LE STOCK (WATER_ITEMS)
  // ==========================================

  Future<List<WaterItem>> getAllItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('water_items');
    return List.generate(maps.length, (i) => WaterItem.fromMap(maps[i]));
  }

  Future<int> insertWaterItem(WaterItem item) async {
    final db = await database;
    return await db.insert('water_items', item.toMap());
  }

  Future<int> updateStock(int id, int variation) async {
    final db = await database;
    return await db.rawUpdate(
        'UPDATE water_items SET quantite = quantite + ? WHERE id = ?',
        [variation, id]
    );
  }

  // Modifier un produit entier (Prix, Nom, etc.)
  Future<int> updateWaterItem(WaterItem item) async {
    final db = await database;
    return await db.update(
      'water_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  // Supprimer un produit du catalogue
  Future<int> deleteWaterItem(int id) async {
    final db = await database;
    return await db.delete(
      'water_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // MÉTHODES POUR L'HISTORIQUE (TRANSACTIONS)
  // ==========================================

  Future<int> insertTransaction(TransactionItem transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  // --- MISE À JOUR : AJOUT DE LA PAGINATION (LIMIT / OFFSET) ---
  Future<List<TransactionItem>> getAllTransactions({String filter = 'Tout', int limit = 20, int offset = 0}) async {
    final db = await database;

    String whereClause = 'statut = ?';
    List<dynamic> whereArgs = ['VALIDEE'];

    DateTime now = DateTime.now();

    if (filter == 'Aujourd\'hui') {
      String today = now.toString().substring(0, 10); // Extrait "YYYY-MM-DD"
      whereClause += ' AND date LIKE ?';
      whereArgs.add('$today%');
    } else if (filter == 'Ce mois-ci') {
      String month = now.toString().substring(0, 7); // Extrait "YYYY-MM"
      whereClause += ' AND date LIKE ?';
      whereArgs.add('$month%');
    }

    final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'id DESC',
        limit: limit, // Limite le nombre de résultats (ex: 20)
        offset: offset // Décale le point de départ (ex: sauter les 20 premiers)
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }

  // --- NOUVELLE MÉTHODE : CALCULER LES TOTAUX DIRECTEMENT EN SQL ---
  // Utile car getAllTransactions ne ramène maintenant qu'une partie des données (ex: 20 lignes)
  Future<Map<String, double>> getBilanFinancier({String filter = 'Tout'}) async {
    final db = await database;
    String whereClause = 'statut = ?';
    List<dynamic> whereArgs = ['VALIDEE'];
    DateTime now = DateTime.now();

    if (filter == 'Aujourd\'hui') {
      whereClause += ' AND date LIKE ?';
      whereArgs.add('${now.toString().substring(0, 10)}%');
    } else if (filter == 'Ce mois-ci') {
      whereClause += ' AND date LIKE ?';
      whereArgs.add('${now.toString().substring(0, 7)}%');
    }

    // Demande à SQLite de faire les additions lui-même (très rapide)
    var resultat = await db.rawQuery('''
      SELECT type, SUM(montant) as total
      FROM transactions
      WHERE $whereClause
      GROUP BY type
    ''', whereArgs);

    double recettes = 0;
    double depenses = 0;

    for (var row in resultat) {
      if (row['type'] == 'ENTREE') {
        depenses = (row['total'] as num?)?.toDouble() ?? 0.0;
      } else if (row['type'] == 'SORTIE') {
        recettes = (row['total'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return {'recettes': recettes, 'depenses': depenses};
  }

  Future<List<TransactionItem>> getTransactionsEnAttente() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: 'statut = ?',
        whereArgs: ['EN_ATTENTE'],
        orderBy: 'id DESC'
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }

  Future<int> validerTransaction(int id) async {
    final db = await database;
    return await db.rawUpdate(
        'UPDATE transactions SET statut = ? WHERE id = ?',
        ['VALIDEE', id]
    );
  }

  Future<int> supprimerTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> getTopSellingProduct() async {
    final db = await database;
    var res = await db.rawQuery('''
      SELECT marque, SUM(quantite) as total 
      FROM transactions 
      WHERE type = 'SORTIE' AND statut = 'VALIDEE'
      GROUP BY marque 
      ORDER BY total DESC LIMIT 1
    ''');
    if (res.isNotEmpty && res.first['marque'] != null) return res.first['marque'] as String;
    return "Aucune vente";
  }

  // ==========================================
  // MÉTHODES POUR LA GESTION DES DETTES
  // ==========================================

  // Marquer une dette comme payée (est_paye passe à 1)
  Future<int> solderDette(int id) async {
    final db = await database;
    return await db.rawUpdate(
        'UPDATE transactions SET est_paye = ? WHERE id = ?',
        [1, id]
    );
  }

  // Récupérer uniquement les factures impayées (crédits)
  Future<List<TransactionItem>> getToutesLesDettes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: 'type = ? AND est_paye = ? AND statut = ?',
        whereArgs: ['SORTIE', 0, 'VALIDEE'], // 0 = non payé
        orderBy: 'id DESC'
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }
}