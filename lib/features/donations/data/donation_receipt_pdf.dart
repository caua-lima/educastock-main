import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/export/report_exporter.dart';
import '../domain/entities/donation.dart';
import '../domain/entities/donation_point.dart';

/// Recibo de doação e relatório de impacto em PDF (tabela dos itens aceitos + dados da ONG).
///
/// É um **comprovante de recebimento da ONG**; o recibo para fins fiscais depende de
/// requisitos legais e contábeis da instituição (RN-D12) e por isso o texto não o
/// declara como tal.
class DonationReceiptPdf {
  const DonationReceiptPdf._();

  static Future<Uint8List> build(
    Donation donation, {
    DonationPoint? point,
    DateTime? now,
  }) async {
    final date = DateFormat('dd/MM/yyyy');
    final dateTime = DateFormat('dd/MM/yyyy HH:mm');
    final issuedAt = dateTime.format(now ?? DateTime.now());

    const blue = PdfColor.fromInt(0xFF1D5FA8);
    const green = PdfColor.fromInt(0xFF2E7D32);
    const grey = PdfColor.fromInt(0xFF6B7280);
    const light = PdfColor.fromInt(0xFFEFF6FF);

    // Linhas da tabela: prometido x conferido (quando houver conferência).
    final received = {for (final r in donation.receivedItems) r.index: r};
    final rows = <List<String>>[];
    for (var i = 0; i < donation.items.length; i++) {
      final item = donation.items[i];
      final info = received[i];
      final accepted = info?.receivedQty ?? item.quantity;
      if (accepted <= 0) continue;
      rows.add([
        pdfSafeText(item.description),
        '${item.quantity} ${pdfSafeText(item.unit)}',
        '$accepted ${pdfSafeText(item.unit)}',
        item.hasExpiry && item.expiryDate != null ? date.format(item.expiryDate!) : 'Sem validade',
      ]);
    }
    final impact = donation.impact;
    final receivedAt = donation.receivedAt;

    final doc = pw.Document(
      title: 'Recibo de doação ${donation.displayProtocol}',
      author: kOrgName,
      creator: 'EducaStock',
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 44),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Emitido em $issuedAt - Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: grey),
          ),
        ),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: const pw.BoxDecoration(
              color: blue,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(kOrgName,
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(kOrgSubtitle,
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Text('Recibo de doação',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Protocolo ${donation.displayProtocol}',
              style: pw.TextStyle(fontSize: 12, color: blue, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: light,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _line('Doador', pdfSafeText(donation.donorSnapshot.displayName)),
                _line('Situação', donation.status.label),
                if (receivedAt != null) _line('Recebida em', dateTime.format(receivedAt)),
                if (point != null) _line('Ponto de recebimento', pdfSafeText('${point.name} - ${point.address}')),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Itens aceitos',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Item', 'Prometido', 'Aceito', 'Validade'],
            data: rows,
            headerStyle:
                pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: blue),
            cellStyle: const pw.TextStyle(fontSize: 10),
            oddRowDecoration: const pw.BoxDecoration(color: light),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: null,
          ),
          if (impact != null) ...[
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: green, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Relatório de impacto',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold, color: green)),
                  pw.SizedBox(height: 6),
                  _line('Destino', pdfSafeText(impact.sector)),
                  if (impact.usedAt != null) _line('Data de utilização', date.format(impact.usedAt!)),
                  pw.SizedBox(height: 4),
                  pw.Text(pdfSafeText(impact.message), style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 22),
          pw.Text(
            'Este documento comprova o recebimento dos itens acima pela $kOrgName. '
            'Não substitui recibo para fins fiscais.',
            style: const pw.TextStyle(fontSize: 9, color: grey),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static pw.Widget _line(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                  text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );

  /// Gera e entrega o recibo (download na web, folha de compartilhamento no celular).
  static Future<void> share(Donation donation, {DonationPoint? point}) async {
    final bytes = await build(donation, point: point);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'recibo_${donation.displayProtocol.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_')}.pdf',
    );
  }
}
