// Prévia da saída por FEFO (reauditoria R18): quantas unidades de uma saída virão de
// lotes já vencidos. A regra de negócio NÃO muda — a saída continua pela ordem FEFO
// (vence primeiro, sai primeiro), igual à transação do datasource. Isto só deixa a
// consequência visível antes de confirmar, para a pessoa decidir entre distribuir e
// registrar como descarte.

import '../../batches/domain/entities/batch.dart';

/// Mesma ordem da transação (`StockRemoteDatasource.compareFefo`): sem validade por
/// último; com validade, da mais antiga para a mais nova.
int compararFefo(Batch a, Batch b) {
  if (a.noExpiry && b.noExpiry) return 0;
  if (a.noExpiry) return 1;
  if (b.noExpiry) return -1;
  return (a.expiryDate ?? DateTime(9999)).compareTo(b.expiryDate ?? DateTime(9999));
}

/// Unidades de lotes vencidos que a saída de [quantidade] do produto consumiria.
/// [lotes]: lotes disponíveis (qualquer produto — os de outro produto são ignorados).
int unidadesVencidasNaSaida({required Iterable<Batch> lotes, required String productId, required int quantidade}) {
  final doProduto = lotes
      .where((b) => b.productId == productId && b.status == BatchStatus.disponivel && b.quantity > 0)
      .toList()
    ..sort(compararFefo);
  var falta = quantidade;
  var vencidas = 0;
  for (final b in doProduto) {
    if (falta <= 0) break;
    final usa = b.quantity < falta ? b.quantity : falta;
    if (b.isExpired) vencidas += usa;
    falta -= usa;
  }
  return vencidas;
}
