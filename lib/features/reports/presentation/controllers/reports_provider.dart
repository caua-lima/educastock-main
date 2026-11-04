import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../stock/domain/entities/stock_movement.dart';
import '../../../stock/presentation/controllers/stock_provider.dart';
import '../../../../core/firebase/firebase_providers.dart';

// ---------- Modelos de relatório ----------

class ReportSummary {
  final int totalProducts;
  final int totalBatches;
  final int expiringIn30Days;
  final int expiredBatches;
  final int lowStockProducts;
  final int movementsThisMonth;

  const ReportSummary({
    required this.totalProducts,
    required this.totalBatches,
    required this.expiringIn30Days,
    required this.expiredBatches,
    required this.lowStockProducts,
    required this.movementsThisMonth,
  });
}

class CategoryStock {
  final String category;
  final int totalItems;
  final double percentage;

  const CategoryStock({
    required this.category,
    required this.totalItems,
    required this.percentage,
  });
}

// ---------- Datasource ----------

class ReportsRemoteDatasource {
  final FirebaseFirestore _firestore;

  ReportsRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Resumo do painel em **uma rodada paralela de contagens** (agregações `count()`):
  /// não baixa nenhum documento, só o número, então o custo é de poucas leituras
  /// independentemente do tamanho do estoque.
  ///
  /// As datas são gravadas como texto ISO-8601 (`Batch.toMap`, `StockMovement.toMap`),
  /// por isso os filtros comparam texto e não `Timestamp`.
  Future<ReportSummary> fetchSummary() async {
    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));
    final startOfMonth = DateTime(now.year, now.month, 1);

    final batches = _firestore.collection('batches');
    final available = batches.where('status', isEqualTo: 'disponivel');
    final withExpiry = available.where('noExpiry', isEqualTo: false);

    final counts = await Future.wait([
      _firestore.collection('products').where('isActive', isEqualTo: true).count().get(),
      available.count().get(),
      withExpiry
          .where('expiryDate', isGreaterThanOrEqualTo: now.toIso8601String())
          .where('expiryDate', isLessThanOrEqualTo: in30Days.toIso8601String())
          .count()
          .get(),
      withExpiry.where('expiryDate', isLessThan: now.toIso8601String()).count().get(),
      _firestore
          .collection('stock_movements')
          .where('performedAt', isGreaterThanOrEqualTo: startOfMonth.toIso8601String())
          .count()
          .get(),
    ]);

    return ReportSummary(
      totalProducts: counts[0].count ?? 0,
      totalBatches: counts[1].count ?? 0,
      expiringIn30Days: counts[2].count ?? 0,
      expiredBatches: counts[3].count ?? 0,
      lowStockProducts: 0, // calculado via business logic
      movementsThisMonth: counts[4].count ?? 0,
    );
  }

  /// Produtos por categoria com uma contagem agregada por categoria, em paralelo.
  /// Antes baixava a coleção `products` inteira só para contar.
  Future<List<CategoryStock>> fetchStockByCategory() async {
    const categories = [
      'alimento',
      'bebida',
      'limpeza',
      'higienePessoal',
      'escolar',
      'roupas',
      'outro',
    ];
    final snaps = await Future.wait([
      for (final c in categories)
        _firestore
            .collection('products')
            .where('category', isEqualTo: c)
            .where('isActive', isEqualTo: true)
            .count()
            .get(),
    ]);
    final counts = <String, int>{
      for (var i = 0; i < categories.length; i++) categories[i]: snaps[i].count ?? 0,
    }..removeWhere((_, v) => v == 0);
    final total = counts.values.fold(0, (a, b) => a + b);
    return counts.entries
        .map((e) => CategoryStock(
              category: e.key,
              totalItems: e.value,
              percentage: total == 0 ? 0 : e.value / total * 100,
            ))
        .toList()
      ..sort((a, b) => b.totalItems.compareTo(a.totalItems));
  }
}

// ---------- Providers ----------

final reportsDatasourceProvider = Provider<ReportsRemoteDatasource>(
  (ref) => ReportsRemoteDatasource(firestore: ref.watch(firestoreProvider)),
);

/// Tempo em que um relatório já calculado é reaproveitado antes de nova leitura.
/// Relatórios (resumo, categorias, períodos) não exigem tempo real absoluto: dentro
/// desta janela, voltar à aba ou ao painel não custa nenhuma leitura no Firestore.
const Duration kReportCacheTtl = Duration(minutes: 5);

/// Mantém o resultado do provider vivo por [kReportCacheTtl] e depois o descarta.
void keepReportCached(Ref ref) {
  final link = ref.keepAlive();
  final timer = Timer(kReportCacheTtl, link.close);
  ref.onDispose(timer.cancel);
}

final reportSummaryProvider = FutureProvider.autoDispose<ReportSummary>((ref) {
  keepReportCached(ref);
  return ref.watch(reportsDatasourceProvider).fetchSummary();
});

final stockByCategoryProvider =
    FutureProvider.autoDispose<List<CategoryStock>>((ref) {
  keepReportCached(ref);
  return ref.watch(reportsDatasourceProvider).fetchStockByCategory();
});

// ─── Movement report providers ───────────────────────────────────────────

final movementsReportProvider = FutureProvider.autoDispose
    .family<List<StockMovement>, DateTimeRange>((ref, range) async {
  keepReportCached(ref);
  final ds = ref.read(stockDatasourceProvider);
  return ds.getMovementsByPeriod(
    from: range.start,
    to: range.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
  );
});

final movementsSummaryProvider = FutureProvider.autoDispose
    .family<Map<String, int>, DateTimeRange>((ref, range) async {
  final movements = await ref.read(movementsReportProvider(range).future);
  final summary = <String, int>{};
  for (final m in movements) {
    final key = m.type.name;
    summary[key] = (summary[key] ?? 0) + m.quantity;
  }
  return summary;
});

final lossesByReasonProvider = FutureProvider.autoDispose
    .family<Map<String, int>, DateTimeRange>((ref, range) async {
  final movements = await ref.read(movementsReportProvider(range).future);
  final losses = movements.where(
    (m) =>
        m.type == MovementType.descarte ||
        m.reasonCode == 'validade' ||
        m.reasonCode == 'avaria',
  );
  final summary = <String, int>{};
  for (final m in losses) {
    final key = m.reasonCode ?? 'outro';
    summary[key] = (summary[key] ?? 0) + m.quantity;
  }
  return summary;
});
