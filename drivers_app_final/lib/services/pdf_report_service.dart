// import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
// import '../models/trip_details.dart';

class PdfReportService {
  /// Générer et afficher/imprimer un rapport de gains en PDF
  static Future<void> generateEarningsReport({
    required String driverName,
    required double totalEarnings,
    required int totalTrips,
    required List<Map<String, dynamic>> recentTrips,
  }) async {
    final pdf = pw.Document();

    // Format de date: JJ/MM/AAAA
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateFormat('dd/MM/yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // ─── Header ───
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('LE BON TAXI',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#6366F1'),
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        )),
                    pw.SizedBox(height: 4),
                    pw.Text('Rapport de Gains - Chauffeur',
                        style: const pw.TextStyle(
                            color: PdfColors.grey700, fontSize: 14)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date : $now',
                        style: const pw.TextStyle(fontSize: 12)),
                    pw.SizedBox(height: 4),
                    pw.Text('Chauffeur : $driverName',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 40),

            // ─── Sommaire (Résumé des gains) ───
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F3F4F6'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Gains Totaux',
                      '${totalEarnings.toStringAsFixed(0)} HTG'),
                  _buildSummaryItem('Courses Effectuées', '$totalTrips'),
                ],
              ),
            ),

            pw.SizedBox(height: 40),
            pw.Text('Historique récent',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // ─── Tableau des courses ───
            if (recentTrips.isEmpty)
              pw.Text('Aucune course récente.',
                  style: const pw.TextStyle(color: PdfColors.grey600))
            else
              pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // Date
                  1: const pw.FlexColumnWidth(3), // Départ
                  2: const pw.FlexColumnWidth(3), // Arrivée
                  3: const pw.FlexColumnWidth(1.5), // Montant
                },
                children: [
                  // En-tête
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex('#E5E7EB')),
                    children: [
                      _buildTableCellHeader('Date'),
                      _buildTableCellHeader('Départ'),
                      _buildTableCellHeader('Arrivée'),
                      _buildTableCellHeader('Montant (HTG)'),
                    ],
                  ),
                  // Lignes
                  for (final trip in recentTrips)
                    pw.TableRow(
                      children: [
                        _buildTableCell(
                          trip['created_at'] != null
                              ? dateFormat.format(
                                  DateTime.parse(trip['created_at'].toString()))
                              : '—',
                        ),
                        _buildTableCell(
                            trip['pickup_address']?.toString() ?? '—'),
                        _buildTableCell(
                            trip['dropoff_address']?.toString() ?? '—'),
                        _buildTableCell(
                          trip['fare_amount'] != null
                              ? '${double.parse(trip['fare_amount'].toString()).toStringAsFixed(0)}'
                              : '—',
                          alignRight: true,
                        ),
                      ],
                    ),
                ],
              ),

            pw.SizedBox(height: 40),

            // ─── Footer ───
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Généré automatiquement par Le Bon Taxi',
                    style: const pw.TextStyle(
                        color: PdfColors.grey500, fontSize: 10)),
              ],
            ),
          ];
        },
      ),
    );

    // Aperçu et partag/impression
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Rapport_Gains_LeBonTaxi_$now.pdf',
    );
  }

  static pw.Widget _buildSummaryItem(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(title,
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 12)),
        pw.SizedBox(height: 4),
        pw.Text(value,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
      ],
    );
  }

  static pw.Widget _buildTableCellHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool alignRight = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment:
          alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }
}
