// Prévia da saída FEFO (reauditoria R18): a regra não muda; a confirmação só mostra
// quantas unidades virão de lote vencido. Validade por dia civil (vence hoje = ok).
import 'package:educastock/features/batches/domain/entities/batch.dart';
import 'package:educastock/features/stock/domain/fefo_vencidos.dart';
import 'package:flutter_test/flutter_test.dart';

Batch _lote(String id, int qtd, DateTime? validade, {String produto = 'p1', BatchStatus status = BatchStatus.disponivel}) => Batch(
      id: id,
      productId: produto,
      productName: 'Leite',
      quantity: qtd,
      initialQuantity: qtd,
      expiryDate: validade,
      noExpiry: validade == null,
      entryDate: DateTime(2026, 1, 1),
      origin: 'doacao',
      status: status,
      createdBy: 'u',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUp(() => Batch.clock = () => DateTime(2026, 11, 4, 15));
  tearDown(() => Batch.clock = DateTime.now);

  final lotes = [
    _lote('sem-validade', 50, null),
    _lote('vence-hoje', 3, DateTime(2026, 11, 4)), // ainda vale hoje
    _lote('vencido-antigo', 4, DateTime(2026, 10, 1)),
    _lote('vencido-ontem', 2, DateTime(2026, 11, 3)),
    _lote('futuro', 10, DateTime(2026, 12, 1)),
    _lote('outro-produto-vencido', 99, DateTime(2026, 1, 1), produto: 'p2'),
    _lote('ja-descartado', 99, DateTime(2026, 1, 1), status: BatchStatus.descartado),
  ];

  test('saída pequena: só lotes vencidos (FEFO pega os mais antigos primeiro)', () {
    expect(unidadesVencidasNaSaida(lotes: lotes, productId: 'p1', quantidade: 5), 5);
  });

  test('saída maior: vencidos (6) + "vence hoje" (não conta) + futuros', () {
    expect(unidadesVencidasNaSaida(lotes: lotes, productId: 'p1', quantidade: 12), 6);
  });

  test('sem lote vencido: zero; outro produto e lote descartado não entram', () {
    final semVencidos = lotes.where((b) => !b.id.startsWith('vencido')).toList();
    expect(unidadesVencidasNaSaida(lotes: semVencidos, productId: 'p1', quantidade: 20), 0);
  });

  test('ordem igual à da transação: sem validade por último', () {
    final ordenados = [...lotes.where((b) => b.productId == 'p1' && b.status == BatchStatus.disponivel)]..sort(compararFefo);
    expect(ordenados.first.id, 'vencido-antigo');
    expect(ordenados.last.id, 'sem-validade');
  });
}
