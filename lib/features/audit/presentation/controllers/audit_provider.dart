import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------- Entidade ----------

class AuditEntry {
  final String id;
  final String action;
  final String entity;
  final String entityId;
  final String performedBy;
  final String performedByName;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  const AuditEntry({
    required this.id,
    required this.action,
    required this.entity,
    required this.entityId,
    required this.performedBy,
    required this.performedByName,
    required this.timestamp,
    required this.details,
  });

  factory AuditEntry.fromMap(Map<String, dynamic> map, String id) {
    return AuditEntry(
      id: id,
      action: map['action'] as String,
      entity: map['entity'] as String,
      entityId: map['entityId'] as String,
      performedBy: map['performedBy'] as String,
      performedByName: map['performedByName'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      details: (map['details'] as Map<String, dynamic>?) ?? {},
    );
  }
}

// ---------- Datasource ----------

class AuditRemoteDatasource {
  final _col = FirebaseFirestore.instance.collection('audit_logs');

  Stream<List<AuditEntry>> watchAuditLogs({int limit = 100}) {
    return _col
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AuditEntry.fromMap(d.data(), d.id)).toList());
  }

  Future<void> log(AuditEntry entry) async {
    await _col.add({
      'action': entry.action,
      'entity': entry.entity,
      'entityId': entry.entityId,
      'performedBy': entry.performedBy,
      'performedByName': entry.performedByName,
      'timestamp': Timestamp.fromDate(entry.timestamp),
      'details': entry.details,
    });
  }
}

// ---------- Providers ----------

final auditDatasourceProvider = Provider<AuditRemoteDatasource>(
  (_) => AuditRemoteDatasource(),
);

final auditLogsProvider = StreamProvider<List<AuditEntry>>((ref) {
  return ref.watch(auditDatasourceProvider).watchAuditLogs();
});
