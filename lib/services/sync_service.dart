import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/db_helper.dart';

class SyncService {
  final _supabase = Supabase.instance.client;
  final _dbHelper = DBHelper();

  // =========================================================================
  // FONCTIONS "MAÎTRE" (À utiliser sur le téléphone du dépôt pour envoyer)
  // =========================================================================

  Future<void> pushToutVersLeCloud() async {
    try {
      print('⏳ Début de la synchronisation vers Supabase...');

      // 1. Synchroniser le Stock Actuel
      final stockLocal = await _dbHelper.getAllItems();
      for (var item in stockLocal) {
        // L'upsert met à jour la ligne si l'ID existe déjà, sinon il la crée
        await _supabase.from('water_items').upsert(item.toMap());
      }
      print('✅ Stock synchronisé !');

      // 2. Synchroniser l'Historique (Les transactions)
      // On charge tout pour être sûr que le cloud est le miroir parfait du téléphone
      final transactionsLocales = await _dbHelper.getAllTransactions(filter: 'Tout', limit: 10000);
      for (var trans in transactionsLocales) {
        await _supabase.from('transactions').upsert(trans.toMap());
      }
      // On n'oublie pas d'envoyer aussi les dettes non payées !
      final dettesLocales = await _dbHelper.getToutesLesDettes();
      for (var dette in dettesLocales) {
        await _supabase.from('transactions').upsert(dette.toMap());
      }
      print('✅ Transactions synchronisées !');

      // 3. Synchroniser les Bilans Journaliers
      final bilansLocaux = await _dbHelper.getHistoriqueBilans();
      for (var bilan in bilansLocaux) {
        await _supabase.from('bilans_journaliers').upsert(bilan);
      }
      print('✅ Bilans synchronisés !');

    } catch (e) {
      print('❌ Erreur critique lors du Push : $e');
    }
  }

  // =========================================================================
  // FONCTIONS "ESCLAVE" (À utiliser sur ton téléphone perso pour lire)
  // =========================================================================

  Future<void> pullToutDepuisLeCloud() async {
    try {
      print('⏳ Téléchargement depuis Supabase...');

      // 1. Récupérer le Stock
      final List<dynamic> stockCloud = await _supabase.from('water_items').select();
      for (var data in stockCloud) {
        Map<String, dynamic> itemMap = Map<String, dynamic>.from(data);
        // On met à jour la base locale avec les données du cloud
        await _dbHelper.updateWaterItemMapSilencieux(itemMap);
      }

      // 2. Récupérer les Transactions
      final List<dynamic> transCloud = await _supabase.from('transactions').select();
      for (var data in transCloud) {
        Map<String, dynamic> transMap = Map<String, dynamic>.from(data);
        await _dbHelper.insertTransactionSilencieux(transMap);
      }

      // 3. Récupérer les Bilans
      final List<dynamic> bilansCloud = await _supabase.from('bilans_journaliers').select();
      for (var data in bilansCloud) {
        Map<String, dynamic> bilanMap = Map<String, dynamic>.from(data);
        await _dbHelper.enregistrerCloture(bilanMap);
      }

      print('✅ Succès : Le téléphone est maintenant un miroir parfait du dépôt !');
    } catch (e) {
      print('❌ Erreur lors du Pull : $e');
    }
  }
}