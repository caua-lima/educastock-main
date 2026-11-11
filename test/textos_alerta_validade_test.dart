// Textos de validade e de alerta: nunca "Vence em -2 dia(s)", nunca dias velhos gravados
// no alerta, nunca "item(ns)".
import 'package:educastock/core/utils/texto_validade.dart';
import 'package:educastock/features/alerts/domain/mensagem_alerta.dart';
import 'package:educastock/features/alerts/presentation/controllers/alerts_provider.dart';
import 'package:educastock/features/batches/domain/entities/batch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('texto de validade: passado, hoje, amanhã e futuro', () {
    expect(textoValidade(-3), 'Venceu há 3 dias');
    expect(textoValidade(-1), 'Venceu ontem');
    expect(textoValidade(0), 'Vence hoje');
    expect(textoValidade(1), 'Vence amanhã');
    expect(textoValidade(12), 'Vence em 12 dias');
    expect(textoValidadeCurto(-2), 'Venceu há 2d');
    expect(textoValidadeCurto(5), 'Vence em 5d');
  });

  group('mensagem do alerta', () {
    final hoje = DateTime(2026, 11, 10, 9);
    setUp(() => Batch.clock = () => hoje);
    tearDown(() => Batch.clock = DateTime.now);

    StockAlert alerta(String msg, {AlertLevel nivel = AlertLevel.critical}) => StockAlert(
          id: 'a1',
          productId: 'p1',
          productName: 'Cenoura · kg',
          batchId: 'b1',
          level: nivel,
          message: msg,
          createdAt: hoje.subtract(const Duration(days: 5)),
        );

    Batch lote(DateTime validade, {String? numero = 'L123'}) => Batch(
          id: 'b1',
          productId: 'p1',
          productName: 'Cenoura · kg',
          quantity: 5,
          initialQuantity: 5,
          expiryDate: validade,
          entryDate: hoje,
          origin: 'doacao',
          batchNumber: numero,
          createdBy: 'u1',
          createdAt: hoje,
        );

    test('recalcula os dias pelo lote atual e mostra o número do lote', () {
      final a = alerta('Crítico: "Cenoura · kg" vence em 7 dias');
      expect(mensagemDoAlerta(a, lote(DateTime(2026, 11, 12))), 'Crítico: vence em 2 dias (lote L123)');
      expect(mensagemDoAlerta(a, lote(DateTime(2026, 11, 8))), 'Crítico: venceu há 2 dias (lote L123)');
      expect(mensagemDoAlerta(alerta('x', nivel: AlertLevel.warning), lote(DateTime(2026, 11, 10), numero: null)),
          'Atenção: vence hoje');
    });

    test('sem o lote em estoque, usa a mensagem gravada com o plural certo', () {
      expect(mensagemDoAlerta(alerta('Nova intenção de doação DOA-1 de Ana (2 item(ns)).'), null),
          'Nova intenção de doação DOA-1 de Ana (2 itens).');
      expect(corrigirPluralItens('(1 item(ns))'), '(1 item)');
    });
  });
}
