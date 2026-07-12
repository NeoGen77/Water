import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/commande_repo.dart';
import '../data/produit_repo.dart';

/// Export Excel : rapports journaliers + état du stock.
class ExportService {
  /// Génère un classeur avec 2 feuilles et laisse l'utilisateur
  /// choisir le dossier de destination. Retourne le chemin du fichier.
  static Future<String?> exporterRapportExcel() async {
    try {
      final dossier = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choisissez le dossier pour le rapport Excel',
      );
      if (dossier == null) return null;

      final excel = Excel.createExcel();
      final enTete = CellStyle(bold: true);

      // --- Feuille 1 : Rapport journalier ---
      final feuilleRapport = excel['Rapport journalier'];
      excel.setDefaultSheet('Rapport journalier');
      final colonnes = [
        'Date',
        'Ventes (F)',
        'Dépenses (F)',
        'Encaissé (F)',
        'Bénéfice net (F)',
        'Opérations'
      ];
      feuilleRapport.appendRow(colonnes.map<CellValue?>(TextCellValue.new).toList());
      for (var i = 0; i < colonnes.length; i++) {
        feuilleRapport
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = enTete;
      }

      final rapports = await CommandeRepo().rapportsJournaliers(limitJours: 365);
      for (final r in rapports) {
        feuilleRapport.appendRow([
          TextCellValue(r['jour'] as String? ?? ''),
          DoubleCellValue((r['ventes'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((r['depenses'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((r['encaisse'] as num?)?.toDouble() ?? 0),
          DoubleCellValue((r['benefice'] as num?)?.toDouble() ?? 0),
          IntCellValue((r['operations'] as num?)?.toInt() ?? 0),
        ]);
      }

      // --- Feuille 2 : État du stock ---
      final feuilleStock = excel['État du stock'];
      final colonnesStock = [
        'Marque',
        'Format',
        'Quantité',
        'Seuil alerte',
        'Prix achat (F)',
        'Prix vente (F)',
        'Valeur stock (F)'
      ];
      feuilleStock.appendRow(colonnesStock.map<CellValue?>(TextCellValue.new).toList());
      for (var i = 0; i < colonnesStock.length; i++) {
        feuilleStock
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle = enTete;
      }

      final produits = await ProduitRepo().tous();
      for (final prod in produits) {
        feuilleStock.appendRow([
          TextCellValue(prod.marque),
          TextCellValue(prod.format),
          IntCellValue(prod.quantite),
          IntCellValue(prod.seuilAlerte),
          DoubleCellValue(prod.prixAchat),
          DoubleCellValue(prod.prixVente),
          DoubleCellValue(prod.quantite * prod.prixVente),
        ]);
      }

      excel.delete('Sheet1'); // feuille vide créée par défaut

      final jour = DateTime.now().toIso8601String().substring(0, 10);
      final chemin = p.join(dossier, 'Rapport_Depot_$jour.xlsx');
      final octets = excel.encode();
      if (octets == null) return null;
      await File(chemin).writeAsBytes(octets);
      return chemin;
    } catch (e) {
      debugPrint('Erreur export Excel : $e');
      return null;
    }
  }
}
