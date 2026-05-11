import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/water_item.dart';
import '../models/transaction_item.dart';

class DBHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('water_stock_v5.db'); // PASSAGE EN V5
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

    // AJOUT DE LA COLONNE STATUT
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
        statut TEXT NOT NULL 
      )
    ''');
  }

  // --- Méthodes Stock ---
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

  // --- Méthodes Transactions ---
  Future<int> insertTransaction(TransactionItem transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  // Récupère UNIQUEMENT les transactions validées pour la caisse principale
  Future<List<TransactionItem>> getAllTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: 'statut = ?',
        whereArgs: ['VALIDEE'],
        orderBy: 'id DESC'
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }

  // --- NOUVEAU : POUR LE SYSTÈME DE SÉCRÉTAIRE ---

  // 1. Récupère les transactions en attente de vérification
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

  // 2. Fonction pour l'Admin pour valider une opération
  Future<int> validerTransaction(int id) async {
    final db = await database;
    return await db.rawUpdate(
        'UPDATE transactions SET statut = ? WHERE id = ?',
        ['VALIDEE', id]
    );
  }

  // 3. Fonction pour rejeter/supprimer une fausse saisie de la secrétaire
  Future<int> supprimerTransaction(int id) async {
    final db = await database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------

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
}