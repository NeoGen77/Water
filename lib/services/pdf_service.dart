import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/formats.dart';
import '../models/commande.dart';

/// Génération des documents PDF (facture, relevé de compte).
class PdfService {
  // Coordonnées de l'entreprise, centralisées.
  static const nomEntreprise = "DÉPÔT D'EAU AQUA VIIM";
  static const adresseEntreprise = 'Ouagadougou, Burkina Faso';
  static const telephoneEntreprise =
      'Téléphone : +226 74 09 66 25 / 73 64 62 36';

  static Future<pw.MemoryImage?> _chargerTampon() async {
    try {
      // Nom identique à pubspec.yaml (sensible à la casse sur Android).
      final bytes = await rootBundle.load('assets/Tampon.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Tampon indisponible : $e');
      return null;
    }
  }

  // ==========================================================
  // 1. FACTURE D'UNE COMMANDE
  // ==========================================================
  static Future<void> exporterFacture(
      Commande commande, List<LigneCommande> lignes) async {
    final pdf = pw.Document();
    final tampon = await _chargerTampon();

    final lignesTableau = lignes
        .map((l) => [
              'Eau minérale ${l.marque} (Paquets)',
              '${l.quantite}',
              fmtFcfa(l.prixUnitaire),
              fmtFcfaLong(l.montant),
            ])
        .toList();

    final statut = commande.estSoldee
        ? 'RÉGLÉ'
        : (commande.totalPaye > 0 ? 'PARTIELLEMENT RÉGLÉ' : 'À CRÉDIT');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _enTete('FACTURE', commande.numero, fmtDate(commande.date)),
            pw.SizedBox(height: 40),
            _blocClient(commande.clientNom ?? 'Client au comptoir', statut),
            pw.SizedBox(height: 30),
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12),
              cellStyle: const pw.TextStyle(fontSize: 12),
              cellAlignment: pw.Alignment.center,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight
              },
              headers: ['Désignation', 'Quantité', 'Prix Unitaire', 'Montant Total'],
              data: lignesTableau,
            ),
            if (commande.totalPaye > 0 && !commande.estSoldee) ...[
              pw.SizedBox(height: 15),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(children: [
                    _ligneBilan('Déjà réglé :', commande.totalPaye, PdfColors.green700),
                    pw.Divider(color: PdfColors.grey300),
                    _ligneBilan('Reste à payer :', commande.resteAPayer,
                        PdfColors.red700,
                        isGras: true),
                  ]),
                ),
              ]),
            ],
            pw.SizedBox(height: 40),
            _piedDePage(tampon, commande.total),
          ],
        ),
      ),
    );

    final nomFichier =
        'Facture_${commande.numero}'.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await Printing.sharePdf(bytes: await pdf.save(), filename: '$nomFichier.pdf');
  }

  // ==========================================================
  // 2. RELEVÉ DE COMPTE CLIENT (dettes en cours)
  // ==========================================================
  static Future<void> exporterReleveClient(
      String nomClient, List<Commande> dettes) async {
    final pdf = pw.Document();
    final tampon = await _chargerTampon();

    double totalAchat = 0, totalPaye = 0;
    for (final c in dettes) {
      totalAchat += c.total;
      totalPaye += c.totalPaye;
    }
    final reste = totalAchat - totalPaye;

    final lignesTableau = dettes
        .map((c) => [
              fmtDateCourte(c.date),
              c.numero,
              fmtFcfa(c.total),
              fmtFcfa(c.totalPaye),
              fmtFcfa(c.resteAPayer),
            ])
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _enTete('RELEVÉ DE COMPTE', 'REL-${todayKey().replaceAll('-', '')}',
              fmtDateCourte(nowIso())),
          pw.SizedBox(height: 40),
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.grey100,
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Client : $nomClient',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900)),
                pw.Text('Factures en cours : ${dettes.length}',
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
          pw.SizedBox(height: 30),
          pw.TableHelper.fromTextArray(
            context: context,
            border: pw.TableBorder.all(color: PdfColors.grey300),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.center,
            cellAlignments: {0: pw.Alignment.centerLeft, 4: pw.Alignment.centerRight},
            headers: ['Date', 'Facture N°', 'Montant', 'Déjà réglé', 'Reste dû'],
            data: lignesTableau,
          ),
          pw.SizedBox(height: 30),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              width: 250,
              child: pw.Column(children: [
                _ligneBilan('Total des achats :', totalAchat, PdfColors.black),
                pw.Divider(color: PdfColors.grey300),
                _ligneBilan('Total déjà réglé :', totalPaye, PdfColors.green700),
                pw.Divider(color: PdfColors.grey300),
                _ligneBilan('RESTE À PAYER :', reste,
                    reste > 0 ? PdfColors.red700 : PdfColors.green700,
                    isGras: true),
              ]),
            ),
          ]),
          pw.SizedBox(height: 40),
          _piedDePage(tampon, null),
        ],
      ),
    );

    final nomNettoye = nomClient.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await Printing.sharePdf(
        bytes: await pdf.save(), filename: 'Releve_$nomNettoye.pdf');
  }

  // ==========================================================
  // COMPOSANTS RÉUTILISABLES
  // ==========================================================
  static pw.Widget _enTete(String titreDoc, String numero, String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(nomEntreprise,
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900)),
            pw.SizedBox(height: 5),
            pw.Text(adresseEntreprise, style: const pw.TextStyle(fontSize: 12)),
            pw.Text(telephoneEntreprise, style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
              color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(titreDoc,
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900)),
              pw.SizedBox(height: 5),
              pw.Text('N° : $numero', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Date : $date', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _blocClient(String nom, String statut) {
    final couleur = statut == 'RÉGLÉ' ? PdfColors.green700 : PdfColors.red700;
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Client : $nom',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Statut : $statut',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold, color: couleur)),
        ],
      ),
    );
  }

  static pw.Widget _ligneBilan(String libelle, double montant, PdfColor couleur,
      {bool isGras = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(libelle,
              style: pw.TextStyle(
                  fontSize: isGras ? 14 : 12,
                  fontWeight: isGras ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(fmtFcfaLong(montant),
              style: pw.TextStyle(
                  fontSize: isGras ? 16 : 12,
                  fontWeight: pw.FontWeight.bold,
                  color: couleur)),
        ],
      ),
    );
  }

  static pw.Widget _piedDePage(pw.MemoryImage? tampon, double? netAPayer) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('La Direction',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                    color: PdfColors.indigo900)),
            pw.SizedBox(height: 10),
            if (tampon != null)
              pw.Image(tampon, width: 100, height: 100)
            else
              pw.Container(
                width: 150,
                height: 80,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                    borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Center(
                    child: pw.Text('Cachet / Signature',
                        style: const pw.TextStyle(color: PdfColors.grey500))),
              ),
          ],
        ),
        if (netAPayer != null)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('NET À PAYER',
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
              pw.SizedBox(height: 5),
              pw.Text(fmtFcfaLong(netAPayer),
                  style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900)),
            ],
          ),
      ],
    );
  }
}
