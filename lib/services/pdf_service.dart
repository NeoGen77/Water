import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/transaction_item.dart';
import 'package:flutter/services.dart'; // Indispensable pour lire le dossier assets
import 'dart:typed_data'; // Pour manipuler les bytes de l'image

class PdfService {

  static Future<void> exporterFacture(TransactionItem trans) async {
    final pdf = pw.Document();

    // Calcul du prix unitaire
    int prixUnitaire = trans.quantite > 0 ? (trans.montant ~/ trans.quantite) : 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- EN-TÊTE ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DÉPÔT D\'EAU ', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.SizedBox(height: 5),
                      pw.Text('Ouagadougou, Burkina Faso', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('Téléphone : +226 74 09 66 25', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.indigo50,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('FACTURE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                        pw.SizedBox(height: 5),
                        pw.Text('N° : FAC-${trans.date.replaceAll('-', '')}-${trans.id ?? "000"}', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Date : ${trans.date}', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 40),

              // --- INFOS CLIENT ---
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Client : ${trans.nomClient ?? "Client au comptoir"}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      'Statut : ${trans.estPaye ? "RÉGLÉ" : "À CRÉDIT"}',
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: trans.estPaye ? PdfColors.green700 : PdfColors.red700
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // --- TABLEAU DES ARTICLES ---
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12),
                cellStyle: const pw.TextStyle(fontSize: 12),
                cellAlignment: pw.Alignment.center,
                cellAlignments: {
                  0: pw.Alignment.centerLeft, // Désignation à gauche
                  3: pw.Alignment.centerRight, // Total à droite
                },
                headers: ['Désignation', 'Quantité', 'Prix Unitaire', 'Montant Total'],
                data: [
                  [
                    'Eau minérale ${trans.marque} (Paquets)',
                    '${trans.quantite}',
                    '$prixUnitaire F',
                    '${trans.montant.toInt()} FCFA'
                  ],
                ],
              ),
              pw.SizedBox(height: 40),

              // --- PIED DE PAGE & CACHET ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Zone de signature / cachet
                  pw.Container(
                    width: 200,
                    height: 100,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Text('Cachet et Signature', style: const pw.TextStyle(color: PdfColors.grey500)),
                    ),
                  ),

                  // Total à payer
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('NET À PAYER', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey600)),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        '${trans.montant.toInt()} FCFA',
                        style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

// 1. On nettoie le nom du client et la date pour enlever les caractères interdits par Windows/Android
    // On remplace les caractères spéciaux (\ / : * ? " < > |) par un tiret bas (_)
    String clientNettoye = (trans.nomClient ?? "Client").replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    String dateNettoyee = trans.date.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');

    // 2. On génère un nom de fichier 100% valide
    String nomDuFichier = 'Facture_${clientNettoye}_$dateNettoyee.pdf';

    // 3. On lance le partage
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: nomDuFichier,
    );
  }
}