import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/donation_needs_datasource.dart';
import '../../domain/entities/donation_need.dart';

final donationNeedsDatasourceProvider = Provider<DonationNeedsDatasource>(
  (_) => DonationNeedsDatasource(),
);

/// Necessidades ativas, já na ordem do servidor (prioridade e atualização).
final donationNeedsProvider = StreamProvider<List<DonationNeed>>((ref) {
  return ref.watch(donationNeedsDatasourceProvider).watchActiveNeeds();
});

/// Só o que ainda precisa de doação: com restante a cobrir e dentro da validade.
final openNeedsProvider = Provider<AsyncValue<List<DonationNeed>>>((ref) {
  final now = DateTime.now();
  return ref.watch(donationNeedsProvider).whenData((list) {
    final open = list
        .where((n) =>
            !n.isCovered &&
            (n.validUntil == null || n.validUntil!.isAfter(now)))
        .toList();
    // Estável: prioridade crítica primeiro; dentro dela, a que falta mais.
    open.sort((a, b) {
      final byRank = a.priorityRank.compareTo(b.priorityRank);
      return byRank != 0 ? byRank : b.remainingQty.compareTo(a.remainingQty);
    });
    return open;
  });
});

/// As [count] necessidades mais urgentes (cartões "Prioridades da semana").
final topNeedsProvider =
    Provider.family<AsyncValue<List<DonationNeed>>, int>((ref, count) {
  return ref.watch(openNeedsProvider).whenData((list) => list.take(count).toList());
});

/// Mapa id → necessidade (validação de itens que vêm de uma necessidade).
final needsByIdProvider = Provider<Map<String, DonationNeed>>((ref) {
  final list = ref.watch(donationNeedsProvider).valueOrNull ?? const <DonationNeed>[];
  return {for (final n in list) n.id: n};
});

final needByIdProvider =
    FutureProvider.family<DonationNeed?, String>((ref, id) async {
  final cached = ref.read(needsByIdProvider)[id];
  if (cached != null) return cached;
  return ref.read(donationNeedsDatasourceProvider).getNeedById(id);
});

// ─── Busca e filtro por categoria (D04) ──────────────────────────────────────

class NeedsFilter {
  final String query;

  /// `ProductCategory.name`; null = todas.
  final String? categoryId;

  const NeedsFilter({this.query = '', this.categoryId});

  NeedsFilter copyWith({String? query, String? categoryId, bool clearCategory = false}) =>
      NeedsFilter(
        query: query ?? this.query,
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      );
}

class NeedsFilterNotifier extends Notifier<NeedsFilter> {
  @override
  NeedsFilter build() => const NeedsFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setCategory(String? categoryId) => state = categoryId == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(categoryId: categoryId);
}

final needsFilterProvider =
    NotifierProvider<NeedsFilterNotifier, NeedsFilter>(NeedsFilterNotifier.new);

final filteredNeedsProvider = Provider<AsyncValue<List<DonationNeed>>>((ref) {
  final filter = ref.watch(needsFilterProvider);
  final query = filter.query.trim().toLowerCase();
  return ref.watch(openNeedsProvider).whenData((list) {
    return list.where((n) {
      final matchesCategory =
          filter.categoryId == null || n.categoryId == filter.categoryId;
      final matchesQuery = query.isEmpty || n.title.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  });
});
