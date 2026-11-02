import 'dart:convert';
import 'package:educastock/core/export/report_exporter.dart';
import 'package:educastock/core/export/report_table.dart';
import 'package:educastock/features/batches/domain/entities/batch.dart';
import 'package:educastock/features/reports/domain/report_tables.dart';
import 'package:educastock/features/stock/domain/entities/stock_movement.dart';
import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';

Batch _batch(String name, int qty, DateTime? expiry, {String origin = 'doacao'}) => Batch(
      id: name,
      productId: 'p-$name',
      productName: name,
      quantity: qty,
      initialQuantity: qty,
      expiryDate: expiry,
      noExpiry: expiry == null,
      entryDate: DateTime(2026, 10, 1),
      origin: origin,
      createdBy: 'u1',
      createdAt: DateTime(2026, 10, 1),
    );

StockMovement _mov(String product, MovementType type, int qty, DateTime at, {String? reasonCode}) =>
    StockMovement(
      id: '$product-$at',
      productId: 'p',
      productName: product,
      batchId: 'b',
      type: type,
      quantity: qty,
      reasonCode: reasonCode,
      performedBy: 'u1',
      performedByName: 'Marta',
      performedAt: at,
    );

void main() {
  final now = DateTime(2026, 11, 3, 10);

  group('ReportTables.stock', () {
    final table = ReportTables.stock([
      _batch('Arroz', 10, now.add(const Duration(days: 40))),
      _batch('Leite', 5, now.add(const Duration(days: 3))),
      _batch('Iogurte', 2, now.subtract(const Duration(days: 2))),
      _batch('Caderno', 7, null),
      _batch('Feijão', 8, now.add(const Duration(days: 20))),
    ], now: now);

    test('ordena do que vence primeiro ao que vence depois, sem validade por último', () {
      expect(table.rows.map((r) => r[0]), ['Iogurte', 'Leite', 'Feijão', 'Arroz', 'Caderno']);
    });

    test('resumo conta vencidos, críticos e atenção', () {
      expect(table.summary['Lotes disponíveis'], '5');
      expect(table.summary['Unidades em estoque'], '32');
      expect(table.summary['Vencidos'], '1');
      expect(table.summary['Críticos (até 7 dias)'], '1');
      expect(table.summary['Atenção (8 a 30 dias)'], '1');
    });

    test('lote sem validade mostra "Sem validade"', () {
      final row = table.rows.last;
      expect(row[2], 'Sem validade');
      expect(row[3], '-');
    });
  });

  group('ReportTables.movements', () {
    final table = ReportTables.movements(
      [
        _mov('Arroz', MovementType.entrada, 50, DateTime(2026, 11, 1)),
        _mov('Leite', MovementType.saida, 10, DateTime(2026, 11, 2)),
        _mov('Iogurte', MovementType.descarte, 4, DateTime(2026, 11, 3), reasonCode: 'validade'),
      ],
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 3),
    );

    test('mais recente primeiro e totais por tipo', () {
      expect(table.rows.first[2], 'Iogurte');
      expect(table.summary['Entradas (un.)'], '50');
      expect(table.summary['Saídas (un.)'], '10');
      expect(table.summary['Perdas por validade/avaria (un.)'], '4');
      expect(table.subtitle, 'Período: 01/11/2026 a 03/11/2026');
    });
  });

  group('ReportExporter', () {
    const table = ReportTable(
      title: 'Posição do Estoque',
      summary: {'Lotes': '2'},
      headers: ['Produto', 'Qtd'],
      rows: [
        ['Arroz; tipo 1', '10'],
        ['Leite "integral"', '5'],
        ['Feijão', '8'],
      ],
    );

    test('CSV: BOM UTF-8, separador ponto e vírgula e aspas escapadas', () {
      final bytes = ReportExporter.buildCsv(table);
      expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(bytes.skip(3).toList());
      expect(text, contains('Produto;Qtd\r\n'));
      expect(text, contains('"Arroz; tipo 1";10\r\n'));
      expect(text, contains('"Leite ""integral""";5\r\n'));
      expect(text, contains('Feijão;8\r\n')); // acento preservado
    });

    test('Excel: gera um .xlsx que reabre com os mesmos dados', () {
      final bytes = ReportExporter.buildXlsx(table);
      final book = xl.Excel.decodeBytes(bytes);
      final sheet = book.tables.values.first;
      final flat = [
        for (final row in sheet.rows)
          for (final c in row) c?.value?.toString() ?? '',
      ];
      expect(flat, containsAll(['Posição do Estoque', 'Produto', 'Qtd', 'Arroz; tipo 1', 'Feijão', '8']));
    });

    test('PDF: gera um documento válido, também quando não há linhas', () async {
      final bytes = await ReportExporter.buildPdf(table, now: DateTime(2026, 11, 3, 9, 30));
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));

      final empty = await ReportExporter.buildPdf(
        const ReportTable(title: 'Vazio', headers: ['A'], rows: []),
      );
      expect(ascii.decode(empty.take(5).toList()), '%PDF-');
    });

    test('texto do PDF: mantém acentos e troca símbolos fora do Latin-1', () {
      expect(pdfSafeText('Feijão — ação… “ok” −3 ≤ 5'), 'Feijão - ação... "ok" -3 <= 5');
      expect(pdfSafeText('Doação 🎁'), 'Doação ?');
    });

    test('nome de arquivo sem acentos nem espaços', () {
      expect(table.fileBaseName(DateTime(2026, 11, 3)), 'posicao_do_estoque_20261103');
      const t = ReportTable(title: 'Movimentações de Estoque', headers: [], rows: []);
      expect(t.fileBaseName(DateTime(2026, 1, 9)), 'movimentacoes_de_estoque_20260109');
    });
  });
}
