import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/batches_remote_datasource.dart';
import '../../domain/entities/batch.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../stock/presentation/controllers/stock_provider.dart';
import '../../../reports/presentation/controllers/reports_provider.dart';

final batchesDatasourceProvider = Provider<BatchesRemoteDatasource>(
  (ref) => BatchesRemoteDatasource(db: bancoDaSessao(ref)),
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

/// Mapa productId → quantidade total disponível, **com os estados de carregamento e
/// erro**. Use este para decidir se um produto está "sem estoque": enquanto os lotes
/// carregam ou se a consulta falhar, não há como saber (auditoria A08).
final productAvailableQtyAsyncProvider = Provider<AsyncValue<Map<String, int>>>((ref) {
  return ref.watch(allAvailableBatchesProvider).whenData((batches) {
    final map = <String, int>{};
    for (final b in batches) {
      if (b.quantity <= 0) continue;
      map[b.productId] = (map[b.productId] ?? 0) + b.quantity;
    }
    return map;
  });
});

/// Mesmo mapa, já resolvido. ATENÇÃO: fica vazio enquanto carrega ou se a consulta
/// falhar — não use para afirmar que um produto está sem estoque; para isso use
/// [productAvailableQtyAsyncProvider].
final productAvailableQtyMapProvider = Provider<Map<String, int>>((ref) {
  return ref.watch(productAvailableQtyAsyncProvider).valueOrNull ?? const <String, int>{};
});

/// Lotes disponíveis de um produto, derivados em memória do stream geral de lotes
/// (sem abrir um listener do Firestore por produto — antes cada cartão da lista abria o
/// seu). Mantém carregando/erro.
final availableBatchesOfProductProvider =
    Provider.family<AsyncValue<List<Batch>>, String>((ref, productId) {
  return ref.watch(allAvailableBatchesProvider).whenData(
        (all) => all.where((b) => b.productId == productId && b.quantity > 0).toList(),
      );
});

/// Data de hoje. Se renova sozinha logo após a meia-noite, para as listas de validade
/// mudarem de dia com o app aberto (auditoria A19).
final currentDayProvider = Provider<DateTime>((ref) {
  final now = Batch.clock();
  final today = DateTime(now.year, now.month, now.day);
  final nextMidnight = today.add(const Duration(days: 1));
  final timer = Timer(nextMidnight.difference(now) + const Duration(seconds: 1), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return today;
});

/// Lotes que vencem em até [days] dias (inclui os já vencidos), calculados em memória a
/// partir de [allAvailableBatchesProvider]. Antes cada chamada fazia uma consulta nova
/// ao Firestore (e ficava desatualizada); agora reaproveita a leitura em tempo real já
/// existente: zero leituras extras por tela.
final expiringBatchesProvider =
    Provider.family<AsyncValue<List<Batch>>, int>((ref, days) {
  ref.watch(currentDayProvider); // recalcula sozinho na virada do dia
  return ref.watch(allAvailableBatchesProvider).whenData((batches) {
    // Por dia de calendário (inclui os vencidos, que têm dias negativos).
    return batches
        .where((b) => !b.noExpiry && b.expiryDate != null && b.daysToExpiry <= days)
        .toList(growable: false);
  });
});

final batchByIdProvider = FutureProvider.family<Batch?, String>((ref, id) {
  if (id.isEmpty) return Future.value(null);
  return ref.read(batchesDatasourceProvider).getBatchById(id);
});

class BatchFormNotifier extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  Future<void> saveBatch(
    Batch batch, {
    File? imageFile,
    Map<String, dynamic>? entryMovement,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(batchesDatasourceProvider);
      final id = await ds.saveBatch(batch, imageFile: imageFile, entryMovement: entryMovement);
      invalidateReportCaches(ref);
      return id;
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
      // Transação: soma ao saldo ATUAL do servidor (não ao valor carregado na tela) e
      // registra a entrada e a auditoria junto (auditoria A01).
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Sessão expirada. Entre novamente.');
      await ref.read(stockDatasourceProvider).addUnitsToBatch(
            batchId: batch.id,
            amount: amount,
            performedBy: user.id,
            performedByName: user.name,
          );
      invalidateReportCaches(ref);
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
