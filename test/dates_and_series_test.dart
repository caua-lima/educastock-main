// Regressão da auditoria A09 (gráfico diário sem dias perdidos) e A19 (validade por
// dia de calendário).
import 'package:educastock/features/batches/domain/entities/batch.dart';
import 'package:educastock/features/dashboard/domain/daily_movement_series.dart';
import 'package:educastock/features/stock/domain/entities/stock_movement.dart';
import 'package:flutter_test/flutter_test.dart';

StockMovement _mov(MovementType type, int qty, DateTime at) => StockMovement(
      id: '',
      productId: 'p1',
      productName: 'Leite',
      batchId: 'b1',
      type: type,
      quantity: qty,
      performedBy: 'u1',
      performedByName: 'Ana',
      performedAt: at,
    );

Batch _batch(DateTime? expiry, {bool noExpiry = false}) => Batch(
      id: 'b',
      productId: 'p',
      productName: 'Leite',
      quantity: 1,
      initialQuantity: 1,
      expiryDate: expiry,
      noExpiry: noExpiry,
      entryDate: DateTime(2026, 1, 1),
      origin: 'doacao',
      createdBy: 'u',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('A09 — série diária do painel', () {
    final start = DateTime(2026, 10, 6);

    test('movimentos em dias "intermediários" entram no gráfico', () {
      final s = DailyMovementSeries.fromMovements([
        _mov(MovementType.entrada, 10, DateTime(2026, 10, 7, 9)), // dia 1 (antes era ignorado)
        _mov(MovementType.saida, 4, DateTime(2026, 10, 9, 18)), // dia 3
        _mov(MovementType.descarte, 2, DateTime(2026, 10, 9, 23, 59)), // dia 3
        _mov(MovementType.entrada, 5, DateTime(2026, 11, 4, 0, 1)), // dia 29
      ], start: start, days: 30);

      expect(s.days, 30);
      expect(s.entries[1], 10);
      expect(s.exits[3], 6);
      expect(s.entries[29], 5);
      expect(s.totalEntries, 15, reason: 'total do gráfico = soma da lista');
      expect(s.totalExits, 6);
    });

    test('ajustes não contam como entrada/saída e movimentos fora do período são ignorados', () {
      final s = DailyMovementSeries.fromMovements([
        _mov(MovementType.ajustePositivo, 7, DateTime(2026, 10, 10)),
        _mov(MovementType.entrada, 3, DateTime(2026, 10, 5, 23, 59)), // véspera
        _mov(MovementType.entrada, 3, DateTime(2026, 11, 5)), // depois do fim
      ], start: start, days: 30);
      expect(s.totalEntries, 0);
      expect(s.totalExits, 0);
    });
  });

  group('A19 — validade por dia de calendário', () {
    tearDown(() => Batch.clock = DateTime.now);

    test('vence hoje: não está vencido e faltam 0 dias, a qualquer hora do dia', () {
      final b = _batch(DateTime(2026, 11, 10));
      for (final hora in [0, 9, 23]) {
        Batch.clock = () => DateTime(2026, 11, 10, hora, 59);
        expect(b.isExpired, isFalse, reason: 'às $hora h');
        expect(b.daysToExpiry, 0);
      }
    });

    test('vence amanhã: 1 dia, mesmo faltando poucas horas para a meia-noite', () {
      Batch.clock = () => DateTime(2026, 11, 9, 23, 30);
      expect(_batch(DateTime(2026, 11, 10)).daysToExpiry, 1);
      // A regra antiga (diferença em horas) dava 0.
    });

    test('a partir da meia-noite do dia seguinte fica vencido', () {
      Batch.clock = () => DateTime(2026, 11, 11, 0, 0, 1);
      final b = _batch(DateTime(2026, 11, 10));
      expect(b.isExpired, isTrue);
      expect(b.daysToExpiry, -1);
      expect(b.expiryUrgency, 0);
    });

    test('validade gravada com horário (ex.: 15h) conta só a data', () {
      Batch.clock = () => DateTime(2026, 11, 10, 18);
      expect(_batch(DateTime(2026, 11, 10, 15)).isExpired, isFalse);
    });

    test('sem validade nunca vence', () {
      Batch.clock = () => DateTime(2030, 1, 1);
      final b = _batch(null, noExpiry: true);
      expect(b.isExpired, isFalse);
      expect(b.daysToExpiry, 9999);
    });
  });
}
