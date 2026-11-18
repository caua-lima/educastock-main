// Relatórios filtrados por categoria (sugestão do teste beta): só as movimentações da
// categoria escolhida entram nos números e na exportação, e o título diz qual é.
import 'package:educastock/features/reports/domain/report_tables.dart';
import 'package:educastock/features/reports/presentation/controllers/reports_provider.dart';
import 'package:educastock/features/stock/domain/entities/stock_movement.dart';
import 'package:flutter_test/flutter_test.dart';

StockMovement _m(String id, String produto, int qtd) => StockMovement(
      id: id,
      productId: produto,
      productName: produto,
      batchId: 'b',
      type: MovementType.saida,
      quantity: qtd,
      performedBy: 'u1',
      performedByName: 'Marta',
      performedAt: DateTime(2026, 11, 10),
    );

void main() {
  final lista = [
    _m('1', 'leite', 5),
    _m('2', 'sabonete', 3),
    _m('3', 'arroz', 2)
  ];
  const categoria = {
    'leite': 'bebida',
    'sabonete': 'higienePessoal',
    'arroz': 'alimento'
  };

  test('sem categoria: todas as movimentações', () {
    expect(filtrarPorCategoria(lista, null, categoria), hasLength(3));
  });

  test(
      'com categoria: só as dela; produto sem categoria conhecida fica de fora',
      () {
    expect(filtrarPorCategoria(lista, 'bebida', categoria).map((m) => m.id),
        ['1']);
    expect(filtrarPorCategoria(lista, 'roupas', categoria), isEmpty);
    expect(
        filtrarPorCategoria(
            [_m('9', 'desconhecido', 1)], 'alimento', categoria),
        isEmpty);
  });

  test('título do relatório indica a categoria exportada', () {
    final t = ReportTables.movements(
        filtrarPorCategoria(lista, 'bebida', categoria),
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
        categoria: 'Bebida');
    expect(t.subtitle, contains('Categoria: Bebida'));
    expect(ReportTables.stock(const [], categoria: 'Alimento').subtitle,
        contains('Categoria: Alimento'));
    expect(ReportTables.stock(const []).subtitle, isNot(contains('Categoria')));
  });
}
