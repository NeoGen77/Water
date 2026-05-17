import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_item.dart';

class PdfService {

  // ==========================================
  // 1. FACTURE UNIQUE (Déjà existante)
  // ==========================================
  static Future<void> exporterFacture(TransactionItem trans) async {
    final pdf = pw.Document();

    pw.MemoryImage? imageTampon;
    try {
      final ByteData bytes = await rootBundle.load('assets/tampon.png');
      final Uint8List imageBytes = bytes.buffer.asUint8List();
      imageTampon = pw.MemoryImage(imageBytes);
    } catch (e) {
      debugPrint("Erreur lors du chargement du tampon : $e");
    }

    int prixUnitaire = trans.quantite > 0 ? (trans.montant ~/ trans.quantite) : 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildEnTete('FACTURE', 'FAC-${trans.date.replaceAll('-', '')}-${trans.id ?? "000"}', trans.date),
              pw.SizedBox(height: 40),
              _buildInfosClient(trans.nomClient ?? "Client au comptoir", trans.estPaye ? "RÉGLÉ" : "À CRÉDIT"),
              pw.SizedBox(height: 30),

              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12),
                cellStyle: const pw.TextStyle(fontSize: 12),
                cellAlignment: pw.Alignment.center,
                cellAlignments: {0: pw.Alignment.centerLeft, 3: pw.Alignment.centerRight},
                headers: ['Désignation', 'Quantité', 'Prix Unitaire', 'Montant Total'],
                data: [
                  ['Eau minérale ${trans.marque} (Paquets)', '${trans.quantite}', '$prixUnitaire F', '${trans.montant.toInt()} FCFA'],
                ],
              ),
              pw.SizedBox(height: 40),
              _buildPiedDePage(imageTampon, trans.montant.toInt()),
            ],
          );
        },
      ),
    );

    String clientNettoye = (trans.nomClient ?? "Client").replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String dateNettoyee = trans.date.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Facture_${clientNettoye}_$dateNettoyee.pdf');
  }

  // ==========================================
  // 2. NOUVEAU : RELEVÉ DE COMPTE MULTIPLE
  // ==========================================
  static Future<void> exporterReleveClient(String nomClient, List<TransactionItem> transactions) async {
    final pdf = pw.Document();

    pw.MemoryImage? imageTampon;
    try {
      final ByteData bytes = await rootBundle.load('assets/tampon.png');
      final Uint8List imageBytes = bytes.buffer.asUint8List();
      imageTampon = pw.MemoryImage(imageBytes);
    } catch (e) {
      debugPrint("Erreur tampon : $e");
    }

    // Calculs globaux
    double totalAchat = 0;
    double totalPaye = 0;

    for (var t in transactions) {
      totalAchat += t.montant;
      if (t.estPaye) totalPaye += t.montant;
    }
    double resteAPayer = totalAchat - totalPaye;

    // Préparation des lignes du tableau
    final List<List<String>> lignesTableau = transactions.map((t) {
      int pu = t.quantite > 0 ? (t.montant ~/ t.quantite) : 0;
      return [
        t.date,
        '${t.marque} (${t.quantite} pqt)',
        '$pu F',
        t.estPaye ? 'Payé' : 'Non Payé',
        '${t.montant.toInt()} F'
      ];
    }).toList();

    String dateAujourdhui = DateTime.now().toString().substring(0, 10);

    pdf.addPage(
      pw.MultiPage( // MultiPage permet de créer plusieurs pages automatiquement si le tableau est très long !
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            _buildEnTete('RELEVÉ DE COMPTE', 'REL-${dateAujourdhui.replaceAll('-', '')}', dateAujourdhui),
            pw.SizedBox(height: 40),

            // Infos du Relevé
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
                  pw.Text('Client : $nomClient', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Text('Nombre d\'opérations : ${transactions.length}', style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Tableau des transactions
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.center,
              cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 4: pw.Alignment.centerRight},
              headers: ['Date', 'Articles', 'Prix Un.', 'Statut', 'Montant'],
              data: lignesTableau,
            ),
            pw.SizedBox(height: 30),

            // Bilan Financier du client
            pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                      width: 250,
                      child: pw.Column(
                        children: [
                          _buildLigneBilan('Total des achats :', totalAchat.toInt(), PdfColors.black),
                          pw.Divider(color: PdfColors.grey300),
                          _buildLigneBilan('Total déjà réglé :', totalPaye.toInt(), PdfColors.green700),
                          pw.Divider(color: PdfColors.grey300),
                          _buildLigneBilan('RESTE À PAYER :', resteAPayer.toInt(), resteAPayer > 0 ? PdfColors.red700 : PdfColors.green700, isGras: true),
                        ],
                      )
                  )
                ]
            ),
            pw.SizedBox(height: 40),

            _buildPiedDePage(imageTampon, null), // On passe null car le total est déjà géré au-dessus
          ];
        },
      ),
    );

    String clientNettoye = nomClient.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'Releve_$clientNettoye.pdf');
  }

  // ==========================================
  // COMPOSANTS RÉUTILISABLES (Pour éviter de dupliquer le code)
  // ==========================================

  static pw.Widget _buildEnTete(String titreDoc, String numero, String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('DÉPÔT D\'EAU PRO', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            pw.SizedBox(height: 5),
            pw.Text('Ouagadougou, Burkina Faso', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Téléphone : +226 74 09 66 25', style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: PdfColors.indigo50, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(titreDoc, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.SizedBox(height: 5),
              pw.Text('N° : $numero', style: const pw.TextStyle(fontSize: 12)),
              pw.Text('Date : $date', style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInfosClient(String nom, String statut) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Client : $nom', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text('Statut : $statut', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: statut == "RÉGLÉ" ? PdfColors.green700 : PdfColors.red700)),
        ],
      ),
    );
  }

  static pw.Widget _buildLigneBilan(String libelle, int montant, PdfColor couleur, {bool isGras = false}) {
    return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(libelle, style: pw.TextStyle(fontSize: isGras ? 14 : 12, fontWeight: isGras ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text('$montant FCFA', style: pw.TextStyle(fontSize: isGras ? 16 : 12, fontWeight: pw.FontWeight.bold, color: couleur)),
          ],
        )
    );
  }

  static pw.Widget _buildPiedDePage(pw.MemoryImage? imageTampon, int? netAPayer) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text('La Direction', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.indigo900)),
            pw.SizedBox(height: 10),
            if (imageTampon != null)
              pw.Image(imageTampon, width: 100, height: 100)
            else
              pw.Container(
                width: 150, height: 80,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed), borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Center(child: pw.Text('Cachet / Signature', style: const pw.TextStyle(color: PdfColors.grey500))),
              ),
          ],
        ),
        if (netAPayer != null)
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('NET À PAYER', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
              pw.SizedBox(height: 5),
              pw.Text('$netAPayer FCFA', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            ],
          ),
      ],
    );
  }
}