import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../data/datasources/alert_checker_service.dart';

// ---------- Entidade ----------

enum AlertLevel { info, warning, critical }

class StockAlert {
  final String id;
  final String productId;
  final String productName;
  final String? batchId;
  final AlertLevel level;
  final String message;
  final DateTime createdAt;
  final bool resolved;
  final DateTime? snoozedUntil;

  const StockAlert({
    required this.id,
    required this.productId,
    required this.productName,
    this.batchId,
    required this.level,
    required this.message,
    required this.createdAt,
    this.resolved = false,
    this.snoozedUntil,
  });

  bool get isManual => productId == 'manual';

  bool get isSnoozed {
    final s = snoozedUntil;
    return s != null && s.isAfter(DateTime.now());
  }

  factory StockAlert.fromMap(Map<String, dynamic> map, String id) {
    return StockAlert(
      id: id,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      batchId: map['batchId'] as String?,
      level: AlertLevel.values.firstWhere(
        (e) => e.name == map['level'],
        orElse: () => AlertLevel.info,
      ),
      message: map['message'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      resolved: map['resolved'] as bool? ?? false,
      snoozedUntil: (map['snoozedUntil'] as Timestamp?)?.toDate(),
    );
  }
}

// ---------- Datasource ----------

class AlertsRemoteDatasource {
  final _col = FirebaseFirestore.instance.collection('alerts');

  Stream<List<StockAlert>> watchActiveAlerts() {
    return _col
        .where('resolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => StockAlert.fromMap(d.data(), d.id))
            .where((a) => !a.isSnoozed) // adiados ficam ocultos até a hora
            .toList());
  }

  Future<void> resolveAlert(String id) async {
    await _col.doc(id).update({'resolved': true});
  }

  Future<void> resolveMany(Iterable<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.update(_col.doc(id), {'resolved': true});
    }
    await batch.commit();
  }

  Future<void> deleteAlert(String id) async {
    await _col.doc(id).delete();
  }

  Future<void> snoozeAlert(String id, Duration duration) async {
    await _col.doc(id).update({
      'snoozedUntil': Timestamp.fromDate(DateTime.now().add(duration)),
    });
  }

  Future<void> createManualAlert({
    required String productName,
    required AlertLevel level,
    required String message,
  }) async {
    await _col.add({
      'productId': 'manual',
      'productName': productName,
      'batchId': null,
      'level': level.name,
      'message': message,
      'createdAt': Timestamp.now(),
      'resolved': false,
    });
  }
}

// ---------- Providers ----------

final alertsDatasourceProvider = Provider<AlertsRemoteDatasource>(
  (_) => AlertsRemoteDatasource(),
);

final activeAlertsProvider = StreamProvider<List<StockAlert>>((ref) {
  return ref.watch(alertsDatasourceProvider).watchActiveAlerts();
});

class AlertsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> resolve(String alertId) async {
    await ref.read(alertsDatasourceProvider).resolveAlert(alertId);
  }

  Future<void> resolveAll(Iterable<String> ids) async {
    await ref.read(alertsDatasourceProvider).resolveMany(ids);
  }

  Future<void> delete(String alertId) async {
    await ref.read(alertsDatasourceProvider).deleteAlert(alertId);
  }

  Future<void> snooze(String alertId, Duration duration) async {
    await ref.read(alertsDatasourceProvider).snoozeAlert(alertId, duration);
  }

  Future<void> createManualAlert({
    required String productName,
    required AlertLevel level,
    required String message,
  }) async {
    await ref.read(alertsDatasourceProvider).createManualAlert(
          productName: productName,
          level: level,
          message: message,
        );
  }

  Future<void> checkAlerts(int criticalDays, int warningDays) async {
    await ref.read(alertCheckerServiceProvider).checkAndCreateAlerts(
          criticalDays: criticalDays,
          warningDays: warningDays,
        );
  }
}

final alertsNotifierProvider =
    AsyncNotifierProvider<AlertsNotifier, void>(AlertsNotifier.new);

// ─── AlertCheckerService provider ─────────────────────────────────────────

final alertCheckerServiceProvider = Provider<AlertCheckerService>((ref) {
  return AlertCheckerService(
    batchesDs: ref.read(batchesDatasourceProvider),
  );
});
