import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../database/db_helper.dart'; // NOUVEAU
import 'package:flutter/foundation.dart';

class BackupService {
  // Nom de la base de données (doit être identique à celui de DBHelper)
  static const String _dbName = 'water_stock_v7.db';

  // ==========================================================
  // ACTION 1 : SAUVEGARDER (Créer une copie dans le téléphone)
  // ==========================================================
  static Future<bool> creerCopieLocale() async {
    try {
      // 1. Localiser le fichier de la base de données active
      final dbPath = await getDatabasesPath();
      final pathOriginal = join(dbPath, _dbName);
      final fichierOriginal = File(pathOriginal);

      if (!await fichierOriginal.exists()) {
        debugPrint("Erreur : La base de données source est introuvable.");
        return false;
      }

      // 2. Demander à l'utilisateur de choisir l'emplacement de sauvegarde
      String? dossierChoisi = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Sélectionnez le dossier pour enregistrer la sauvegarde',
      );

      if (dossierChoisi != null) {
        // 3. Préparer le nouveau nom de fichier (ex: Sauvegarde_Depot_2026-05-15.db)
        String horodatage = DateTime.now().toString().substring(0, 10);
        String cheminDestination = join(dossierChoisi, 'Sauvegarde_Depot_$horodatage.db');

        // 4. Effectuer la copie physique
        await fichierOriginal.copy(cheminDestination);
        return true;
      }
      return false; // L'utilisateur a annulé le choix du dossier
    } catch (e) {
      debugPrint("Erreur lors de la création de la sauvegarde : $e");
      return false;
    }
  }

  // ==========================================================
  // ACTION 2 : RESTAURER (Remplacer la base par une copie)
  // ==========================================================
  // ==========================================================
  // ACTION 2 : RESTAURER (Remplacer la base par une copie)
  // ==========================================================
  static Future<bool> restaurerCopieLocale() async {
    try {
      // 1. Demander à l'utilisateur de choisir le fichier .db de sauvegarde
      FilePickerResult? resultat = await FilePicker.platform.pickFiles(
        dialogTitle: 'Sélectionnez le fichier de sauvegarde à restaurer',
        type: FileType.any,
      );

      if (resultat != null && resultat.files.single.path != null) {
        final cheminSauvegarde = resultat.files.single.path!;

        // Vérification de l'extension par sécurité
        if (!cheminSauvegarde.endsWith('.db')) {
          debugPrint("Erreur : Le fichier sélectionné n'est pas une base de données .db");
          return false;
        }

        File fichierSauvegarde = File(cheminSauvegarde);

        // 2. Définir le chemin de destination (le dossier privé de l'app)
        final dbPath = await getDatabasesPath();
        final pathDestination = join(dbPath, _dbName);

        // --- LA CORRECTION EST ICI ---
        // 3. FERMER LA BASE DE DONNÉES ACTIVE AVANT D'ÉCRASER
        await DBHelper().fermerBaseDeDonnees();

        // 4. Écraser l'ancienne base par la nouvelle
        await fichierSauvegarde.copy(pathDestination);

        return true;
      }
      return false; // L'utilisateur a annulé
    } catch (e) {
      debugPrint("Erreur lors de la restauration des données : $e");
      return false;
    }
  }
}