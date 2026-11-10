// "Entradas por mês" (reauditoria R16): vem das movimentações de entrada, não do
// saldo atual dos lotes; meses sem repetição, em ordem e sem valores inventados.
import 'package:educastock/features/reports/domain/entradas_por_mes.dart';
import 'package:educastock/features/stock/domain/entities/stock_movement.dart';
import 'package:flutter_test/flutter_test.dart';

StockMovement _mov(MovementType tipo, int qtd, DateTime quando) => StockMovement(
      id: '${tipo.name}-$qtd-${quando.toIso8601String()}',
      productId: 'p',
      productName: 'Arroz',
      batchId: 'b',
      type: tipo,
      quantity: qtd,
      performedBy: 'u',
      performedByName: 'Pessoa',
      performedAt: quando,
    );

void main() {
  final agora = DateTime(2026, 11, 4);

  test('janela de 6 meses: chaves em ordem, sem repetição, virando o ano', () {
    final r = entradasPorMes(const [], DateTime(2026, 2, 10));
    expect(r.keys.toList(), ['09/25', '10/25', '11/25', '12/25', '01/26', '02/26']);
    expect(r.values.every((v) => v == 0), isTrue);
    expect(inicioDaJanela(DateTime(2026, 2, 10)), DateTime(2025, 9, 1));
  });

  test('só entradas contam; saída, ajustes e descarte não', () {
    final r = entradasPorMes([
      _mov(MovementType.entrada, 50, DateTime(2026, 10, 3)),
      _mov(MovementType.entrada, 20, DateTime(2026, 10, 28)),
      _mov(MovementType.saida, 30, DateTime(2026, 10, 15)), // não reduz a entrada histórica
      _mov(MovementType.ajustePositivo, 7, DateTime(2026, 10, 16)),
      _mov(MovementType.ajusteNegativo, 4, DateTime(2026, 11, 1)),
      _mov(MovementType.descarte, 2, DateTime(2026, 11, 2)),
      _mov(MovementType.entrada, 12, DateTime(2026, 11, 3)),
    ], agora);
    expect(r['10/26'], 70);
    expect(r['11/26'], 12);
  });

  test('movimento fora da janela não entra (nem cria mês extra)', () {
    final r = entradasPorMes([
      _mov(MovementType.entrada, 99, DateTime(2026, 4, 30)),
      _mov(MovementType.entrada, 5, DateTime(2026, 6, 1)),
    ], agora);
    expect(r.length, 6);
    expect(r.containsKey('04/26'), isFalse);
    expect(r['06/26'], 5);
  });
}
