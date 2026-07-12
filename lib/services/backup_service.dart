import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';

class BackupService {
  static const _nbSauvegardesConservees = 14;

  static Future<String> _cheminBase() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, AppDatabase.dbName);
  }

  // ==========================================================
  // SAUVEGARDE AUTOMATIQUE QUOTIDIENNE
  // Appelée au lancement : une copie par jour, les 14 dernières
  // sont conservées dans Documents/SauvegardesDepotEau.
  // ==========================================================
  static Future<void> sauvegardeAutomatique() async {
    try {
      final original = File(await _cheminBase());
      if (!await original.exists()) return;

      final docs = await getApplicationDocumentsDirectory();
      final dossier = Directory(join(docs.path, 'SauvegardesDepotEau'));
      await dossier.create(recursive: true);

      final jour = DateTime.now().toIso8601String().substring(0, 10);
      final destination = File(join(dossier.path, 'Auto_$jour.db'));
      if (await destination.exists()) return; // déjà faite aujourd'hui

      await original.copy(destination.path);

      // Purge des anciennes copies automatiques
      final copies = dossier
          .listSync()
          .whereType<File>()
          .where((f) => basename(f.path).startsWith('Auto_'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final vieille in copies.skip(_nbSauvegardesConservees)) {
        await vieille.delete();
      }
      debugPrint('✅ Sauvegarde automatique du $jour créée.');
    } catch (e) {
      debugPrint('⚠️ Sauvegarde automatique impossible : $e');
    }
  }

  // ==========================================================
  // SAUVEGARDE MANUELLE (l'utilisateur choisit le dossier)
  // ==========================================================
  static Future<bool> creerCopieLocale() async {
    try {
      final original = File(await _cheminBase());
      if (!await original.exists()) return false;

      final dossierChoisi = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Sélectionnez le dossier pour enregistrer la sauvegarde',
      );
      if (dossierChoisi == null) return false;

      final jour = DateTime.now().toIso8601String().substring(0, 10);
      await original.copy(join(dossierChoisi, 'Sauvegarde_Depot_$jour.db'));
      return true;
    } catch (e) {
      debugPrint('Erreur lors de la sauvegarde : $e');
      return false;
    }
  }

  // ==========================================================
  // RESTAURATION
  // ==========================================================
  static Future<bool> restaurerCopieLocale() async {
    try {
      final resultat = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sélectionnez le fichier de sauvegarde à restaurer',
        type: FileType.any,
      );
      final chemin = resultat?.files.single.path;
      if (chemin == null || !chemin.endsWith('.db')) return false;

      await AppDatabase.fermer();
      await File(chemin).copy(await _cheminBase());
      return true;
    } catch (e) {
      debugPrint('Erreur lors de la restauration : $e');
      return false;
    }
  }
}
