import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:waterstock/data/app_database.dart';
import 'package:waterstock/data/client_repo.dart';
import 'package:waterstock/data/commande_repo.dart';
import 'package:waterstock/data/produit_repo.dart';
import 'package:waterstock/models/commande.dart';
import 'package:waterstock/models/produit.dart';

void main() {
  late Directory tempDir;
  final produitRepo = ProduitRepo();
  final commandeRepo = CommandeRepo();
  final clientRepo = ClientRepo();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('depot_test');
    await databaseFactory.setDatabasesPath(tempDir.path);
  });

  tearDown(() async {
    await AppDatabase.fermer();
    await tempDir.delete(recursive: true);
  });

  Future<int> creerProduit({int stock = 50}) async {
    return produitRepo.creer(Produit(
      marque: 'Lafi',
      format: 'Paquet 24x 500ml',
      quantite: stock,
      seuilAlerte: 10,
      prixAchat: 1000,
      prixVente: 1500,
    ));
  }

  LigneCommande ligne(int produitId, {int qte = 5}) => LigneCommande(
        produitId: produitId,
        marque: 'Lafi',
        quantite: qte,
        prixUnitaire: 1500,
        montant: qte * 1500,
        benefice: qte * 500,
      );

  test('vente admin comptant : stock décrémenté et facture soldée', () async {
    final produitId = await creerProduit();

    final numero = await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId)],
      estPayeComptant: true,
      isAdmin: true,
    );

    expect(numero, startsWith('VEN-'));

    final produits = await produitRepo.tous();
    expect(produits.single.quantite, 45);

    final historique = await commandeRepo.historique();
    final cmd = historique.single;
    expect(cmd.total, 7500);
    expect(cmd.benefice, 2500);
    expect(cmd.estSoldee, isTrue);
  });

  test('vente à crédit : paiements partiels jusqu\'au solde', () async {
    final produitId = await creerProduit();
    final clientId = await clientRepo.trouverOuCreer('Ali');

    await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId)],
      clientId: clientId,
      estPayeComptant: false,
      isAdmin: true,
    );

    var dettes = await commandeRepo.dettesDuClient(clientId);
    expect(dettes.single.resteAPayer, 7500);

    // Paiement partiel
    await commandeRepo.encaisser(dettes.single.id!, 3000);
    dettes = await commandeRepo.dettesDuClient(clientId);
    expect(dettes.single.resteAPayer, 4500);
    expect(dettes.single.totalPaye, 3000);

    // Refus d'un encaissement supérieur au reste
    expect(() => commandeRepo.encaisser(dettes.single.id!, 99999),
        throwsStateError);

    // Solde final : plus de dette
    await commandeRepo.encaisser(dettes.single.id!, 4500);
    dettes = await commandeRepo.dettesDuClient(clientId);
    expect(dettes, isEmpty);
    expect(await commandeRepo.totalDettes(), 0);
  });

  test('vente secrétaire : en attente sans toucher le stock, puis validée',
      () async {
    final produitId = await creerProduit();

    await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId)],
      estPayeComptant: true,
      isAdmin: false,
    );

    // Stock intact tant que non validée
    expect((await produitRepo.tous()).single.quantite, 50);
    final enAttente = await commandeRepo.enAttente();
    expect(enAttente.single.statut, Commande.statutEnAttente);

    await commandeRepo.validerCommande(enAttente.single.id!);

    expect((await produitRepo.tous()).single.quantite, 45);
    // L'intention "comptant" de la secrétaire a créé le paiement
    final cmd = (await commandeRepo.historique()).single;
    expect(cmd.estSoldee, isTrue);
  });

  test('stock insuffisant : la commande est refusée sans rien écrire',
      () async {
    final produitId = await creerProduit(stock: 3);

    expect(
      () => commandeRepo.creerCommande(
        type: Commande.typeVente,
        lignes: [ligne(produitId, qte: 5)],
        estPayeComptant: true,
        isAdmin: true,
      ),
      throwsStateError,
    );

    expect((await produitRepo.tous()).single.quantite, 3);
    expect(await commandeRepo.historique(), isEmpty);
  });

  test('annulation : le stock est restauré et tout est supprimé', () async {
    final produitId = await creerProduit();

    await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId)],
      estPayeComptant: true,
      isAdmin: true,
    );
    final cmd = (await commandeRepo.historique()).single;

    await commandeRepo.annulerCommande(cmd.id!);

    expect((await produitRepo.tous()).single.quantite, 50);
    expect(await commandeRepo.historique(), isEmpty);
    expect(await commandeRepo.paiementsDe(cmd.id!), isEmpty);
  });

  test('ravitaillement : le stock augmente et compte en dépense', () async {
    final produitId = await creerProduit(stock: 10);

    await commandeRepo.creerCommande(
      type: Commande.typeRavitaillement,
      lignes: [
        LigneCommande(
          produitId: produitId,
          marque: 'Lafi',
          quantite: 20,
          prixUnitaire: 1000,
          montant: 20000,
          benefice: 0,
        ),
      ],
      estPayeComptant: true,
      isAdmin: true,
    );

    expect((await produitRepo.tous()).single.quantite, 30);
    final bilan = await commandeRepo.bilan();
    expect(bilan['depenses'], 20000);
    expect(bilan['ventes'], 0);
  });

  test('clients : pas de doublons Ali/ali/ALI', () async {
    final id1 = await clientRepo.trouverOuCreer('Ali');
    final id2 = await clientRepo.trouverOuCreer('ali');
    final id3 = await clientRepo.trouverOuCreer('ALI');
    expect(id1, id2);
    expect(id2, id3);
    expect((await clientRepo.tous()).length, 1);
  });
}
