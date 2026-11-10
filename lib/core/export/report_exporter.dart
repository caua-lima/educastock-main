import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'entregar_arquivos.dart';
import 'report_table.dart';

/// Nome da instituição que assina os documentos exportados.
const String kOrgName = 'Casa da Criança';
const String kOrgSubtitle = 'EducaStock - Gestão de doações e estoque';

/// Deixa o texto seguro para as fontes padrão do PDF (Helvetica), que só cobrem
/// Latin-1: mantém acentos e cedilha, troca travessões, aspas curvas e reticências por
/// equivalentes simples e substitui emojis e símbolos fora do alcance por `?`.
String pdfSafeText(String text) {
  const map = {
    0x2013: '-', // –
    0x2014: '-', // —
    0x2212: '-', // −
    0x2026: '...', // …
    0x2018: "'",
    0x2019: "'",
    0x201C: '"',
    0x201D: '"',
    0x2022: '-', // •
    0x2264: '<=',
    0x2265: '>=',
  };
  final out = StringBuffer();
  for (final rune in text.runes) {
    if (rune <= 0xFF) {
      out.writeCharCode(rune);
    } else {
      out.write(map[rune] ?? '?');
    }
  }
  return out.toString();
}

/// Gera e entrega relatórios em PDF, Excel (.xlsx) e CSV.
///
/// Funciona no celular **e na web** (não usa `dart:io` nem pastas temporárias): os
/// arquivos são montados em memória e entregues pela folha de compartilhamento
/// (celular) ou como download (web).
class ReportExporter {
  const ReportExporter._();

  // ─── Geração (funções puras, testáveis) ───────────────────────────────────

  /// CSV pronto para o Excel em português: separador `;`, quebras `\r\n` e BOM UTF-8
  /// (sem o BOM os acentos aparecem quebrados ao abrir com duplo clique).
  static Uint8List buildCsv(ReportTable table) {
    final buffer = StringBuffer();
    String esc(String v) {
      final needsQuotes = v.contains(';') || v.contains('"') || v.contains('\n') || v.contains('\r');
      final safe = v.replaceAll('"', '""');
      return needsQuotes ? '"$safe"' : safe;
    }

    buffer.write('${esc(table.title)}\r\n');
    for (final e in table.summary.entries) {
      buffer.write('${esc(e.key)};${esc(e.value)}\r\n');
    }
    if (table.summary.isNotEmpty) buffer.write('\r\n');
    buffer.write('${table.headers.map(esc).join(';')}\r\n');
    for (final row in table.rows) {
      buffer.write('${row.map(esc).join(';')}\r\n');
    }
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
  }

  static Uint8List buildXlsx(ReportTable table) {
    final book = xl.Excel.createExcel();
    final defaultSheet = book.getDefaultSheet();
    const sheetName = 'Relatório';
    if (defaultSheet != null) book.rename(defaultSheet, sheetName);
    final sheet = book[sheetName];

    var rowIndex = 0;
    void put(int col, String value, {bool bold = false}) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      cell.value = xl.TextCellValue(value);
      if (bold) cell.cellStyle = xl.CellStyle(bold: true);
    }

    put(0, table.title, bold: true);
    rowIndex++;
    if (table.subtitle != null) {
      put(0, table.subtitle!);
      rowIndex++;
    }
    for (final e in table.summary.entries) {
      put(0, e.key, bold: true);
      put(1, e.value);
      rowIndex++;
    }
    if (table.summary.isNotEmpty || table.subtitle != null) rowIndex++;
    for (var c = 0; c < table.headers.length; c++) {
      put(c, table.headers[c], bold: true);
    }
    rowIndex++;
    for (final row in table.rows) {
      for (var c = 0; c < row.length; c++) {
        put(c, row[c]);
      }
      rowIndex++;
    }
    for (var c = 0; c < table.headers.length; c++) {
      sheet.setColumnWidth(c, 22);
    }
    // encode(): só gera os bytes. save() também baixa "FlutterExcel.xlsx" sozinho na web.
    final bytes = book.encode();
    if (bytes == null) throw StateError('Não foi possível gerar o arquivo Excel.');
    return Uint8List.fromList(bytes);
  }

  /// PDF A4 com cabeçalho da ONG, indicadores, tabela paginada e rodapé numerado.
  static Future<Uint8List> buildPdf(ReportTable original, {DateTime? now}) async {
    final table = ReportTable(
      title: pdfSafeText(original.title),
      subtitle: original.subtitle == null ? null : pdfSafeText(original.subtitle!),
      summary: {for (final e in original.summary.entries) pdfSafeText(e.key): pdfSafeText(e.value)},
      headers: original.headers.map(pdfSafeText).toList(),
      rows: [for (final r in original.rows) r.map(pdfSafeText).toList()],
    );
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(now ?? DateTime.now());
    final doc = pw.Document(title: table.title, author: kOrgName, creator: 'EducaStock');

    const blue = PdfColor.fromInt(0xFF1D5FA8);
    const grey = PdfColor.fromInt(0xFF6B7280);
    const light = PdfColor.fromInt(0xFFEFF6FF);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('$kOrgName - ${table.title}',
                    style: const pw.TextStyle(fontSize: 9, color: grey)),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount} - gerado em $generatedAt',
              style: const pw.TextStyle(fontSize: 8, color: grey)),
        ),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: const pw.BoxDecoration(
              color: blue,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(kOrgName,
                    style: pw.TextStyle(
                        color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text(kOrgSubtitle,
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text(table.title,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (table.subtitle != null)
            pw.Text(table.subtitle!, style: const pw.TextStyle(fontSize: 10, color: grey)),
          pw.SizedBox(height: 10),
          if (table.summary.isNotEmpty)
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in table.summary.entries)
                  pw.Container(
                    width: 120,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      color: light,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(e.value,
                            style: pw.TextStyle(
                                fontSize: 14, fontWeight: pw.FontWeight.bold, color: blue)),
                        pw.Text(e.key, style: const pw.TextStyle(fontSize: 8, color: grey)),
                      ],
                    ),
                  ),
              ],
            ),
          pw.SizedBox(height: 14),
          if (table.rows.isEmpty)
            pw.Text('Nenhum registro no período.', style: const pw.TextStyle(color: grey))
          else
            pw.TableHelper.fromTextArray(
              headers: table.headers,
              data: table.rows,
              headerStyle: pw.TextStyle(
                  color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: blue),
              cellStyle: const pw.TextStyle(fontSize: 9),
              oddRowDecoration: const pw.BoxDecoration(color: light),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              border: null,
            ),
        ],
      ),
    );
    return doc.save();
  }

  // ─── Entrega ──────────────────────────────────────────────────────────────

  static Future<void> sharePdf(ReportTable table) async {
    final bytes = await buildPdf(table);
    await Printing.sharePdf(bytes: bytes, filename: '${table.fileBaseName()}.pdf');
  }

  static Future<void> shareCsv(ReportTable table) async {
    final name = '${table.fileBaseName()}.csv';
    await entregarArquivos(
      [(bytes: buildCsv(table), nome: name, mime: 'text/csv')],
      assunto: table.title,
    );
  }

  static const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static Future<void> shareXlsx(ReportTable table) async {
    final name = '${table.fileBaseName()}.xlsx';
    await entregarArquivos(
      [(bytes: buildXlsx(table), nome: name, mime: _xlsxMime)],
      assunto: table.title,
    );
  }

  /// Gera PDF, Excel e CSV **em paralelo** e entrega os três arquivos de uma vez.
  static Future<void> shareAll(ReportTable table) async {
    final base = table.fileBaseName();
    final results = await Future.wait<Uint8List>([
      buildPdf(table),
      Future.sync(() => buildXlsx(table)),
      Future.sync(() => buildCsv(table)),
    ]);
    await entregarArquivos(
      [
        (bytes: results[0], nome: '$base.pdf', mime: 'application/pdf'),
        (bytes: results[1], nome: '$base.xlsx', mime: _xlsxMime),
        (bytes: results[2], nome: '$base.csv', mime: 'text/csv'),
      ],
      assunto: table.title,
    );
  }
}
