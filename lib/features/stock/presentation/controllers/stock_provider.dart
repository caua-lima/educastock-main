import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_movement.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';

final stockDatasourceProvider = Provider<StockRemoteDatasource>((ref) {
  return StockRemoteDatasource();
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

  Future<void> registerMovement({
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
    await ds.registerMovement(
      movement: movement,
      batchId: batchId,
      previousQuantity: previousQuantity,
      newQuantity: newQuantity,
      nextStatus:
          nextStatusOverride ?? (newQuantity == 0 ? 'distribuido' : null),
    );
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
