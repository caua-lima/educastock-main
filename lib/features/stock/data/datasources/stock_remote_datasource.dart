import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../../../core/offline/offline_queue.dart';
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

/// Resultado de aplicar no servidor uma movimentação que ficou na fila offline.
enum QueuedMovementOutcome {
  applied,
  alreadyApplied,
  batchNotFound,
  insufficientStock,
}

/// Uma página de movimentações mais o cursor para pedir a seguinte.
class MovementsPage {
  final List<StockMovement> items;

  /// Último documento da página (cursor de `startAfterDocument`); null se vazia.
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;

  /// `true` quando a página veio cheia: pode haver mais registros.
  final bool hasMore;

  const MovementsPage({required this.items, required this.lastDoc, required this.hasMore});
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

  /// Aplica uma movimentação guardada offline. Recalcula a quantidade em cima do que
  /// está no servidor agora (usando a variação registrada) e usa o `opId` como id do
  /// documento, então repetir o envio nunca duplica o movimento.
  Future<QueuedMovementOutcome> applyQueuedMovement(PendingMovement op) {
    return _db.runTransaction<QueuedMovementOutcome>((tx) async {
      final movRef = _movements.doc(op.opId);
      if ((await tx.get(movRef)).exists) return QueuedMovementOutcome.alreadyApplied;

      final batchRef = _db.collection('batches').doc(op.batchId);
      final batchSnap = await tx.get(batchRef);
      if (!batchSnap.exists) return QueuedMovementOutcome.batchNotFound;

      final current = (batchSnap.data()?['quantity'] as num?)?.toInt() ?? 0;
      final newQty = current + op.delta;
      if (newQty < 0) return QueuedMovementOutcome.insufficientStock;

      final status = op.nextStatus ?? (newQty == 0 ? 'distribuido' : null);
      final movement = Map<String, dynamic>.from(op.movement)
        ..['isPendingSync'] = false
        ..['auditBefore'] = {'quantity': current}
        ..['auditAfter'] = {'quantity': newQty, if (status != null) 'status': status};
      tx.set(movRef, movement);
      tx.update(batchRef, {
        'quantity': newQty,
        if (status != null) 'status': status,
      });
      tx.set(_auditLogs.doc(), {
        'collection': 'batches',
        'documentId': op.batchId,
        'action': movement['type'],
        'before': movement['auditBefore'],
        'after': movement['auditAfter'],
        'performedBy': movement['performedBy'],
        'performedByName': movement['performedByName'],
        'performedAt': movement['performedAt'],
        'syncedFromOffline': true,
      });
      return QueuedMovementOutcome.applied;
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

  MovementsPage _toPage(QuerySnapshot<Map<String, dynamic>> snap, int pageSize) {
    return MovementsPage(
      items: snap.docs.map((d) => StockMovement.fromMap(d.data(), d.id)).toList(),
      lastDoc: snap.docs.isEmpty ? null : snap.docs.last,
      hasMore: snap.docs.length >= pageSize,
    );
  }

  /// Primeira página, em tempo real (os registros novos aparecem no topo sozinhos).
  Stream<MovementsPage> watchMovementsHead({int pageSize = 60}) {
    return _movements
        .orderBy('performedAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snap) => _toPage(snap, pageSize));
  }

  /// Páginas seguintes por **cursor** (`startAfterDocument`): lê só o próximo trecho, sem
  /// reler o que já foi carregado (diferente de `offset`/aumentar o `limit`).
  Future<MovementsPage> fetchMovementsAfter(
    DocumentSnapshot<Map<String, dynamic>> cursor, {
    int pageSize = 60,
  }) async {
    final snap = await _movements
        .orderBy('performedAt', descending: true)
        .startAfterDocument(cursor)
        .limit(pageSize)
        .get();
    return _toPage(snap, pageSize);
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

  /// Ordem FEFO: lotes com validade mais próxima primeiro; sem validade por último.
  static int compareFefo(Map<String, dynamic> a, Map<String, dynamic> b) {
    final an = a['noExpiry'] as bool? ?? false;
    final bn = b['noExpiry'] as bool? ?? false;
    if (an && bn) return 0;
    if (an) return 1;
    if (bn) return -1;
    final ad = DateTime.tryParse((a['expiryDate'] as String?) ?? '') ?? DateTime(9999);
    final bd = DateTime.tryParse((b['expiryDate'] as String?) ?? '') ?? DateTime(9999);
    return ad.compareTo(bd);
  }

  /// Só para testes: roda entre a escolha dos lotes candidatos e a transação, para
  /// simular outra pessoa mexendo no mesmo lote nesse intervalo.
  @visibleForTesting
  Future<void> Function()? debugAfterPlanning;

  /// Saída de vários produtos pela regra FEFO, **segura contra concorrência**.
  ///
  /// 1. Uma consulta escolhe os lotes candidatos de cada produto (consultas não rodam
  ///    dentro de transações no cliente).
  /// 2. Uma transação **relê cada lote**, recalcula o FEFO com os saldos atuais e grava
  ///    lote, movimentação, auditoria e o registro da saída de uma vez. Se outra pessoa
  ///    alterar um desses lotes ao mesmo tempo, o Firestore repete a transação com os
  ///    valores novos — nenhuma baixa se perde e o saldo nunca fica negativo.
  /// 3. [operationId] identifica a operação: reenviar a mesma saída (duplo toque, rede
  ///    instável) devolve o registro existente em vez de descontar de novo.
  Future<Map<String, dynamic>> registerBulkOutputFefo({
    required List<ProductOutputRequest> items,
    required String performedBy,
    required String performedByName,
    required String reasonCode,
    String? reason,
    String? activity,
    String? operationId,
  }) async {
    final wanted = items.where((i) => i.quantity > 0).toList();
    if (wanted.isEmpty) {
      throw Exception('Nenhum item selecionado para saída.');
    }

    // 1) Lotes candidatos por produto (fora da transação).
    final candidates = <String, List<DocumentReference<Map<String, dynamic>>>>{};
    for (final item in wanted) {
      final snap = await _db
          .collection('batches')
          .where('productId', isEqualTo: item.productId)
          .where('status', isEqualTo: 'disponivel')
          .get();
      candidates[item.productId] = snap.docs.map((d) => d.reference).toList();
    }
    await debugAfterPlanning?.call();

    final outputRef = operationId == null
        ? _db.collection('outputs').doc()
        : _db.collection('outputs').doc(operationId);

    // 2) Transação: relê, recalcula e grava tudo junto.
    return _db.runTransaction<Map<String, dynamic>>((tx) async {
      // Reenvio da mesma operação: devolve o que já foi gravado.
      final existing = await tx.get(outputRef);
      if (existing.exists) {
        return {'outputId': outputRef.id, ...?existing.data(), 'alreadyApplied': true};
      }

      // Todas as leituras antes de qualquer escrita (exigência das transações).
      final fresh = <String, List<DocumentSnapshot<Map<String, dynamic>>>>{};
      for (final item in wanted) {
        final refs = candidates[item.productId] ?? const [];
        final snaps = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final r in refs) {
          snaps.add(await tx.get(r));
        }
        fresh[item.productId] = snaps;
      }

      final now = DateTime.now().toIso8601String();
      final movementsSummary = <Map<String, dynamic>>[];
      final writes = <void Function()>[];
      var seq = 0;

      for (final item in wanted) {
        final docs = fresh[item.productId]!
            .where((d) =>
                d.exists &&
                (d.data()!['status'] as String? ?? '') == 'disponivel' &&
                ((d.data()!['quantity'] as num?)?.toInt() ?? 0) > 0)
            .toList()
          ..sort((a, b) => compareFefo(a.data()!, b.data()!));

        final available =
            docs.fold<int>(0, (acc, d) => acc + ((d.data()!['quantity'] as num).toInt()));
        if (available < item.quantity) {
          throw Exception(
            'Estoque insuficiente para ${item.productName}. '
            'Disponível agora: $available, necessário: ${item.quantity}.',
          );
        }

        var remaining = item.quantity;
        for (final doc in docs) {
          if (remaining <= 0) break;
          final data = doc.data()!;
          final before = (data['quantity'] as num).toInt();
          final consume = before >= remaining ? remaining : before;
          final after = before - consume;
          remaining -= consume;
          final oldStatus = data['status'] as String? ?? 'disponivel';
          final newStatus = after <= 0 ? 'distribuido' : oldStatus;
          final movementRef = _movements.doc('${outputRef.id}_${seq++}');
          final auditRef = _auditLogs.doc('${movementRef.id}_audit');

          writes.add(() {
            tx.update(doc.reference, {
              'quantity': after,
              if (after <= 0) 'status': 'distribuido',
            });
            tx.set(movementRef, {
              'productId': item.productId,
              'productName': item.productName,
              'batchId': doc.id,
              'type': MovementType.saida.name,
              'quantity': consume,
              'reasonCode': reasonCode,
              'reason': reason,
              'activity': activity,
              'performedBy': performedBy,
              'performedByName': performedByName,
              'performedAt': now,
              'isPendingSync': false,
              'outputId': outputRef.id,
              'auditBefore': {'quantity': before, 'status': oldStatus},
              'auditAfter': {'quantity': after, 'status': newStatus, 'reasonCode': reasonCode},
            });
            tx.set(auditRef, {
              'collection': 'batches',
              'documentId': doc.id,
              'action': 'saida',
              'before': {'quantity': before, 'status': oldStatus},
              'after': {'quantity': after, 'status': newStatus, 'reasonCode': reasonCode},
              'performedBy': performedBy,
              'performedByName': performedByName,
              'performedAt': now,
            });
          });

          movementsSummary.add({
            'movementId': movementRef.id,
            'productId': item.productId,
            'productName': item.productName,
            'batchId': doc.id,
            'consumed': consume,
            'before': before,
            'after': after,
            'shelfLocation': data['shelfLocation'] as String?,
            'expiryDate': data['expiryDate'] as String?,
          });
        }
      }

      if (movementsSummary.isEmpty) {
        throw Exception('Nenhum consumo calculado para saída.');
      }

      final output = {
        'createdAt': now,
        'performedBy': performedBy,
        'performedByName': performedByName,
        'reasonCode': reasonCode,
        'reason': reason,
        'movements': movementsSummary,
      };
      for (final w in writes) {
        w();
      }
      tx.set(outputRef, output);
      return {'outputId': outputRef.id, ...output};
    });
  }

  /// Acrescenta unidades a um lote existente, **em transação**: relê o saldo atual
  /// (outra pessoa pode ter mexido no lote) e registra a entrada e a auditoria junto.
  Future<int> addUnitsToBatch({
    required String batchId,
    required int amount,
    required String performedBy,
    required String performedByName,
  }) async {
    if (amount <= 0) throw Exception('Informe uma quantidade maior que zero.');
    final batchRef = _db.collection('batches').doc(batchId);
    return _db.runTransaction<int>((tx) async {
      final snap = await tx.get(batchRef);
      if (!snap.exists) throw Exception('Lote não encontrado.');
      final data = snap.data()!;
      final before = (data['quantity'] as num?)?.toInt() ?? 0;
      final oldStatus = data['status'] as String? ?? 'disponivel';
      final after = before + amount;
      final now = DateTime.now().toIso8601String();
      tx.update(batchRef, {'quantity': after, 'status': 'disponivel'});
      final movementRef = _movements.doc();
      tx.set(movementRef, {
        'productId': data['productId'],
        'productName': data['productName'],
        'batchId': batchId,
        'type': MovementType.entrada.name,
        'quantity': amount,
        'reasonCode': 'acrescimo_lote',
        'reason': 'Unidades acrescentadas ao lote',
        'performedBy': performedBy,
        'performedByName': performedByName,
        'performedAt': now,
        'isPendingSync': false,
        'auditBefore': {'quantity': before, 'status': oldStatus},
        'auditAfter': {'quantity': after, 'status': 'disponivel'},
      });
      tx.set(_auditLogs.doc('${movementRef.id}_audit'), {
        'collection': 'batches',
        'documentId': batchId,
        'action': 'entrada',
        'before': {'quantity': before, 'status': oldStatus},
        'after': {'quantity': after, 'status': 'disponivel'},
        'performedBy': performedBy,
        'performedByName': performedByName,
        'performedAt': now,
      });
      return after;
    });
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
