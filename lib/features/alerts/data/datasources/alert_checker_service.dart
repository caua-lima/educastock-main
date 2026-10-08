import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../batches/data/datasources/batches_remote_datasource.dart';

class AlertCheckerService {
  final BatchesRemoteDatasource _batchesDs;
  final FirebaseFirestore _db;

  AlertCheckerService({
    required BatchesRemoteDatasource batchesDs,
    FirebaseFirestore? db,
  })  : _batchesDs = batchesDs,
        _db = db ?? FirebaseFirestore.instance;

  Future<void> checkAndCreateAlerts({
    int criticalDays = 7,
    int warningDays = 30,
  }) async {
    final batches = await _batchesDs.getBatchesExpiringInDays(warningDays);
    for (final batch in batches) {
      if (batch.noExpiry) continue;
      final days = batch.daysToExpiry;
      String level;
      String message;

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

      // Avoid duplicating alerts for same batch + level
      final existing = await _db
          .collection('alerts')
          .where('batchId', isEqualTo: batch.id)
          .where('level', isEqualTo: level)
          .where('resolved', isEqualTo: false)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;

      await _db.collection('alerts').add({
        'productId': batch.productId,
        'productName': batch.productName,
        'batchId': batch.id,
        'level': level,
        'message': message,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'resolved': false,
      });
    }
  }

  Future<void> resolveAlertsForBatch(String batchId) async {
    final snap = await _db
        .collection('alerts')
        .where('batchId', isEqualTo: batchId)
        .where('resolved', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'resolved': true});
    }
  }
}

