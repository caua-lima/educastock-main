import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/batches_remote_datasource.dart';
import '../../domain/entities/batch.dart';

final batchesDatasourceProvider = Provider<BatchesRemoteDatasource>(
  (_) => BatchesRemoteDatasource(),
);

final batchesByProductProvider =
    StreamProvider.family<List<Batch>, String>((ref, productId) {
  return ref
      .watch(batchesDatasourceProvider)
      .watchBatchesByProduct(productId);
});

final allAvailableBatchesProvider = StreamProvider<List<Batch>>((ref) {
  return ref.watch(batchesDatasourceProvider).watchAllAvailableBatches();
});

/// Mapa productId → quantidade total disponível (soma de todos os lotes
/// com status `disponivel`). Recalcula automaticamente quando o stream de
/// batches muda. Usado para determinar se um produto está "ativo" (tem
/// estoque) ou "inativo" (sem estoque).
final productAvailableQtyMapProvider = Provider<Map<String, int>>((ref) {
  final batches =
      ref.watch(allAvailableBatchesProvider).valueOrNull ?? const <Batch>[];
  final map = <String, int>{};
  for (final b in batches) {
    if (b.quantity <= 0) continue;
    map[b.productId] = (map[b.productId] ?? 0) + b.quantity;
  }
  return map;
});

final expiringBatchesProvider =
    FutureProvider.family<List<Batch>, int>((ref, days) {
  return ref
      .watch(batchesDatasourceProvider)
      .getBatchesExpiringInDays(days);
});

final batchByIdProvider = FutureProvider.family<Batch?, String>((ref, id) {
  if (id.isEmpty) return Future.value(null);
  return ref.read(batchesDatasourceProvider).getBatchById(id);
});

class BatchFormNotifier extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  Future<void> saveBatch(Batch batch, {File? imageFile}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(batchesDatasourceProvider);
      return ds.saveBatch(batch, imageFile: imageFile);
    });
  }
}

final batchFormProvider =
    NotifierProvider<BatchFormNotifier, AsyncValue<String?>>(
        () => BatchFormNotifier());

/// Conta quantos lotes ativos estão na localização indicada (pelo label).
/// Útil para validar capacidade de prateleira/nível.
final batchCountByLocationProvider =
    Provider.family<int, String>((ref, locationLabel) {
  return ref.watch(allAvailableBatchesProvider).when(
        data: (batches) =>
            batches.where((b) => b.shelfLocation == locationLabel).length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});

// ─── Adicionar unidades a um lote existente ──────────────────────────────

class AddBatchQuantityNotifier
    extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> addUnits(Batch batch, int amount) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final newQty = batch.quantity + amount;
      final newStatus =
          newQty > 0 ? BatchStatus.disponivel : BatchStatus.distribuido;
      await ref
          .read(batchesDatasourceProvider)
          .updateBatchQuantity(batch.id, newQty, newStatus);
    });
  }
}

final addBatchQuantityProvider = AutoDisposeNotifierProvider<
    AddBatchQuantityNotifier, AsyncValue<void>>(
  () => AddBatchQuantityNotifier(),
);

// ─── Deletar lote ────────────────────────────────────────────────────────

class DeleteBatchNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> deleteBatch(String batchId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(batchesDatasourceProvider).deleteBatch(batchId);
    });
  }
}

final deleteBatchProvider =
    AutoDisposeNotifierProvider<DeleteBatchNotifier, AsyncValue<void>>(
  () => DeleteBatchNotifier(),
);
