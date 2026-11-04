import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/offline/offline_queue.dart';
import '../../../../core/offline/offline_sync_controller.dart';
import '../../domain/entities/stock_movement.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../../reports/presentation/controllers/reports_provider.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../../core/firebase/firebase_providers.dart';

final stockDatasourceProvider = Provider<StockRemoteDatasource>((ref) {
  return StockRemoteDatasource(db: ref.watch(firestoreProvider));
});

final stockMovementsProvider = StreamProvider<List<StockMovement>>((ref) {
  return ref.watch(stockDatasourceProvider).watchMovements();
});

final movementsByProductProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, productId) {
  return ref.watch(stockDatasourceProvider).watchMovementsByProduct(productId);
});

class StockNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Registra a movimentação. Retorna `true` se foi gravada no servidor agora, ou `false`
  /// se estava sem internet e ficou guardada no aparelho para ser enviada sozinha
  /// quando a conexão voltar.
  Future<bool> registerMovement({
    required String productId,
    required String productName,
    required String batchId,
    required MovementType type,
    required int quantity,
    required int previousQuantity,
    String? reason,
    String? reasonCode,
    String? activity,
    String? nextStatusOverride,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Usuario nao autenticado');
    final ds = ref.read(stockDatasourceProvider);
    final newQuantity = type == MovementType.entrada || type == MovementType.ajustePositivo
        ? previousQuantity + quantity
        : previousQuantity - quantity;
    final movement = StockMovement(
      id: '',
      productId: productId,
      productName: productName,
      batchId: batchId,
      type: type,
      quantity: quantity,
      reasonCode: reasonCode,
      reason: reason,
      activity: activity,
      performedBy: user.id,
      performedByName: user.name,
      performedAt: DateTime.now(),
    );
    final nextStatus =
        nextStatusOverride ?? (newQuantity == 0 ? 'distribuido' : null);

    Future<bool> saveOffline() async {
      final op = PendingMovement(
        opId: _newOpId(),
        movement: (StockMovement(
          id: '',
          productId: productId,
          productName: productName,
          batchId: batchId,
          type: type,
          quantity: quantity,
          reasonCode: reasonCode,
          reason: reason,
          activity: activity,
          performedBy: user.id,
          performedByName: user.name,
          performedAt: movement.performedAt,
          isPendingSync: true,
        )).toMap(),
        batchId: batchId,
        delta: newQuantity - previousQuantity,
        nextStatus: nextStatusOverride,
        createdAt: DateTime.now(),
        ownerId: user.id,
        projectId: ref.read(firebaseProjectIdProvider),
      );
      await ref.read(offlineSyncProvider.notifier).enqueue(op);
      return false;
    }

    if (!ref.read(offlineSyncProvider).online) return saveOffline();

    try {
      await ds.registerMovement(
        movement: movement,
        batchId: batchId,
        previousQuantity: previousQuantity,
        newQuantity: newQuantity,
        nextStatus: nextStatus,
      );
      invalidateReportCaches(ref);
      return true;
    } on FirebaseException catch (e) {
      // Caiu a conexão no meio da gravação: guarda para enviar depois.
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        ref.read(offlineSyncProvider.notifier).markOffline();
        return saveOffline();
      }
      rethrow;
    }
  }

  static String _newOpId() {
    final rnd = Random.secure();
    final suffix = List.generate(8, (_) => rnd.nextInt(36).toRadixString(36)).join();
    return 'off_${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  /// Dá baixa total no lote como descarte por validade vencida.
  /// Status final do lote = descartado. Registra movimento e auditoria.
  Future<void> discardExpiredBatch(Batch batch, {String? note}) async {
    if (batch.quantity <= 0) return;
    await registerMovement(
      productId: batch.productId,
      productName: batch.productName,
      batchId: batch.id,
      type: MovementType.descarte,
      quantity: batch.quantity,
      previousQuantity: batch.quantity,
      reasonCode: MovementReasonCode.validade.name,
      reason: note ?? 'Descarte por validade vencida',
      nextStatusOverride: 'descartado',
    );
  }

  /// Dá baixa total registrando o destino (uso interno, doação, etc).
  Future<void> writeOffExpiredBatch(
    Batch batch, {
    required MovementType type,
    required MovementReasonCode reasonCode,
    String? note,
  }) async {
    if (batch.quantity <= 0) return;
    await registerMovement(
      productId: batch.productId,
      productName: batch.productName,
      batchId: batch.id,
      type: type,
      quantity: batch.quantity,
      previousQuantity: batch.quantity,
      reasonCode: reasonCode.name,
      reason: note,
      nextStatusOverride:
          type == MovementType.descarte ? 'descartado' : 'distribuido',
    );
  }
}

final stockNotifierProvider =
    AsyncNotifierProvider<StockNotifier, void>(StockNotifier.new);
