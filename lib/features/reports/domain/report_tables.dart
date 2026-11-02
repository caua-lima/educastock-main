import 'package:intl/intl.dart';
import '../../../core/export/report_table.dart';
import '../../batches/domain/entities/batch.dart';
import '../../stock/domain/entities/stock_movement.dart';

/// Monta as tabelas exportáveis (PDF, Excel e CSV) a partir dos dados já carregados.
/// Funções puras: não leem o Firestore, então são fáceis de testar.
class ReportTables {
  const ReportTables._();

  static final _date = DateFormat('dd/MM/yyyy');
  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static const _origins = {
    'doacao': 'Doação',
    'compra': 'Compra',
    'parceiro': 'Parceiro',
    'transferencia': 'Transferência',
  };

  /// Posição do estoque: um lote por linha, do que vence primeiro ao que vence depois.
  static ReportTable stock(List<Batch> batches, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final sorted = [...batches]..sort((a, b) {
        if (a.noExpiry != b.noExpiry) return a.noExpiry ? 1 : -1;
        final ad = a.expiryDate, bd = b.expiryDate;
        if (ad == null || bd == null) return ad == null ? (bd == null ? 0 : 1) : -1;
        return ad.compareTo(bd);
      });

    int daysOf(Batch b) => b.expiryDate!.difference(today).inDays;
    final withExpiry = sorted.where((b) => !b.noExpiry && b.expiryDate != null);
    final expired = withExpiry.where((b) => b.expiryDate!.isBefore(today)).length;
    final critical = withExpiry
        .where((b) => !b.expiryDate!.isBefore(today) && daysOf(b) <= 7)
        .length;
    final warning = withExpiry.where((b) => daysOf(b) > 7 && daysOf(b) <= 30).length;
    final units = batches.fold<int>(0, (sum, b) => sum + b.quantity);

    return ReportTable(
      title: 'Posição do Estoque',
      subtitle: 'Gerado em ${_dateTime.format(today)}',
      summary: {
        'Lotes disponíveis': '${batches.length}',
        'Unidades em estoque': '$units',
        'Vencidos': '$expired',
        'Críticos (até 7 dias)': '$critical',
        'Atenção (8 a 30 dias)': '$warning',
      },
      headers: const ['Produto', 'Quantidade', 'Validade', 'Dias para vencer', 'Origem', 'Local'],
      rows: [
        for (final b in sorted)
          [
            b.productName,
            '${b.quantity}',
            b.noExpiry || b.expiryDate == null ? 'Sem validade' : _date.format(b.expiryDate!),
            b.noExpiry || b.expiryDate == null ? '-' : '${daysOf(b)}',
            _origins[b.origin] ?? b.origin,
            b.shelfLocation ?? '-',
          ],
      ],
    );
  }

  static const _types = {
    MovementType.entrada: 'Entrada',
    MovementType.saida: 'Saída',
    MovementType.ajustePositivo: 'Ajuste (+)',
    MovementType.ajusteNegativo: 'Ajuste (-)',
    MovementType.descarte: 'Descarte',
  };

  /// Movimentações de um período, da mais recente para a mais antiga, com totais por tipo.
  static ReportTable movements(
    List<StockMovement> movements, {
    required DateTime from,
    required DateTime to,
  }) {
    final sorted = [...movements]..sort((a, b) => b.performedAt.compareTo(a.performedAt));
    final totals = <MovementType, int>{};
    for (final m in sorted) {
      totals[m.type] = (totals[m.type] ?? 0) + m.quantity;
    }
    final losses = sorted
        .where((m) => m.type == MovementType.descarte || m.reasonCode == 'validade' || m.reasonCode == 'avaria')
        .fold<int>(0, (sum, m) => sum + m.quantity);

    return ReportTable(
      title: 'Movimentações de Estoque',
      subtitle: 'Período: ${_date.format(from)} a ${_date.format(to)}',
      summary: {
        'Registros': '${sorted.length}',
        'Entradas (un.)': '${totals[MovementType.entrada] ?? 0}',
        'Saídas (un.)': '${totals[MovementType.saida] ?? 0}',
        'Descartes (un.)': '${totals[MovementType.descarte] ?? 0}',
        'Perdas por validade/avaria (un.)': '$losses',
      },
      headers: const ['Data', 'Tipo', 'Produto', 'Quantidade', 'Motivo', 'Responsável'],
      rows: [
        for (final m in sorted)
          [
            _dateTime.format(m.performedAt),
            _types[m.type] ?? m.type.name,
            m.productName,
            '${m.quantity}',
            m.reason ?? m.reasonCode ?? '-',
            m.performedByName,
          ],
      ],
    );
  }
}
