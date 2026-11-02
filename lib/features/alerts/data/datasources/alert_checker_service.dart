import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../batches/data/datasources/batches_remote_datasource.dart';
import '../../../batches/domain/entities/batch.dart';

/// Cria e mantém os alertas de validade.
///
/// Faz **duas leituras no total** (lotes a vencer + alertas abertos) e grava tudo em
/// lotes de escrita, em vez de uma consulta por lote (o antigo padrão N+1).
class AlertCheckerService {
  final BatchesRemoteDatasource _batchesDs;
  final FirebaseFirestore _db;

  AlertCheckerService({
    required BatchesRemoteDatasource batchesDs,
    FirebaseFirestore? db,
  })  : _batchesDs = batchesDs,
        _db = db ?? FirebaseFirestore.instance;

  static const _maxBatchWrites = 400; // limite do Firestore é 500 por commit

  Future<void> checkAndCreateAlerts({
    int criticalDays = 7,
    int warningDays = 30,
  }) async {
    final results = await Future.wait([
      _batchesDs.getBatchesExpiringInDays(warningDays),
      _db.collection('alerts').where('resolved', isEqualTo: false).get(),
    ]);
    final batches = results[0] as List<Batch>;
    final openAlerts = (results[1] as QuerySnapshot<Map<String, dynamic>>).docs;

    // batchId -> níveis que já têm alerta aberto.
    final openLevels = <String, Set<String>>{};
    for (final doc in openAlerts) {
      final data = doc.data();
      final batchId = data['batchId'] as String?;
      if (batchId == null || data['productId'] == 'manual') continue;
      openLevels.putIfAbsent(batchId, () => <String>{}).add(data['level'] as String? ?? '');
    }

    final writes = <void Function(WriteBatch)>[];
    final currentLevel = <String, String>{};

    for (final batch in batches) {
      if (batch.noExpiry) continue;
      final days = batch.daysToExpiry;
      final String level;
      final String message;

      if (days <= 0) {
        level = 'critical';
        message = 'Lote VENCIDO — descarte imediato: ${batch.productName}';
      } else if (days <= criticalDays) {
        level = 'critical';
        message =
            'Crítico: "${batch.productName}" vence em $days dia${days == 1 ? '' : 's'}';
      } else {
        level = 'warning';
        message =
            'Atenção: "${batch.productName}" vence em $days dia${days == 1 ? '' : 's'}';
      }
      currentLevel[batch.id] = level;

      if (openLevels[batch.id]?.contains(level) ?? false) continue; // já existe

      final ref = _db.collection('alerts').doc();
      writes.add((wb) => wb.set(ref, {
            'productId': batch.productId,
            'productName': batch.productName,
            'batchId': batch.id,
            'level': level,
            'message': message,
            'createdAt': Timestamp.fromDate(DateTime.now()),
            'resolved': false,
          }));
    }

    // Encerra alertas de lotes que saíram da janela (consumidos, descartados, validade
    // corrigida) ou cujo nível mudou. Alertas manuais e de doação nunca são alterados.
    for (final doc in openAlerts) {
      final data = doc.data();
      final batchId = data['batchId'] as String?;
      if (batchId == null || data['productId'] == 'manual') continue;
      if (currentLevel[batchId] != data['level']) {
        writes.add((wb) => wb.update(doc.reference, {'resolved': true}));
      }
    }

    await _commit(writes);
  }

  Future<void> resolveAlertsForBatch(String batchId) async {
    final snap = await _db
        .collection('alerts')
        .where('batchId', isEqualTo: batchId)
        .where('resolved', isEqualTo: false)
        .get();
    await _commit([
      for (final doc in snap.docs)
        (wb) => wb.update(doc.reference, {'resolved': true}),
    ]);
  }

  Future<void> _commit(List<void Function(WriteBatch)> writes) async {
    for (var i = 0; i < writes.length; i += _maxBatchWrites) {
      final wb = _db.batch();
      for (final write in writes.skip(i).take(_maxBatchWrites)) {
        write(wb);
      }
      await wb.commit();
    }
  }
}
