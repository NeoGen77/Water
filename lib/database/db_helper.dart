import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/water_item.dart';
import '../models/transaction_item.dart';

class DBHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    // PASSAGE EN V7 POUR LA CLÔTURE DE CAISSE ET ARCHIVES
    _database = await _initDB('water_stock_v7.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3, // PASSAGE EN VERSION 2 POUR LE PRIX D'ACHAT
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // NOUVEAU : Fonction de mise à jour
    );
  }

  // --- NOUVEAU : Met à jour la base existante sans perdre les données ---
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE water_items ADD COLUMN prix_achat REAL NOT NULL DEFAULT 0.0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE transactions ADD COLUMN benefice REAL NOT NULL DEFAULT 0.0');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE water_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        marque TEXT NOT NULL,
        format TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        seuil_alerte INTEGER NOT NULL,
        prix_achat REAL NOT NULL DEFAULT 0.0, -- NOUVELLE COLONNE
        prix_vente REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        water_item_id INTEGER NOT NULL,
        marque TEXT NOT NULL,
        type TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        montant REAL NOT NULL,
        benefice REAL NOT NULL,
        date TEXT NOT NULL,
        est_paye INTEGER NOT NULL,
        statut TEXT NOT NULL,
        nom_client TEXT 
      )
    ''');

    // NOUVELLE TABLE : Les Archives de Fin de Journée
    await db.execute('''
      CREATE TABLE bilans_journaliers (
        date_cloture TEXT PRIMARY KEY,
        total_entrees REAL NOT NULL,
        total_sorties REAL NOT NULL,
        total_credits_accordes REAL NOT NULL,
        total_credits_encaisses REAL NOT NULL,
        cash_theorique REAL NOT NULL,
        cash_reel_declare REAL NOT NULL,
        ecart_caisse REAL NOT NULL,
        nombre_ventes INTEGER NOT NULL,
        marque_top_vente TEXT
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

  Future<int> updateWaterItem(WaterItem item) async {
    final db = await database;
    return await db.update(
      'water_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

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

  Future<List<TransactionItem>> getAllTransactions({String filter = 'Tout', int limit = 20, int offset = 0}) async {
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

    final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'id DESC',
        limit: limit,
        offset: offset
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }

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

    var resultat = await db.rawQuery('''
      SELECT type, SUM(montant) as total, SUM(benefice) as total_benefice
      FROM transactions
      WHERE $whereClause
      GROUP BY type
    ''', whereArgs);

    double ventes = 0;
    double depenses = 0;
    double benefices = 0;

    for (var row in resultat) {
      if (row['type'] == 'ENTREE') {
        depenses += (row['total'] as num?)?.toDouble() ?? 0.0;
      } else if (row['type'] == 'SORTIE') {
        ventes += (row['total'] as num?)?.toDouble() ?? 0.0;
        // On récupère le bénéfice calculé lors de chaque vente
        benefices += (row['total_benefice'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return {'ventes': ventes, 'depenses': depenses, 'benefices': benefices};
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
      WHERE type = 'SORTIE' AND statut = 'VALIDEE' AND date LIKE '${DateTime.now().toString().substring(0, 10)}%'
      GROUP BY marque 
      ORDER BY total DESC LIMIT 1
    ''');
    if (res.isNotEmpty && res.first['marque'] != null) return res.first['marque'] as String;
    return "Aucune vente";
  }

  // ==========================================
  // MÉTHODES POUR LA GESTION DES DETTES
  // ==========================================

  Future<int> solderDette(int id) async {
    final db = await database;
    String today = DateTime.now().toString().substring(0, 19);

    return await db.rawUpdate(
        'UPDATE transactions SET est_paye = ?, date = ? WHERE id = ?',
        [1, today, id]
    );
  }

  Future<List<TransactionItem>> getToutesLesDettes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
        'transactions',
        where: 'type = ? AND est_paye = ? AND statut = ?',
        whereArgs: ['SORTIE', 0, 'VALIDEE'],
        orderBy: 'id DESC'
    );
    return List.generate(maps.length, (i) => TransactionItem.fromMap(maps[i]));
  }

  // ==========================================
  // NOUVELLES MÉTHODES : CLÔTURE DE CAISSE & RAPPORTS
  // ==========================================

  Future<Map<String, dynamic>> preparerClotureJour(String dateDuJour) async {
    final db = await database;

    var ventesPayees = await db.rawQuery("SELECT SUM(montant) as total FROM transactions WHERE type = 'SORTIE' AND est_paye = 1 AND statut = 'VALIDEE' AND date LIKE '$dateDuJour%'");
    var depenses = await db.rawQuery("SELECT SUM(montant) as total FROM transactions WHERE type = 'ENTREE' AND statut = 'VALIDEE' AND date LIKE '$dateDuJour%'");
    var credits = await db.rawQuery("SELECT SUM(montant) as total FROM transactions WHERE type = 'SORTIE' AND est_paye = 0 AND statut = 'VALIDEE' AND date LIKE '$dateDuJour%'");
    var countVentes = await db.rawQuery("SELECT COUNT(id) as total FROM transactions WHERE type = 'SORTIE' AND statut = 'VALIDEE' AND date LIKE '$dateDuJour%'");

    double totalEntrees = (ventesPayees.first['total'] as num?)?.toDouble() ?? 0.0;
    double totalSorties = (depenses.first['total'] as num?)?.toDouble() ?? 0.0;
    double totalCreditsAccordes = (credits.first['total'] as num?)?.toDouble() ?? 0.0;
    int nombreVentes = (countVentes.first['total'] as int?) ?? 0;
    String topVente = await getTopSellingProduct();

    double cashTheorique = totalEntrees - totalSorties;

    return {
      'date_cloture': dateDuJour,
      'total_entrees': totalEntrees,
      'total_sorties': totalSorties,
      'total_credits_accordes': totalCreditsAccordes,
      'total_credits_encaisses': 0.0,
      'cash_theorique': cashTheorique,
      'nombre_ventes': nombreVentes,
      'marque_top_vente': topVente
    };
  }

  Future<int> enregistrerCloture(Map<String, dynamic> bilanMap) async {
    final db = await database;
    return await db.insert('bilans_journaliers', bilanMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getHistoriqueBilans() async {
    final db = await database;
    return await db.query('bilans_journaliers', orderBy: 'date_cloture DESC');
  }

  Future<Map<String, dynamic>> getRapportHebdomadaire(String dateDebut, String dateFin) async {
    final db = await database;
    var res = await db.rawQuery('''
      SELECT 
        SUM(total_entrees) as recettes, 
        SUM(total_sorties) as depenses,
        SUM(total_credits_accordes) as credits,
        SUM(nombre_ventes) as ventes
      FROM bilans_journaliers 
      WHERE date_cloture BETWEEN ? AND ?
    ''', [dateDebut, dateFin]);

    if (res.isNotEmpty && res.first['recettes'] != null) {
      double recettes = (res.first['recettes'] as num).toDouble();
      double depenses = (res.first['depenses'] as num).toDouble();
      return {
        'recettes': recettes,
        'depenses': depenses,
        'credits': (res.first['credits'] as num).toDouble(),
        'ventes': res.first['ventes'] as int,
        'benefice': recettes - depenses
      };
    }
    return {};
  }

// ==========================================
  // RAPPORTS AUTOMATIQUES SANS CLÔTURE MANUELLE
  // ==========================================
  Future<List<Map<String, dynamic>>> getRapportsJournaliersAutomatiques() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        substr(date, 1, 10) as jour,
        SUM(CASE WHEN type = 'SORTIE' AND est_paye = 1 THEN montant ELSE 0 END) as recettes,
        SUM(CASE WHEN type = 'ENTREE' THEN montant ELSE 0 END) as depenses,
        SUM(CASE WHEN type = 'SORTIE' AND est_paye = 0 THEN montant ELSE 0 END) as credits,
        SUM(CASE WHEN type = 'SORTIE' THEN benefice ELSE 0 END) as benefice_net, -- NOUVEAU : Calcul du profit
        COUNT(id) as nombre_operations
      FROM transactions
      WHERE statut = 'VALIDEE'
      GROUP BY substr(date, 1, 10)
      ORDER BY jour DESC
    ''');
  }

  Future<void> updateWaterItemMapSilencieux(Map<String, dynamic> map) async {
    final db = await database;
    await db.insert('water_items', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertTransactionSilencieux(Map<String, dynamic> map) async {
    final db = await database;
    await db.insert('transactions', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ==========================================
  // FERMETURE DE LA BASE (Utile pour la restauration)
  // ==========================================
  Future<void> fermerBaseDeDonnees() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint("Base de données fermée avec succès.");
    }
  }

  // ==========================================
  // ANNULATION D'UNE TRANSACTION AVEC CORRECTION DE STOCK
  // ==========================================
  Future<bool> annulerTransaction(int idTransaction) async {
    final db = await database;
    try {
      await db.transaction((txn) async {

        final List<Map<String, dynamic>> transData = await txn.query(
            'transactions',
            where: 'id = ?',
            whereArgs: [idTransaction]
        );

        if (transData.isEmpty) return;

        int waterItemId = transData.first['water_item_id'];
        int quantite = transData.first['quantite'];
        String type = transData.first['type'];

        final List<Map<String, dynamic>> itemData = await txn.query(
            'water_items',
            where: 'id = ?',
            whereArgs: [waterItemId]
        );

        if (itemData.isNotEmpty) {
          int stockActuel = itemData.first['quantite'];

          int nouveauStock = type == 'SORTIE' ? (stockActuel + quantite) : (stockActuel - quantite);

          await txn.update(
              'water_items',
              {'quantite': nouveauStock},
              where: 'id = ?',
              whereArgs: [waterItemId]
          );
        }

        await txn.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [idTransaction]
        );
      });
      return true;
    } catch (e) {
      debugPrint("Erreur lors de l'annulation de la transaction : $e");
      return false;
    }
  }

  // ==========================================
  // DANGER ZONE : RÉINITIALISATION COMPLÈTE
  // ==========================================
  Future<void> reinitialiserBaseDeDonnees() async {
    final db = await database;
    try {
      await db.transaction((txn) async {
        await txn.delete('transactions');
        await txn.update('water_items', {'quantite': 0});
      });
      debugPrint("✅ Base de données réinitialisée avec succès.");
    } catch (e) {
      debugPrint("❌ Erreur lors de la réinitialisation : $e");
    }
  }
}