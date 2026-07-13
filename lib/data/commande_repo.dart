import 'package:sqflite/sqflite.dart';

import '../core/formats.dart';
import '../models/commande.dart';
import 'app_database.dart';

/// Toutes les écritures qui touchent à la fois au stock, aux commandes et
/// aux paiements passent par une transaction SQL : soit tout réussit,
/// soit rien n'est modifié.
class CommandeRepo {
  static const _selectAvecPaiements = '''
    SELECT cmd.*, c.nom AS client_nom, COALESCE(p.paye, 0) AS total_paye
    FROM commandes cmd
    LEFT JOIN clients c ON c.id = cmd.client_id
    LEFT JOIN (
      SELECT commande_id, SUM(montant) AS paye FROM paiements GROUP BY commande_id
    ) p ON p.commande_id = cmd.id
  ''';

  // ==========================================================
  // CRÉATION D'UNE COMMANDE (panier complet, atomique)
  // ==========================================================
  Future<String> creerCommande({
    required String type, // Commande.typeVente ou typeRavitaillement
    required List<LigneCommande> lignes,
    int? clientId,
    required bool estPayeComptant,
    required bool isAdmin,
  }) async {
    if (lignes.isEmpty) throw ArgumentError('Panier vide');
    final db = await AppDatabase.instance;

    return db.transaction((txn) async {
      final statut = isAdmin ? Commande.statutValidee : Commande.statutEnAttente;
      final date = nowIso();
      final numero = await _prochainNumero(txn, type);

      double total = 0, benefice = 0;
      for (final l in lignes) {
        total += l.montant;
        benefice += l.benefice;
      }

      // Vérification du stock au moment exact de l'écriture (ventes validées)
      if (type == Commande.typeVente) {
        for (final l in lignes) {
          final rows = await txn.query('produits',
              columns: ['quantite', 'marque'], where: 'id = ?', whereArgs: [l.produitId]);
          if (rows.isEmpty) throw StateError('Produit introuvable : ${l.marque}');
          final dispo = (rows.first['quantite'] as num).toInt();
          final demande = lignes
              .where((x) => x.produitId == l.produitId)
              .fold<int>(0, (s, x) => s + x.quantite);
          if (demande > dispo) {
            throw StateError('Stock insuffisant : il reste $dispo ${l.marque}.');
          }
        }
      }

      final commandeId = await txn.insert('commandes', {
        'numero': numero,
        'type': type,
        'client_id': clientId,
        'date': date,
        'statut': statut,
        'total': total,
        'benefice': benefice,
        'intention_paye': estPayeComptant ? 1 : 0,
      });

      for (final l in lignes) {
        await txn.insert('lignes', (l.toMap()..remove('id'))..['commande_id'] = commandeId);
      }

      // Le stock ne bouge que pour les commandes validées (Admin).
      if (isAdmin) {
        await _appliquerStock(txn, commandeId, type, sens: 1);
      }

      // Vente payée comptant -> paiement complet immédiat.
      if (type == Commande.typeVente && estPayeComptant && isAdmin) {
        await txn.insert('paiements',
            {'commande_id': commandeId, 'montant': total, 'date': date});
      }
      return numero;
    });
  }

  Future<String> _prochainNumero(DatabaseExecutor txn, String type) async {
    final prefixe = type == Commande.typeVente ? 'VEN' : 'RAV';
    final jour = todayKey().replaceAll('-', '');
    final res = await txn.rawQuery(
      "SELECT COUNT(*) AS n FROM commandes WHERE numero LIKE ?",
      ['$prefixe-$jour-%'],
    );
    final n = (res.first['n'] as num).toInt() + 1;
    return '$prefixe-$jour-${n.toString().padLeft(4, '0')}';
  }

  /// sens = 1 pour appliquer, -1 pour annuler l'effet stock.
  Future<void> _appliquerStock(DatabaseExecutor txn, int commandeId, String type,
      {required int sens}) async {
    final lignes =
        await txn.query('lignes', where: 'commande_id = ?', whereArgs: [commandeId]);
    for (final l in lignes) {
      final variation = (type == Commande.typeVente ? -1 : 1) *
          sens *
          (l['quantite'] as num).toInt();
      await txn.rawUpdate('UPDATE produits SET quantite = quantite + ? WHERE id = ?',
          [variation, l['produit_id']]);
    }
  }

  // ==========================================================
  // VALIDATION / REJET (workflow secrétaire)
  // ==========================================================
  Future<void> validerCommande(int commandeId) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      final rows =
          await txn.query('commandes', where: 'id = ?', whereArgs: [commandeId]);
      if (rows.isEmpty) throw StateError('Commande introuvable');
      final type = rows.first['type'] as String;
      final total = (rows.first['total'] as num).toDouble();
      final payeComptant = rows.first['intention_paye'] == 1;

      if (type == Commande.typeVente) {
        final lignes = await txn
            .query('lignes', where: 'commande_id = ?', whereArgs: [commandeId]);
        for (final l in lignes) {
          final prod = await txn.query('produits',
              columns: ['quantite'], where: 'id = ?', whereArgs: [l['produit_id']]);
          final dispo = prod.isEmpty ? 0 : (prod.first['quantite'] as num).toInt();
          if ((l['quantite'] as num).toInt() > dispo) {
            throw StateError(
                'Stock insuffisant pour ${l['marque']} : $dispo restant(s).');
          }
        }
      }

      await txn.update('commandes', {'statut': Commande.statutValidee},
          where: 'id = ?', whereArgs: [commandeId]);
      await _appliquerStock(txn, commandeId, type, sens: 1);

      if (type == Commande.typeVente && payeComptant) {
        await txn.insert('paiements',
            {'commande_id': commandeId, 'montant': total, 'date': nowIso()});
      }
    });
  }

  Future<void> rejeterCommande(int commandeId) async {
    final db = await AppDatabase.instance;
    // ON DELETE CASCADE supprime lignes et paiements.
    await db.delete('commandes', where: 'id = ?', whereArgs: [commandeId]);
  }

  /// Annule une commande validée : le stock est restauré, tout est supprimé.
  Future<void> annulerCommande(int commandeId) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      final rows =
          await txn.query('commandes', where: 'id = ?', whereArgs: [commandeId]);
      if (rows.isEmpty) return;
      if (rows.first['statut'] == Commande.statutValidee) {
        await _appliquerStock(txn, commandeId, rows.first['type'] as String, sens: -1);
      }
      await txn.delete('commandes', where: 'id = ?', whereArgs: [commandeId]);
    });
  }

  // ==========================================================
  // PAIEMENTS (règlement partiel des dettes)
  // ==========================================================
  Future<void> encaisser(int commandeId, double montant) async {
    if (montant <= 0) throw ArgumentError('Montant invalide');
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      final res = await txn.rawQuery('''
        SELECT cmd.total, COALESCE(SUM(p.montant), 0) AS paye
        FROM commandes cmd LEFT JOIN paiements p ON p.commande_id = cmd.id
        WHERE cmd.id = ? GROUP BY cmd.id
      ''', [commandeId]);
      if (res.isEmpty) throw StateError('Commande introuvable');
      final reste = (res.first['total'] as num).toDouble() -
          (res.first['paye'] as num).toDouble();
      if (montant > reste + 0.001) {
        throw StateError('Le montant dépasse le reste à payer (${reste.toInt()} F).');
      }
      await txn.insert('paiements',
          {'commande_id': commandeId, 'montant': montant, 'date': nowIso()});
    });
  }

  Future<List<Paiement>> paiementsDe(int commandeId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('paiements',
        where: 'commande_id = ?', whereArgs: [commandeId], orderBy: 'date');
    return rows.map(Paiement.fromMap).toList();
  }

  // ==========================================================
  // LECTURES
  // ==========================================================
  Future<List<Commande>> historique(
      {String filtre = 'Tout', int limit = 20, int offset = 0}) async {
    final db = await AppDatabase.instance;
    final where = _clauseFiltre(filtre, statut: Commande.statutValidee);
    final rows = await db.rawQuery(
        '$_selectAvecPaiements WHERE ${where.$1} ORDER BY cmd.date DESC, cmd.id DESC LIMIT ? OFFSET ?',
        [...where.$2, limit, offset]);
    return rows.map(Commande.fromMap).toList();
  }

  Future<List<Commande>> enAttente() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery(
        "$_selectAvecPaiements WHERE cmd.statut = 'EN_ATTENTE' ORDER BY cmd.id DESC");
    return rows.map(Commande.fromMap).toList();
  }

  Future<List<LigneCommande>> lignesDe(int commandeId) async {
    final db = await AppDatabase.instance;
    final rows =
        await db.query('lignes', where: 'commande_id = ?', whereArgs: [commandeId]);
    return rows.map(LigneCommande.fromMap).toList();
  }

  /// Ventes validées non soldées d'un client, avec reste à payer.
  Future<List<Commande>> dettesDuClient(int clientId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      $_selectAvecPaiements
      WHERE cmd.client_id = ? AND cmd.type = 'SORTIE' AND cmd.statut = 'VALIDEE'
        AND cmd.total - COALESCE(p.paye, 0) > 0.001
      ORDER BY cmd.date
    ''', [clientId]);
    return rows.map(Commande.fromMap).toList();
  }

  Future<List<Commande>> historiqueDuClient(int clientId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery('''
      $_selectAvecPaiements
      WHERE cmd.client_id = ? AND cmd.type = 'SORTIE' AND cmd.statut = 'VALIDEE'
      ORDER BY cmd.date DESC
    ''', [clientId]);
    return rows.map(Commande.fromMap).toList();
  }

  // ==========================================================
  // STATISTIQUES & RAPPORTS
  // ==========================================================
  (String, List<Object?>) _clauseFiltre(String filtre, {String? statut}) {
    final clauses = <String>[];
    final args = <Object?>[];
    if (statut != null) {
      clauses.add('cmd.statut = ?');
      args.add(statut);
    }
    final now = DateTime.now();
    if (filtre == "Aujourd'hui") {
      clauses.add('cmd.date LIKE ?');
      args.add('${todayKey()}%');
    } else if (filtre == 'Ce mois-ci') {
      clauses.add('cmd.date LIKE ?');
      args.add('${now.toIso8601String().substring(0, 7)}%');
    }
    return (clauses.isEmpty ? '1=1' : clauses.join(' AND '), args);
  }

  /// Ventes, dépenses, bénéfice et encaissements réels sur une période.
  Future<Map<String, double>> bilan({String filtre = 'Tout'}) async {
    final db = await AppDatabase.instance;
    final where = _clauseFiltre(filtre, statut: Commande.statutValidee);

    final res = await db.rawQuery('''
      SELECT cmd.type, SUM(cmd.total) AS total, SUM(cmd.benefice) AS benefice
      FROM commandes cmd
      WHERE ${where.$1}
      GROUP BY cmd.type
    ''', where.$2);

    double ventes = 0, depenses = 0, benefices = 0;
    for (final row in res) {
      if (row['type'] == 'ENTREE') {
        depenses = (row['total'] as num?)?.toDouble() ?? 0;
      } else {
        ventes = (row['total'] as num?)?.toDouble() ?? 0;
        benefices = (row['benefice'] as num?)?.toDouble() ?? 0;
      }
    }

    // Encaissements réels (paiements reçus sur la période, dettes incluses)
    final wherePaie = _clauseFiltre(filtre).$1.replaceAll('cmd.date', 'p.date');
    final resPaie = await db.rawQuery('''
      SELECT COALESCE(SUM(p.montant), 0) AS encaisse FROM paiements p
      WHERE $wherePaie
    ''', _clauseFiltre(filtre).$2);
    final encaisse = (resPaie.first['encaisse'] as num).toDouble();

    return {
      'ventes': ventes,
      'depenses': depenses,
      'benefices': benefices,
      'encaisse': encaisse,
    };
  }

  Future<double> totalDettes() async {
    final db = await AppDatabase.instance;
    final res = await db.rawQuery('''
      SELECT COALESCE(SUM(cmd.total - COALESCE(p.paye, 0)), 0) AS dette
      FROM commandes cmd
      LEFT JOIN (
        SELECT commande_id, SUM(montant) AS paye FROM paiements GROUP BY commande_id
      ) p ON p.commande_id = cmd.id
      WHERE cmd.type = 'SORTIE' AND cmd.statut = 'VALIDEE'
        AND cmd.total - COALESCE(p.paye, 0) > 0.001
    ''');
    return (res.first['dette'] as num).toDouble();
  }

  /// Rapport par jour : ventes, dépenses, encaissements, bénéfice, opérations.
  Future<List<Map<String, dynamic>>> rapportsJournaliers({int limitJours = 90}) async {
    final db = await AppDatabase.instance;
    return db.rawQuery('''
      SELECT jour,
             SUM(ventes) AS ventes,
             SUM(depenses) AS depenses,
             SUM(benefice) AS benefice,
             SUM(encaisse) AS encaisse,
             SUM(nb) AS operations
      FROM (
        SELECT substr(date, 1, 10) AS jour,
               CASE WHEN type = 'SORTIE' THEN total ELSE 0 END AS ventes,
               CASE WHEN type = 'ENTREE' THEN total ELSE 0 END AS depenses,
               CASE WHEN type = 'SORTIE' THEN benefice ELSE 0 END AS benefice,
               0 AS encaisse, 1 AS nb
        FROM commandes WHERE statut = 'VALIDEE'
        UNION ALL
        SELECT substr(date, 1, 10), 0, 0, 0, montant, 0 FROM paiements
      )
      GROUP BY jour
      ORDER BY jour DESC
      LIMIT ?
    ''', [limitJours]);
  }

  /// Dettes anciennes à relancer : ventes validées non soldées depuis
  /// au moins [joursMin] jours, les plus vieilles d'abord.
  Future<List<Map<String, dynamic>>> dettesAnciennes({int joursMin = 15}) async {
    final db = await AppDatabase.instance;
    return db.rawQuery('''
      SELECT cmd.id, cmd.numero, cmd.date, c.nom AS client_nom,
             cmd.total - COALESCE(p.paye, 0) AS reste,
             CAST(julianday('now') - julianday(cmd.date) AS INTEGER) AS anciennete
      FROM commandes cmd
      LEFT JOIN clients c ON c.id = cmd.client_id
      LEFT JOIN (
        SELECT commande_id, SUM(montant) AS paye FROM paiements GROUP BY commande_id
      ) p ON p.commande_id = cmd.id
      WHERE cmd.type = 'SORTIE' AND cmd.statut = 'VALIDEE'
        AND cmd.total - COALESCE(p.paye, 0) > 0.001
        AND julianday('now') - julianday(cmd.date) >= ?
      ORDER BY anciennete DESC
    ''', [joursMin]);
  }

  /// Ventes/dépenses/bénéfice entre deux dates (début inclus, fin exclue).
  /// Sert aux comparaisons de périodes.
  Future<Map<String, double>> bilanPeriode(
      String debutInclus, String finExclue) async {
    final db = await AppDatabase.instance;
    final res = await db.rawQuery('''
      SELECT type, SUM(total) AS total, SUM(benefice) AS benefice
      FROM commandes
      WHERE statut = 'VALIDEE' AND date >= ? AND date < ?
      GROUP BY type
    ''', [debutInclus, finExclue]);

    double ventes = 0, depenses = 0, benefices = 0;
    for (final row in res) {
      if (row['type'] == 'ENTREE') {
        depenses = (row['total'] as num?)?.toDouble() ?? 0;
      } else {
        ventes = (row['total'] as num?)?.toDouble() ?? 0;
        benefices = (row['benefice'] as num?)?.toDouble() ?? 0;
      }
    }
    return {'ventes': ventes, 'depenses': depenses, 'benefices': benefices};
  }

  /// Quantités vendues par produit sur les N derniers jours (ventes validées).
  /// Sert à estimer le rythme de vente et prévoir les ruptures de stock.
  Future<Map<int, int>> quantitesVenduesParProduit({int jours = 14}) async {
    final db = await AppDatabase.instance;
    final depuis = DateTime.now()
        .subtract(Duration(days: jours))
        .toIso8601String()
        .substring(0, 10);
    final rows = await db.rawQuery('''
      SELECT l.produit_id, SUM(l.quantite) AS q
      FROM lignes l
      JOIN commandes cmd ON cmd.id = l.commande_id
      WHERE cmd.type = 'SORTIE' AND cmd.statut = 'VALIDEE' AND cmd.date >= ?
      GROUP BY l.produit_id
    ''', [depuis]);
    return {
      for (final r in rows)
        (r['produit_id'] as num).toInt(): (r['q'] as num?)?.toInt() ?? 0
    };
  }

  Future<int> nombreEnAttente() async {
    final db = await AppDatabase.instance;
    final res = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM commandes WHERE statut = 'EN_ATTENTE'");
    return (res.first['n'] as num).toInt();
  }

  /// Quantités vendues par marque sur une période (top ventes).
  Future<List<Map<String, dynamic>>> topVentes({String filtre = 'Tout'}) async {
    final db = await AppDatabase.instance;
    final where = _clauseFiltre(filtre, statut: Commande.statutValidee);
    return db.rawQuery('''
      SELECT l.marque, SUM(l.quantite) AS quantite, SUM(l.benefice) AS benefice
      FROM lignes l
      JOIN commandes cmd ON cmd.id = l.commande_id AND cmd.type = 'SORTIE'
      WHERE ${where.$1}
      GROUP BY l.marque
      ORDER BY quantite DESC
    ''', where.$2);
  }
}
