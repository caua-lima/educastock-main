import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../domain/entities/stock_movement.dart';
import 'stock_provider.dart';

/// Tamanho de cada página do histórico.
const int kMovementsPageSize = 60;

/// Primeira página do histórico, em tempo real.
final movementsHeadProvider = StreamProvider<MovementsPage>((ref) {
  return ref
      .watch(stockDatasourceProvider)
      .watchMovementsHead(pageSize: kMovementsPageSize);
});

/// Páginas mais antigas carregadas sob demanda (botão "Carregar mais" / rolagem).
class OlderMovements {
  final List<StockMovement> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool loading;
  final bool exhausted;
  final Object? error;

  const OlderMovements({
    this.items = const [],
    this.cursor,
    this.loading = false,
    this.exhausted = false,
    this.error,
  });

  OlderMovements copyWith({
    List<StockMovement>? items,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    bool? loading,
    bool? exhausted,
    Object? error,
    bool clearError = false,
  }) =>
      OlderMovements(
        items: items ?? this.items,
        cursor: cursor ?? this.cursor,
        loading: loading ?? this.loading,
        exhausted: exhausted ?? this.exhausted,
        error: clearError ? null : (error ?? this.error),
      );
}

class OlderMovementsNotifier extends Notifier<OlderMovements> {
  @override
  OlderMovements build() => const OlderMovements();

  Future<void> loadMore() async {
    final s = state;
    if (s.loading || s.exhausted) return;

    // O cursor inicial é o último documento da primeira página (em tempo real).
    final cursor = s.cursor ?? ref.read(movementsHeadProvider).valueOrNull?.lastDoc;
    if (cursor == null) return;

    state = s.copyWith(loading: true, clearError: true);
    try {
      final page = await ref
          .read(stockDatasourceProvider)
          .fetchMovementsAfter(cursor, pageSize: kMovementsPageSize);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        cursor: page.lastDoc ?? cursor,
        loading: false,
        exhausted: !page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Volta ao início (usado ao atualizar a lista).
  void reset() => state = const OlderMovements();
}

final olderMovementsProvider =
    NotifierProvider<OlderMovementsNotifier, OlderMovements>(OlderMovementsNotifier.new);

/// Lista completa do histórico: primeira página ao vivo + páginas antigas, sem repetidos,
/// da mais recente para a mais antiga.
final movementsFeedProvider = Provider<AsyncValue<List<StockMovement>>>((ref) {
  final older = ref.watch(olderMovementsProvider);
  return ref.watch(movementsHeadProvider).whenData((head) {
    final seen = <String>{};
    final all = <StockMovement>[];
    for (final m in [...head.items, ...older.items]) {
      if (seen.add(m.id)) all.add(m);
    }
    return all;
  });
});

/// Há mais páginas para carregar?
final movementsHasMoreProvider = Provider<bool>((ref) {
  final older = ref.watch(olderMovementsProvider);
  if (older.exhausted) return false;
  final head = ref.watch(movementsHeadProvider).valueOrNull;
  if (head == null) return false;
  // Se ainda não pedimos nada, vale a dica da primeira página; depois, o estado das antigas.
  return older.cursor == null ? head.hasMore : true;
});
