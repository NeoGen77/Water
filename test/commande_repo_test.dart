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

  test('rythme de vente : quantités des 14 derniers jours par produit',
      () async {
    final produitId = await creerProduit();

    await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId, qte: 5)],
      estPayeComptant: true,
      isAdmin: true,
    );
    await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId, qte: 3)],
      estPayeComptant: true,
      isAdmin: true,
    );

    final ventes = await commandeRepo.quantitesVenduesParProduit(jours: 14);
    expect(ventes[produitId], 8);

    // Une commande EN_ATTENTE ne compte pas dans le rythme
    await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId, qte: 10)],
      estPayeComptant: true,
      isAdmin: false,
    );
    final ventesApres =
        await commandeRepo.quantitesVenduesParProduit(jours: 14);
    expect(ventesApres[produitId], 8);
    expect(await commandeRepo.nombreEnAttente(), 1);
  });

  test('bilan par période : bornes début incluse / fin exclue', () async {
    final produitId = await creerProduit();
    await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId)],
      estPayeComptant: true,
      isAdmin: true,
    );

    final demain =
        DateTime.now().add(const Duration(days: 1)).toIso8601String();
    final hier =
        DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

    final dedans = await commandeRepo.bilanPeriode(hier, demain);
    expect(dedans['ventes'], 7500);
    expect(dedans['benefices'], 2500);

    // Période entièrement passée : rien
    final avant = await commandeRepo.bilanPeriode(
        DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        hier);
    expect(avant['ventes'], 0);
  });

  test('dettes anciennes : seules les dettes assez vieilles remontent',
      () async {
    final produitId = await creerProduit();
    final clientId = await clientRepo.trouverOuCreer('Moussa');

    await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId)],
      clientId: clientId,
      estPayeComptant: false,
      isAdmin: true,
    );

    // La dette date d'aujourd'hui : rien à relancer à 15 jours
    expect(await commandeRepo.dettesAnciennes(joursMin: 15), isEmpty);
    // ... mais elle apparaît avec un seuil à 0 jour
    final relances = await commandeRepo.dettesAnciennes(joursMin: 0);
    expect(relances.single['client_nom'], 'Moussa');
    expect((relances.single['reste'] as num).toDouble(), 7500);
  });

  test('numérotation : une annulation ne fait pas reculer le compteur',
      () async {
    final produitId = await creerProduit(stock: 500);

    Future<String> vendre() => commandeRepo.creerCommande(
          type: Commande.typeVente,
          lignes: [ligne(produitId, qte: 1)],
          estPayeComptant: true,
          isAdmin: true,
        );

    final n1 = await vendre();
    final n2 = await vendre();
    expect(n1, endsWith('-0001'));
    expect(n2, endsWith('-0002'));

    // On annule la première : le numéro 0001 est libéré...
    final premiere =
        (await commandeRepo.historique()).firstWhere((c) => c.numero == n1);
    await commandeRepo.annulerCommande(premiere.id!);

    // ... mais la vente suivante ne doit pas le réutiliser (collision UNIQUE).
    final n3 = await vendre();
    expect(n3, endsWith('-0003'));

    final numeros = (await commandeRepo.historique()).map((c) => c.numero);
    expect(numeros.toSet().length, numeros.length);
  });

  test('numérotation : un rejet de commande en attente ne crée pas de doublon',
      () async {
    final produitId = await creerProduit(stock: 500);

    Future<String> saisir({required bool isAdmin}) =>
        commandeRepo.creerCommande(
          type: Commande.typeVente,
          lignes: [ligne(produitId, qte: 1)],
          estPayeComptant: true,
          isAdmin: isAdmin,
        );

    // La secrétaire saisit deux commandes, l'admin rejette la première.
    final n1 = await saisir(isAdmin: false);
    await saisir(isAdmin: false);
    final rejetee =
        (await commandeRepo.enAttente()).firstWhere((c) => c.numero == n1);
    await commandeRepo.rejeterCommande(rejetee.id!);

    // La saisie suivante doit passer sans collision.
    final n3 = await saisir(isAdmin: false);
    expect(n3, endsWith('-0003'));

    final numeros = (await commandeRepo.enAttente()).map((c) => c.numero);
    expect(numeros.toSet().length, numeros.length);
  });

  test('numérotation : le compteur du jour repart à 1 si tout a été supprimé',
      () async {
    final produitId = await creerProduit(stock: 500);

    final n1 = await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId, qte: 1)],
      estPayeComptant: true,
      isAdmin: true,
    );
    final cmd =
        (await commandeRepo.historique()).firstWhere((c) => c.numero == n1);
    await commandeRepo.annulerCommande(cmd.id!);

    // Comportement assumé : plus aucune commande du jour en base, donc
    // aucun risque de collision — le numéro 0001 redevient disponible.
    final n2 = await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId, qte: 1)],
      estPayeComptant: true,
      isAdmin: true,
    );
    expect(n2, endsWith('-0001'));
  });

  test('numérotation : ventes et ravitaillements comptent séparément',
      () async {
    final produitId = await creerProduit(stock: 500);

    final vente = await commandeRepo.creerCommande(
      type: Commande.typeVente,
      lignes: [ligne(produitId, qte: 1)],
      estPayeComptant: true,
      isAdmin: true,
    );
    final ravito = await commandeRepo.creerCommande(
      type: Commande.typeRavitaillement,
      lignes: [
        LigneCommande(
          produitId: produitId,
          marque: 'Lafi',
          quantite: 10,
          prixUnitaire: 1000,
          montant: 10000,
          benefice: 0,
        ),
      ],
      estPayeComptant: true,
      isAdmin: true,
    );

    expect(vente, startsWith('VEN-'));
    expect(vente, endsWith('-0001'));
    expect(ravito, startsWith('RAV-'));
    expect(ravito, endsWith('-0001'));
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
