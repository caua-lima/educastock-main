import '../../stock/domain/entities/stock_movement.dart';

/// Entradas e saídas somadas por **dia civil**, para todos os dias do período.
///
/// Antes o gráfico do painel lia só os dias 0, 5, 10… e descartava os intermediários
/// (auditoria A09): os totais do gráfico não batiam com a lista e a exportação.
class DailyMovementSeries {
  final DateTime start;

  /// Quantidade de entradas por dia (índice 0 = [start]).
  final List<int> entries;

  /// Saídas e descartes por dia.
  final List<int> exits;

  const DailyMovementSeries({required this.start, required this.entries, required this.exits});

  int get days => entries.length;
  int get totalEntries => entries.fold(0, (a, b) => a + b);
  int get totalExits => exits.fold(0, (a, b) => a + b);

  /// Monta a série de [days] dias a partir de [start] (só a data conta, não a hora).
  /// Movimentos fora do período são ignorados.
  factory DailyMovementSeries.fromMovements(
    Iterable<StockMovement> movements, {
    required DateTime start,
    required int days,
  }) {
    final entries = List<int>.filled(days, 0);
    final exits = List<int>.filled(days, 0);
    // Datas em UTC "de calendário": diferença em dias exata, sem efeito de horário de verão.
    final base = DateTime.utc(start.year, start.month, start.day);
    for (final m in movements) {
      final at = m.performedAt;
      final day = DateTime.utc(at.year, at.month, at.day).difference(base).inDays;
      if (day < 0 || day >= days) continue;
      switch (m.type) {
        case MovementType.entrada:
          entries[day] += m.quantity;
        case MovementType.saida:
        case MovementType.descarte:
          exits[day] += m.quantity;
        default:
          break; // ajustes não entram no gráfico de entradas/saídas
      }
    }
    return DailyMovementSeries(start: start, entries: entries, exits: exits);
  }
}
