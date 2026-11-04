// "Entradas por mês" (reauditoria R16): soma das MOVIMENTAÇÕES DE ENTRADA de cada
// mês — não o saldo atual dos lotes (antes uma saída mudava a "entrada" de meses
// passados e lotes esgotados sumiam do gráfico).
//
// Regra explícita:
// - conta só o tipo `entrada` (recebimento de mercadoria, inclusive doações);
// - ajustes de inventário (+/−), saídas e descartes NÃO contam como entrada;
// - lotes antigos, cadastrados antes de existir o registro de movimentações, não
//   têm entrada registrada e não são inventados aqui.

import '../../stock/domain/entities/stock_movement.dart';

/// Primeiro dia do mês que abre a janela de [meses] meses terminando no mês de [agora].
DateTime inicioDaJanela(DateTime agora, {int meses = 6}) =>
    DateTime(agora.year, agora.month - (meses - 1), 1);

/// Chave do mês no formato "MM/aa".
String chaveMes(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${(d.year % 100).toString().padLeft(2, '0')}';

/// Unidades recebidas por mês, nos [meses] meses até [agora] (inclusive), em ordem
/// cronológica e com todos os meses presentes (mês sem entrada = 0).
Map<String, int> entradasPorMes(Iterable<StockMovement> movimentos, DateTime agora, {int meses = 6}) {
  final resultado = <String, int>{};
  for (var i = meses - 1; i >= 0; i--) {
    resultado[chaveMes(DateTime(agora.year, agora.month - i, 1))] = 0;
  }
  for (final m in movimentos) {
    if (m.type != MovementType.entrada) continue;
    final k = chaveMes(m.performedAt);
    if (resultado.containsKey(k)) resultado[k] = resultado[k]! + m.quantity.abs();
  }
  return resultado;
}
