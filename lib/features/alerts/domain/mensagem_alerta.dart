import '../../../core/utils/texto_validade.dart';
import '../../batches/domain/entities/batch.dart';
import '../presentation/controllers/alerts_provider.dart';

/// Texto exibido no cartão do alerta.
///
/// A mensagem gravada no alerta é de quando ele foi criado ("vence em 7 dias") e
/// envelhece. Se o lote do alerta ainda está em estoque, os dias são recalculados agora
/// e o número do lote aparece (dois lotes do mesmo produto deixam de parecer repetidos).
/// Sem o lote, usa a mensagem gravada, com o plural "item(ns)" corrigido.
String mensagemDoAlerta(StockAlert alerta, Batch? lote) {
  if (lote != null && !lote.noExpiry && lote.expiryDate != null) {
    final nivel = switch (alerta.level) {
      AlertLevel.critical => 'Crítico',
      AlertLevel.warning => 'Atenção',
      AlertLevel.info => 'Aviso',
    };
    final validade = textoValidade(lote.daysToExpiry);
    final numero = (lote.batchNumber ?? '').trim();
    return '$nivel: ${validade[0].toLowerCase()}${validade.substring(1)}'
        '${numero.isEmpty ? '' : ' (lote $numero)'}';
  }
  return corrigirPluralItens(alerta.message);
}

/// "(1 item(ns))" -> "(1 item)"; "(3 item(ns))" -> "(3 itens)".
String corrigirPluralItens(String texto) => texto.replaceAllMapped(
      RegExp(r'(\d+) item\(ns\)'),
      (m) => '${m[1]} ${m[1] == '1' ? 'item' : 'itens'}',
    );
