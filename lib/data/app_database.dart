import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base de données v4 : schéma relationnel propre avec clés étrangères.
///
/// - `produits`   : le catalogue (ex-water_items)
/// - `clients`    : fiches clients réelles (plus de texte libre dupliqué)
/// - `commandes`  : une vente ou un ravitaillement, avec un vrai numéro
/// - `lignes`     : les articles d'une commande (panier)
/// - `paiements`  : encaissements, permettant les règlements partiels
///
/// Au premier lancement, les données de l'ancienne base (water_stock_v7.db)
/// sont migrées automatiquement.
class AppDatabase {
  static const dbName = 'depot_eau_v4.db';
  static const _ancienneDbName = 'water_stock_v7.db';

  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dossier = await getDatabasesPath();
    _db = await openDatabase(
      join(dossier, dbName),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _creerSchema(db);
        await _migrerAncienneBase(db, join(dossier, _ancienneDbName));
      },
    );
    return _db!;
  }

  static Future<void> fermer() async {
    await _db?.close();
    _db = null;
  }

  /// Zone de danger : efface l'historique et remet le stock à zéro.
  static Future<void> reinitialiser() async {
    final db = await instance;
    await db.transaction((txn) async {
      await txn.delete('paiements');
      await txn.delete('lignes');
      await txn.delete('commandes');
      await txn.update('produits', {'quantite': 0});
    });
  }

  static Future<void> _creerSchema(Database db) async {
    await db.execute('''
      CREATE TABLE produits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        marque TEXT NOT NULL,
        format TEXT NOT NULL,
        quantite INTEGER NOT NULL DEFAULT 0,
        seuil_alerte INTEGER NOT NULL DEFAULT 10,
        prix_achat REAL NOT NULL DEFAULT 0,
        prix_vente REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL UNIQUE COLLATE NOCASE,
        telephone TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE commandes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL CHECK (type IN ('SORTIE','ENTREE')),
        client_id INTEGER REFERENCES clients(id) ON DELETE SET NULL,
        date TEXT NOT NULL,
        statut TEXT NOT NULL CHECK (statut IN ('EN_ATTENTE','VALIDEE')),
        total REAL NOT NULL DEFAULT 0,
        benefice REAL NOT NULL DEFAULT 0,
        intention_paye INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE lignes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commande_id INTEGER NOT NULL REFERENCES commandes(id) ON DELETE CASCADE,
        produit_id INTEGER NOT NULL,
        marque TEXT NOT NULL,
        quantite INTEGER NOT NULL,
        prix_unitaire REAL NOT NULL DEFAULT 0,
        montant REAL NOT NULL DEFAULT 0,
        benefice REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE paiements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        commande_id INTEGER NOT NULL REFERENCES commandes(id) ON DELETE CASCADE,
        montant REAL NOT NULL,
        date TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_commandes_date ON commandes(date)');
    await db.execute('CREATE INDEX idx_commandes_statut ON commandes(statut)');
    await db.execute('CREATE INDEX idx_lignes_commande ON lignes(commande_id)');
    await db.execute('CREATE INDEX idx_paiements_commande ON paiements(commande_id)');
  }

  // ==========================================================
  // MIGRATION DEPUIS L'ANCIENNE APPLICATION (v7)
  // ==========================================================
  static Future<void> _migrerAncienneBase(Database db, String cheminAncien) async {
    if (!await File(cheminAncien).exists()) return;

    Database? ancienne;
    try {
      ancienne = await openReadOnlyDatabase(cheminAncien);

      // 1. Produits
      final anciensProduits = await ancienne.query('water_items');
      final mapProduits = <int, int>{}; // ancien id -> nouvel id
      for (final p in anciensProduits) {
        final nouvelId = await db.insert('produits', {
          'marque': p['marque'],
          'format': p['format'],
          'quantite': p['quantite'],
          'seuil_alerte': p['seuil_alerte'],
          'prix_achat': p['prix_achat'] ?? 0,
          'prix_vente': p['prix_vente'] ?? 0,
        });
        mapProduits[p['id'] as int] = nouvelId;
      }

      // 2. Transactions -> clients + commandes + lignes + paiements.
      // L'ancienne app liait les lignes d'un même panier par (date, client, type).
      final anciennes = await ancienne.query('transactions', orderBy: 'id ASC');
      final mapClients = <String, int>{}; // nom en minuscules -> id
      final mapCommandes = <String, int>{}; // clé de groupe -> id commande
      int compteur = 0;

      for (final t in anciennes) {
        final type = t['type'] as String;
        final statut = (t['statut'] as String?) ?? 'VALIDEE';
        final date = (t['date'] as String?) ?? '';
        final nomClient = (t['nom_client'] as String?)?.trim() ?? '';
        final montant = (t['montant'] as num?)?.toDouble() ?? 0;
        final quantite = (t['quantite'] as num?)?.toInt() ?? 0;
        final estPaye = t['est_paye'] == 1;

        // Client (on ignore les anonymes)
        int? clientId;
        if (nomClient.isNotEmpty && nomClient.toLowerCase() != 'client anonyme') {
          final cle = nomClient.toLowerCase();
          clientId = mapClients[cle];
          if (clientId == null) {
            clientId = await db.insert('clients', {
              'nom': nomClient,
              'created_at': date,
            });
            mapClients[cle] = clientId;
          }
        }

        // Commande (regroupement identique à l'ancienne logique)
        final cleGroupe = '$date|$nomClient|$type|$statut';
        int? commandeId = mapCommandes[cleGroupe];
        if (commandeId == null) {
          compteur++;
          final prefixe = type == 'SORTIE' ? 'VEN' : 'RAV';
          commandeId = await db.insert('commandes', {
            'numero': '$prefixe-MIG-${compteur.toString().padLeft(5, '0')}',
            'type': type,
            'client_id': clientId,
            'date': date,
            'statut': statut,
            'total': 0,
            'benefice': 0,
            'intention_paye': estPaye ? 1 : 0,
          });
          mapCommandes[cleGroupe] = commandeId;
        }

        final produitId = mapProduits[(t['water_item_id'] as num?)?.toInt()] ?? 0;
        await db.insert('lignes', {
          'commande_id': commandeId,
          'produit_id': produitId,
          'marque': t['marque'],
          'quantite': quantite,
          'prix_unitaire': quantite > 0 ? montant / quantite : 0,
          'montant': montant,
          'benefice': t['benefice'] ?? 0,
        });

        await db.rawUpdate(
          'UPDATE commandes SET total = total + ?, benefice = benefice + ? WHERE id = ?',
          [montant, (t['benefice'] as num?)?.toDouble() ?? 0, commandeId],
        );

        // Ancienne vente déjà payée -> paiement complet à la date de la vente
        if (type == 'SORTIE' && estPaye && montant > 0) {
          await db.insert('paiements', {
            'commande_id': commandeId,
            'montant': montant,
            'date': date,
          });
        }
      }
      debugPrint('✅ Migration terminée : ${anciensProduits.length} produits, '
          '${anciennes.length} lignes, ${mapClients.length} clients.');
    } catch (e) {
      debugPrint('⚠️ Migration de l\'ancienne base impossible : $e');
    } finally {
      await ancienne?.close();
    }
  }
}
