import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../donations/domain/entities/donation.dart';
import '../../donations/domain/entities/donation_item.dart';
import '../../donations/domain/entities/donation_status.dart';
import '../../products/domain/entities/product.dart';

/// Quantidade conferida de um item no recebimento (tela S03).
class ReceivedItemInput {
  final int index;
  final int receivedQty;
  final DateTime? expiryDate;
  final String? note;

  const ReceivedItemInput({
    required this.index,
    required this.receivedQty,
    this.expiryDate,
    this.note,
  });
}

class DonationOpsException implements Exception {
  final String message;
  const DonationOpsException(this.message);

  @override
  String toString() => message;
}

/// Operações da equipe sobre as doações (S01 a S03).
///
/// Cada ação roda em **transação** e faz, no próprio cliente, o que as Cloud Functions
/// fazem quando estão publicadas (protocolo, reserva de quantidade, linha do tempo,
/// auditoria e aviso ao doador). As gravações levam o marcador `clientProcessedStatus`
/// para as funções não repetirem o trabalho.
class DonationOpsRepository {
  final FirebaseFirestore _db;

  DonationOpsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _donations => _db.collection('donations');
  CollectionReference<Map<String, dynamic>> get _needs => _db.collection('donation_needs');
  CollectionReference<Map<String, dynamic>> get _products => _db.collection('products');
  CollectionReference<Map<String, dynamic>> get _batches => _db.collection('batches');
  CollectionReference<Map<String, dynamic>> get _movements => _db.collection('stock_movements');
  CollectionReference<Map<String, dynamic>> get _audit => _db.collection('audit_logs');
  DocumentReference<Map<String, dynamic>> get _counters => _db.doc('settings/counters');

  static const _queueStatuses = ['pendente', 'aprovada', 'recebida', 'recebida_parcial'];

  /// Fila da equipe: tudo que ainda exige uma ação (decidir, receber ou destinar).
  /// Filtra só por status (sem `orderBy`) para não depender de índice composto; a
  /// ordenação por data é feita aqui.
  /// Id da doação com o [protocol] (QR Code apresentado pelo doador na entrega), ou null.
  Future<String?> findIdByProtocol(String protocol) async {
    final snap = await _donations.where('protocol', isEqualTo: protocol).limit(1).get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  Stream<List<Donation>> watchQueue({int limit = 200}) {
    return _donations
        .where('status', whereIn: _queueStatuses)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => Donation.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
      return list;
    });
  }

  // ─── S02: decidir ──────────────────────────────────────────────────────────

  Future<void> decide({
    required String donationId,
    required bool approve,
    required AppUser actor,
    String? message,
    String? refusalReason,
  }) async {
    final ref = _donations.doc(donationId);
    final next = approve ? DonationStatus.aprovada : DonationStatus.recusada;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) throw const DonationOpsException('Doação não encontrada.');
      final current = DonationStatus.fromValue(data['status'] as String?);
      if (!current.canTransitionTo(next)) {
        throw DonationOpsException(
          'Esta doação já está "${current.label}" e não pode mais ser decidida.',
        );
      }

      final plan = await _planProtocol(tx, data);
      final protocol = plan.protocol;
      final pledges = _pledgesOf(data);
      final applied = data['reservationApplied'] == true;
      final released = data['reservationReleased'] == true;
      // Reserva de quantidade prometida (RN-D05): aplica ao aprovar, se ninguém aplicou;
      // devolve ao recusar, se já tinha sido aplicada.
      final needSnaps = (approve && !applied) || (!approve && applied && !released)
          ? await _readNeeds(tx, pledges.keys)
          : const <DocumentSnapshot<Map<String, dynamic>>>[];

      _commitProtocol(tx, plan);
      _writePledges(tx, needSnaps, pledges, approve ? 1 : -1);

      final trimmedMessage = message?.trim();
      tx.update(ref, {
        'status': next.value,
        'protocol': protocol,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor.id,
        'updatedByName': actor.name,
        'updatedByRole': actor.role.name,
        'clientProcessedStatus': next.value,
        if (approve && trimmedMessage != null && trimmedMessage.isNotEmpty)
          'approvalMessage': trimmedMessage,
        if (!approve) 'refusalReason': (refusalReason?.trim().isNotEmpty ?? false) ? refusalReason!.trim() : trimmedMessage,
        if (approve && !applied) ...{'reservationApplied': true, 'reservationReleased': false},
        if (!approve && applied && !released) 'reservationReleased': true,
      });

      _writeEvent(tx, ref, actor, current, next, note: approve ? trimmedMessage : (refusalReason ?? trimmedMessage));
      _writeAudit(tx, donationId, actor, 'donation_${next.value}', current, next);
      _writeNotification(
        tx,
        donorId: data['donorId'] as String? ?? '',
        donationId: donationId,
        status: next,
        protocol: protocol,
        extra: approve ? trimmedMessage : (refusalReason ?? trimmedMessage),
      );
    });
  }

  // ─── S03: receber, dar entrada no estoque e destinar ───────────────────────

  Future<void> receive({
    required Donation donation,
    required AppUser actor,
    required List<ReceivedItemInput> received,
    String? sector,
    String? impactMessage,
    DateTime? usedAt,
  }) async {
    final byIndex = {for (final r in received) r.index: r};
    final total = donation.items.length;

    // Valida antes de qualquer gravação.
    var anyReceived = false;
    var allFull = true;
    for (var i = 0; i < total; i++) {
      final item = donation.items[i];
      final r = byIndex[i];
      final qty = r?.receivedQty ?? 0;
      if (qty < 0) throw DonationOpsException('Quantidade inválida em "${item.description}".');
      if (qty > 0) anyReceived = true;
      if (qty != item.quantity) {
        allFull = false;
        if ((r?.note ?? '').trim().isEmpty) {
          throw DonationOpsException(
            'Explique a divergência de "${item.description}" (prometido ${item.quantity}, conferido $qty).',
          );
        }
      }
      if (qty > 0 && item.hasExpiry && r?.expiryDate == null) {
        throw DonationOpsException('Informe a validade de "${item.description}".');
      }
    }
    if (!anyReceived) {
      throw const DonationOpsException('Nenhum item foi conferido. Para não receber nada, recuse ou cancele a doação.');
    }
    final hasImpact = (sector ?? '').trim().isNotEmpty && (impactMessage ?? '').trim().isNotEmpty;

    // Produto de cada item (fora da transação: pode precisar criar o cadastro).
    final productIds = <int, ({String id, String name})>{};
    for (var i = 0; i < total; i++) {
      if ((byIndex[i]?.receivedQty ?? 0) > 0) {
        productIds[i] = await _resolveProduct(donation.items[i], actor);
      }
    }

    final ref = _donations.doc(donation.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null) throw const DonationOpsException('Doação não encontrada.');
      final current = DonationStatus.fromValue(data['status'] as String?);
      final next = allFull ? DonationStatus.recebida : DonationStatus.recebidaParcial;
      if (!current.canTransitionTo(next)) {
        throw DonationOpsException(
          current.isConcluded
              ? 'Esta doação já foi recebida.'
              : 'Só doações aprovadas podem ser recebidas (esta está "${current.label}").',
        );
      }

      final plan = await _planProtocol(tx, data);
      final protocol = plan.protocol;
      final pledges = _pledgesOf(data);
      final needsRelease = data['reservationApplied'] == true && data['reservationReleased'] != true;
      final needSnaps = needsRelease
          ? await _readNeeds(tx, pledges.keys)
          : const <DocumentSnapshot<Map<String, dynamic>>>[];

      _commitProtocol(tx, plan);
      final now = DateTime.now();
      final receivedInfo = <Map<String, dynamic>>[];
      for (var i = 0; i < total; i++) {
        final r = byIndex[i];
        final qty = r?.receivedQty ?? 0;
        String? batchId;
        if (qty > 0) {
          final item = donation.items[i];
          final product = productIds[i]!;
          final batchRef = _batches.doc();
          batchId = batchRef.id;
          final expiry = item.hasExpiry ? r?.expiryDate : null;
          tx.set(batchRef, {
            'productId': product.id,
            'productName': product.name,
            'quantity': qty,
            'initialQuantity': qty,
            'expiryDate': expiry?.toIso8601String(),
            'noExpiry': !item.hasExpiry,
            'entryDate': now.toIso8601String(),
            'origin': 'doacao',
            'donor': donation.donorSnapshot.displayName,
            'donorId': donation.donorId,
            'donationId': donation.id,
            'notes': 'Doação $protocol',
            'status': 'disponivel',
            'createdBy': actor.id,
            'createdAt': now.toIso8601String(),
          });
          tx.set(_movements.doc(), {
            'productId': product.id,
            'productName': product.name,
            'batchId': batchId,
            'type': 'entrada',
            'quantity': qty,
            'reasonCode': 'doacao',
            'reason': 'Doação $protocol',
            'activity': null,
            'performedBy': actor.id,
            'performedByName': actor.name,
            'performedAt': now.toIso8601String(),
            'isPendingSync': false,
            'auditBefore': null,
            'auditAfter': {'quantity': qty},
          });
          tx.set(_audit.doc(), {
            'collection': 'batches',
            'documentId': batchId,
            'action': 'entrada',
            'before': null,
            'after': {'quantity': qty, 'origin': 'doacao', 'donationId': donation.id},
            'performedBy': actor.id,
            'performedByName': actor.name,
            'performedAt': now.toIso8601String(),
          });
        }
        receivedInfo.add({
          'index': i,
          'receivedQty': qty,
          'batchId': batchId,
          'note': (r?.note ?? '').trim().isEmpty ? null : r!.note!.trim(),
        });
      }

      if (needsRelease) _writePledges(tx, needSnaps, pledges, -1);

      final impact = hasImpact
          ? DonationImpact(
              sector: sector!.trim(),
              message: impactMessage!.trim(),
              usedAt: usedAt ?? now,
              byName: actor.name,
            ).toMap()
          : null;

      tx.update(ref, {
        'status': next.value,
        'protocol': protocol,
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedItems': receivedInfo,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': actor.id,
        'updatedByName': actor.name,
        'updatedByRole': actor.role.name,
        'clientProcessedStatus': next.value,
        if (impact != null) 'impact': impact,
        if (needsRelease) 'reservationReleased': true,
      });

      _writeEvent(tx, ref, actor, current, next, note: protocol);
      if (impact != null) {
        tx.set(ref.collection('events').doc(), {
          'type': 'impact_registered',
          'fromStatus': next.value,
          'toStatus': next.value,
          'by': actor.id,
          'byRole': actor.role.name,
          'note': sector!.trim(),
          'at': FieldValue.serverTimestamp(),
        });
      }
      _writeAudit(tx, donation.id, actor, 'donation_${next.value}', current, next);
      _writeNotification(
        tx,
        donorId: donation.donorId,
        donationId: donation.id,
        status: next,
        protocol: protocol,
        extra: hasImpact ? impactMessage!.trim() : null,
      );
    });
  }

  /// Registra (ou corrige) o destino e a mensagem de impacto de uma doação já recebida.
  Future<void> saveImpact({
    required Donation donation,
    required AppUser actor,
    required String sector,
    required String message,
    DateTime? usedAt,
  }) async {
    if (!donation.status.isConcluded) {
      throw const DonationOpsException('O destino só pode ser registrado depois do recebimento.');
    }
    if (sector.trim().isEmpty || message.trim().isEmpty) {
      throw const DonationOpsException('Informe o setor de destino e a mensagem de impacto.');
    }
    final ref = _donations.doc(donation.id);
    final impact = DonationImpact(
      sector: sector.trim(),
      message: message.trim(),
      usedAt: usedAt ?? DateTime.now(),
      byName: actor.name,
    ).toMap();

    final batch = _db.batch();
    batch.update(ref, {
      'impact': impact,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actor.id,
      'updatedByName': actor.name,
      'updatedByRole': actor.role.name,
    });
    batch.set(ref.collection('events').doc(), {
      'type': 'impact_registered',
      'fromStatus': donation.status.value,
      'toStatus': donation.status.value,
      'by': actor.id,
      'byRole': actor.role.name,
      'note': sector.trim(),
      'at': FieldValue.serverTimestamp(),
    });
    batch.set(
      _db.collection('user_notifications').doc(donation.donorId).collection('items').doc(),
      {
        'title': 'Veja o impacto da sua doação',
        'body': message.trim(),
        'donationId': donation.id,
        'status': donation.status.value,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  // ─── Internos ──────────────────────────────────────────────────────────────

  /// Mantém o protocolo se a função já o gerou; senão, gera o próximo `DOA-AAAA-NNNNNN`
  /// com o mesmo contador (`settings/counters`). Precisa ser a primeira leitura.
  Future<_ProtocolPlan> _planProtocol(
    Transaction tx,
    Map<String, dynamic> donation,
  ) async {
    final existing = donation['protocol'] as String?;
    if (existing != null && existing.isNotEmpty) return _ProtocolPlan(existing);
    final year = DateTime.now().year;
    final snap = await tx.get(_counters);
    final current = (snap.data()?['donations_$year'] as num?)?.toInt() ?? 0;
    final next = current + 1;
    return _ProtocolPlan(
      'DOA-$year-${next.toString().padLeft(6, '0')}',
      counterField: 'donations_$year',
      counterValue: next,
    );
  }

  /// Grava o novo valor do contador (só se o protocolo foi gerado agora).
  void _commitProtocol(Transaction tx, _ProtocolPlan plan) {
    final field = plan.counterField;
    if (field == null) return;
    tx.set(_counters, {field: plan.counterValue}, SetOptions(merge: true));
  }

  Map<String, int> _pledgesOf(Map<String, dynamic> donation) {
    final pledges = <String, int>{};
    for (final raw in (donation['items'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final needId = raw['needId'] as String?;
      final qty = (raw['quantity'] as num?)?.toInt() ?? 0;
      if (needId == null || needId.isEmpty || qty <= 0) continue;
      pledges[needId] = (pledges[needId] ?? 0) + qty;
    }
    return pledges;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _readNeeds(
    Transaction tx,
    Iterable<String> ids,
  ) {
    return Future.wait(ids.map((id) => tx.get(_needs.doc(id))));
  }

  void _writePledges(
    Transaction tx,
    List<DocumentSnapshot<Map<String, dynamic>>> snaps,
    Map<String, int> pledges,
    int direction,
  ) {
    for (final snap in snaps) {
      final data = snap.data();
      if (!snap.exists || data == null) continue;
      final qty = pledges[snap.id] ?? 0;
      final suggested = (data['suggestedQty'] as num?)?.toInt() ?? 0;
      final pledged = ((data['pledgedQty'] as num?)?.toInt() ?? 0) + direction * qty;
      final safePledged = pledged < 0 ? 0 : pledged;
      tx.update(snap.reference, {
        'pledgedQty': safePledged,
        'remainingQty': suggested - safePledged < 0 ? 0 : suggested - safePledged,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _writeEvent(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
    AppUser actor,
    DonationStatus from,
    DonationStatus to, {
    String? note,
  }) {
    tx.set(ref.collection('events').doc(), {
      'type': 'status_changed',
      'fromStatus': from.value,
      'toStatus': to.value,
      'by': actor.id,
      'byRole': actor.role.name,
      'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      'at': FieldValue.serverTimestamp(),
    });
  }

  void _writeAudit(
    Transaction tx,
    String donationId,
    AppUser actor,
    String action,
    DonationStatus from,
    DonationStatus to,
  ) {
    tx.set(_audit.doc(), {
      'collection': 'donations',
      'documentId': donationId,
      'action': action,
      'before': {'status': from.value},
      'after': {'status': to.value},
      'performedBy': actor.id,
      'performedByName': actor.name,
      'performedAt': DateTime.now().toIso8601String(),
    });
  }

  static const _notificationText = {
    DonationStatus.aprovada: (
      'Doação aprovada',
      'A equipe aprovou sua doação. Veja onde e quando entregar.',
    ),
    DonationStatus.recusada: (
      'Doação recusada',
      'A equipe não pôde aceitar esta doação. Veja o motivo no aplicativo.',
    ),
    DonationStatus.recebida: (
      'Doação recebida',
      'Recebemos sua doação. Obrigado por ajudar a Casa da Criança!',
    ),
    DonationStatus.recebidaParcial: (
      'Doação recebida parcialmente',
      'Recebemos parte da sua doação. Veja os detalhes no aplicativo.',
    ),
  };

  void _writeNotification(
    Transaction tx, {
    required String donorId,
    required String donationId,
    required DonationStatus status,
    required String protocol,
    String? extra,
  }) {
    final text = _notificationText[status];
    if (text == null || donorId.isEmpty) return;
    final more = (extra?.trim().isNotEmpty ?? false) ? ' ${extra!.trim()}' : '';
    tx.set(
      _db.collection('user_notifications').doc(donorId).collection('items').doc(),
      {
        'title': text.$1,
        'body': '${text.$2} ($protocol)$more',
        'donationId': donationId,
        'status': status.value,
        'readAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  /// Acha o produto do estoque correspondente ao item doado: o da necessidade, um de
  /// mesmo nome, ou cria um cadastro novo.
  Future<({String id, String name})> _resolveProduct(DonationItem item, AppUser actor) async {
    final needId = item.needId;
    if (needId != null && needId.isNotEmpty) {
      final need = (await _needs.doc(needId).get()).data();
      final productId = need?['productId'] as String?;
      if (productId != null && productId.isNotEmpty) {
        final product = (await _products.doc(productId).get()).data();
        if (product != null) {
          return (id: productId, name: product['name'] as String? ?? item.description);
        }
      }
    }
    final name = item.description.trim();
    final found = await _products.where('name', isEqualTo: name).limit(1).get();
    if (found.docs.isNotEmpty) return (id: found.docs.first.id, name: name);

    final category = ProductCategory.values.firstWhere(
      (c) => c.name == item.category,
      orElse: () => ProductCategory.outro,
    );
    final created = await _products.add({
      'name': name,
      'brand': null,
      'category': category.name,
      'unit': item.unit,
      'barcode': null,
      'imageUrl': null,
      'description': 'Cadastrado automaticamente a partir de uma doação.',
      'isPerishable': item.hasExpiry,
      'minimumStock': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': actor.id,
      'isActive': true,
    });
    return (id: created.id, name: name);
  }
}

class _ProtocolPlan {
  final String protocol;
  final String? counterField;
  final int counterValue;

  const _ProtocolPlan(this.protocol, {this.counterField, this.counterValue = 0});
}
