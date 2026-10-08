import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/stock_movement.dart';

class ProductOutputRequest {
  final String productId;
  final String productName;
  final int quantity;

  const ProductOutputRequest({
    required this.productId,
    required this.productName,
    required this.quantity,
  });
}

class StockRemoteDatasource {
  final FirebaseFirestore _db;

  StockRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stock_movements');
  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _db.collection('audit_logs');
    CollectionReference<Map<String, dynamic>> get _adjustmentApprovals =>
      _db.collection('adjustment_approvals');

  Future<void> registerMovement({
    required StockMovement movement,
    required String batchId,
    required int previousQuantity,
    required int newQuantity,
    String? nextStatus,
  }) async {
    await _db.runTransaction((tx) async {
      final movRef = _movements.doc();
      tx.set(movRef, movement.toMap());

      final batchRef = _db.collection('batches').doc(batchId);
      tx.update(batchRef, {
        'quantity': newQuantity,
        if (nextStatus != null) 'status': nextStatus,
      });

      final auditRef = _auditLogs.doc();
      tx.set(auditRef, {
        'collection': 'batches',
        'documentId': batchId,
        'action': movement.type.name,
        'before': movement.auditBefore,
        'after': movement.auditAfter,
        'performedBy': movement.performedBy,
        'performedByName': movement.performedByName,
        'performedAt': movement.performedAt.toIso8601String(),
      });
    });
  }

  /// Registra um movimento de ENTRADA (cadastro de lote) no histórico.
  /// Diferente de [registerMovement], NÃO usa transação nem altera o batch —
  /// o lote já foi criado pelo BatchesRemoteDatasource. Apenas grava o
  /// documento em `stock_movements` + um log de auditoria.
  Future<void> logEntryMovement(StockMovement movement) async {
    await _movements.add(movement.toMap());
    await _auditLogs.add({
      'collection': 'batches',
      'documentId': movement.batchId,
      'action': 'entrada',
      'before': null,
      'after': {'quantity': movement.quantity},
      'performedBy': movement.performedBy,
      'performedByName': movement.performedByName,
      'performedAt': movement.performedAt.toIso8601String(),
    });
  }

  Stream<List<StockMovement>> watchMovements({int limit = 200}) {
    return _movements
        .orderBy('performedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StockMovement.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<StockMovement>> watchMovementsByProduct(String productId) {
    return _movements
        .where('productId', isEqualTo: productId)
        .orderBy('performedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StockMovement.fromMap(d.data(), d.id))
            .toList());
  }

  Future<List<StockMovement>> getMovementsByPeriod({
    required DateTime from,
    required DateTime to,
    String? productId,
  }) async {
    Query<Map<String, dynamic>> query = _movements
        .where('performedAt', isGreaterThanOrEqualTo: from.toIso8601String())
        .where('performedAt', isLessThanOrEqualTo: to.toIso8601String())
        .orderBy('performedAt', descending: true);

    if (productId != null) {
      query = query.where('productId', isEqualTo: productId);
    }

    final snap = await query.get();
    return snap.docs
        .map((d) => StockMovement.fromMap(d.data(), d.id))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> watchAuditLogs({int limit = 50}) {
    return _auditLogs
        .orderBy('performedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }

  Future<void> createAdjustmentApprovalRequest({
    required String productId,
    required String productName,
    required String batchId,
    required int quantity,
    required String requestedBy,
    required String requestedByName,
    required String reason,
  }) async {
    await _adjustmentApprovals.add({
      'productId': productId,
      'productName': productName,
      'batchId': batchId,
      'quantity': quantity,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'reason': reason,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchPendingAdjustmentApprovals() {
    return _adjustmentApprovals
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> processAdjustmentApproval({
    required String requestId,
    required bool approve,
    required String approverId,
    required String approverName,
  }) async {
    await _db.runTransaction((tx) async {
      final reqRef = _adjustmentApprovals.doc(requestId);
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) return;
      final req = reqSnap.data()!;

      if (!approve) {
        tx.update(reqRef, {
          'status': 'rejected',
          'reviewedBy': approverId,
          'reviewedByName': approverName,
          'reviewedAt': DateTime.now().toIso8601String(),
        });
        return;
      }

      final batchId = req['batchId'] as String;
      final quantity = (req['quantity'] as num?)?.toInt() ?? 0;
      final productId = req['productId'] as String? ?? '';
      final productName = req['productName'] as String? ?? '';
      final reason = req['reason'] as String?;

      final batchRef = _db.collection('batches').doc(batchId);
      final batchSnap = await tx.get(batchRef);
      if (!batchSnap.exists) {
        tx.update(reqRef, {
          'status': 'failed',
          'failureReason': 'batch_not_found',
          'reviewedBy': approverId,
          'reviewedByName': approverName,
          'reviewedAt': DateTime.now().toIso8601String(),
        });
        return;
      }

      final batchData = batchSnap.data()!;
      final previousQty = (batchData['quantity'] as num?)?.toInt() ?? 0;
      final newQty = previousQty - quantity;
      if (newQty < 0) {
        tx.update(reqRef, {
          'status': 'failed',
          'failureReason': 'insufficient_quantity',
          'reviewedBy': approverId,
          'reviewedByName': approverName,
          'reviewedAt': DateTime.now().toIso8601String(),
        });
        return;
      }

      final movementRef = _movements.doc();
      tx.set(movementRef, {
        'productId': productId,
        'productName': productName,
        'batchId': batchId,
        'type': MovementType.ajusteNegativo.name,
        'quantity': quantity,
        'reason': reason,
        'activity': null,
        'performedBy': approverId,
        'performedByName': approverName,
        'performedAt': DateTime.now().toIso8601String(),
        'isPendingSync': false,
        'auditBefore': {'quantity': previousQty, 'status': batchData['status']},
        'auditAfter': {
          'quantity': newQty,
          'status': newQty <= 0 ? 'distribuido' : batchData['status'],
        },
      });

      tx.update(batchRef, {
        'quantity': newQty,
        if (newQty <= 0) 'status': 'distribuido',
      });

      final auditRef = _auditLogs.doc();
      tx.set(auditRef, {
        'collection': 'adjustment_approvals',
        'documentId': requestId,
        'action': 'approval_granted',
        'before': {'status': 'pending'},
        'after': {'status': 'approved'},
        'performedBy': approverId,
        'performedByName': approverName,
        'performedAt': DateTime.now().toIso8601String(),
      });

      tx.update(reqRef, {
        'status': 'approved',
        'reviewedBy': approverId,
        'reviewedByName': approverName,
        'reviewedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<Map<String, dynamic>> registerBulkOutputFefo({
    required List<ProductOutputRequest> items,
    required String performedBy,
    required String performedByName,
    required String reasonCode,
    String? reason,
    String? activity,
  }) async {
    if (items.isEmpty) {
      throw Exception('Nenhum item selecionado para saída.');
    }

    final planned = <Map<String, dynamic>>[];

    for (final item in items) {
      if (item.quantity <= 0) continue;

      final batchesSnap = await _db
          .collection('batches')
          .where('productId', isEqualTo: item.productId)
          .where('status', isEqualTo: 'disponivel')
          .get();

      final docs = batchesSnap.docs.toList();
      docs.sort((a, b) {
        final ad = DateTime.tryParse((a.data()['expiryDate'] as String?) ?? '9999-12-31') ?? DateTime(9999);
        final bd = DateTime.tryParse((b.data()['expiryDate'] as String?) ?? '9999-12-31') ?? DateTime(9999);
        final an = a.data()['noExpiry'] as bool? ?? false;
        final bn = b.data()['noExpiry'] as bool? ?? false;
        if (an && bn) return 0;
        if (an) return 1;
        if (bn) return -1;
        return ad.compareTo(bd);
      });

      final available = docs.fold<int>(0, (acc, d) => acc + ((d.data()['quantity'] as num?)?.toInt() ?? 0));
      if (available < item.quantity) {
        throw Exception(
          'Estoque insuficiente para ${item.productName}. Disponível: $available, necessário: ${item.quantity}.',
        );
      }

      var remaining = item.quantity;
      for (final doc in docs) {
        if (remaining <= 0) break;
        final before = (doc.data()['quantity'] as num?)?.toInt() ?? 0;
        if (before <= 0) continue;
        final consume = before >= remaining ? remaining : before;
        final after = before - consume;
        remaining -= consume;

        planned.add({
          'doc': doc,
          'productId': item.productId,
          'productName': item.productName,
          'consumed': consume,
          'before': before,
          'after': after,
          'oldStatus': doc.data()['status'] as String? ?? 'disponivel',
        });
      }
    }

    if (planned.isEmpty) {
      throw Exception('Nenhum consumo calculado para saída.');
    }

    final batch = _db.batch();
    final now = DateTime.now().toIso8601String();

    final List<Map<String, dynamic>> movementsSummary = [];

    for (final p in planned) {
      final doc = p['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
      final productId = p['productId'] as String;
      final productName = p['productName'] as String;
      final consumed = p['consumed'] as int;
      final before = p['before'] as int;
      final after = p['after'] as int;
      final oldStatus = p['oldStatus'] as String;

      batch.update(doc.reference, {
        'quantity': after,
        if (after <= 0) 'status': 'distribuido',
      });

      final movementRef = _movements.doc();
      batch.set(movementRef, {
        'productId': productId,
        'productName': productName,
        'batchId': doc.id,
        'type': MovementType.saida.name,
        'quantity': consumed,
        'reasonCode': reasonCode,
        'reason': reason,
        'activity': activity,
        'performedBy': performedBy,
        'performedByName': performedByName,
        'performedAt': now,
        'isPendingSync': false,
        'auditBefore': {'quantity': before, 'status': oldStatus},
        'auditAfter': {
          'quantity': after,
          'status': after <= 0 ? 'distribuido' : oldStatus,
          'reasonCode': reasonCode,
        },
      });

      movementsSummary.add({
        'movementId': movementRef.id,
        'productId': productId,
        'productName': productName,
        'batchId': doc.id,
        'consumed': consumed,
        'before': before,
        'after': after,
        'shelfLocation': doc.data()['shelfLocation'] as String?,
        'expiryDate': doc.data()['expiryDate'] as String?,
      });

      final auditRef = _auditLogs.doc();
      batch.set(auditRef, {
        'collection': 'batches',
        'documentId': doc.id,
        'action': 'saida',
        'before': {'quantity': before, 'status': oldStatus},
        'after': {
          'quantity': after,
          'status': after <= 0 ? 'distribuido' : oldStatus,
          'reasonCode': reasonCode,
        },
        'performedBy': performedBy,
        'performedByName': performedByName,
        'performedAt': now,
      });
    }

    final outputRef = _db.collection('outputs').doc();
    batch.set(outputRef, {
      'createdAt': now,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'reasonCode': reasonCode,
      'reason': reason,
      'movements': movementsSummary,
    });

    await batch.commit();

    return {
      'outputId': outputRef.id,
      'createdAt': now,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'reasonCode': reasonCode,
      'reason': reason,
      'movements': movementsSummary,
    };
  }

  Future<Map<String, dynamic>?> fetchOutputBySession(
      String createdAt, String performedBy) async {
    final snap = await _db
        .collection('outputs')
        .where('createdAt', isEqualTo: createdAt)
        .where('performedBy', isEqualTo: performedBy)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return {'outputId': doc.id, ...doc.data()};
  }
}
