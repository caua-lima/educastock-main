import 'package:cloud_firestore/cloud_firestore.dart';
import 'donation_dates.dart';
import 'donation_item.dart';
import 'donation_status.dart';

/// Janela de entrega escolhida pelo doador (`donations/{id}.window`).
class DonationWindow {
  final DateTime from;
  final DateTime to;

  const DonationWindow({required this.from, required this.to});

  factory DonationWindow.fromMap(Map<String, dynamic> map) {
    final from = parseDonationDate(map['from']) ?? DateTime.now();
    final to = parseDonationDate(map['to']) ?? from;
    return DonationWindow(from: from, to: to);
  }

  Map<String, dynamic> toMap() => {
        'from': Timestamp.fromDate(from),
        'to': Timestamp.fromDate(to),
      };

  Map<String, dynamic> toJson() => {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      };
}

/// Resumo do doador gravado na doação (evita ler `donors` na fila da equipe).
class DonorSnapshot {
  final String displayName;
  final String? phone;

  const DonorSnapshot({required this.displayName, this.phone});

  factory DonorSnapshot.fromMap(Map<String, dynamic>? map) => DonorSnapshot(
        displayName: map?['displayName'] as String? ?? 'Doador',
        phone: map?['phone'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'phone': phone,
      };
}

/// Destino e mensagem de impacto registrados pela equipe (tela S03) e mostrados
/// ao doador no relatório de impacto (D09).
class DonationImpact {
  final String sector;
  final String message;
  final DateTime? usedAt;
  final String? byName;

  const DonationImpact({
    required this.sector,
    required this.message,
    this.usedAt,
    this.byName,
  });

  factory DonationImpact.fromMap(Map<String, dynamic> map) => DonationImpact(
        sector: map['sector'] as String? ?? '',
        message: map['message'] as String? ?? '',
        usedAt: parseDonationDate(map['usedAt']),
        byName: map['byName'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'sector': sector,
        'message': message,
        'usedAt': toTimestamp(usedAt),
        'byName': byName,
      };
}

/// Conferência de um item no recebimento (`donations/{id}.receivedItems[]`).
class ReceivedItemInfo {
  final int index;
  final int receivedQty;
  final String? batchId;
  final String? note;

  const ReceivedItemInfo({
    required this.index,
    required this.receivedQty,
    this.batchId,
    this.note,
  });

  factory ReceivedItemInfo.fromMap(Map<String, dynamic> map) => ReceivedItemInfo(
        index: (map['index'] as num?)?.toInt() ?? 0,
        receivedQty: (map['receivedQty'] as num?)?.toInt() ?? 0,
        batchId: map['batchId'] as String?,
        note: map['note'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'index': index,
        'receivedQty': receivedQty,
        'batchId': batchId,
        'note': note,
      };
}

/// Intenção formal de doação — documento `donations/{id}`.
class Donation {
  final String id;

  /// `DOA-AAAA-NNNNNN`, gerado por `onDonationCreated` (vazio até a função rodar).
  final String protocol;
  final String donorId;
  final DonorSnapshot donorSnapshot;
  final DonationStatus status;
  final List<DonationItem> items;
  final String pointId;
  final DonationWindow? window;
  final DateTime? termsAcceptedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? cancelReason;
  final String? refusalReason;

  /// Mensagem opcional da equipe ao doador, enviada junto da aprovação (S02).
  final String? approvalMessage;
  final DateTime? receivedAt;
  final List<ReceivedItemInfo> receivedItems;
  final DonationImpact? impact;

  const Donation({
    required this.id,
    this.protocol = '',
    required this.donorId,
    required this.donorSnapshot,
    required this.status,
    required this.items,
    required this.pointId,
    this.window,
    this.termsAcceptedAt,
    this.createdAt,
    this.updatedAt,
    this.cancelReason,
    this.refusalReason,
    this.approvalMessage,
    this.receivedAt,
    this.receivedItems = const [],
    this.impact,
  });

  /// Recebida mas ainda sem destino/impacto registrado (aba "Para destinar").
  bool get needsDestination => status.isConcluded && impact == null;

  int get totalUnits => items.fold(0, (total, item) => total + item.quantity);

  String get displayProtocol => protocol.isEmpty ? 'Gerando protocolo…' : protocol;

  factory Donation.fromMap(Map<String, dynamic> map, String id) {
    final rawItems = (map['items'] as List?) ?? const [];
    final rawWindow = map['window'];
    return Donation(
      id: id,
      protocol: map['protocol'] as String? ?? '',
      donorId: map['donorId'] as String? ?? '',
      donorSnapshot: DonorSnapshot.fromMap(
          (map['donorSnapshot'] as Map?)?.cast<String, dynamic>()),
      status: DonationStatus.fromValue(map['status'] as String?),
      items: rawItems
          .whereType<Map>()
          .map((e) => DonationItem.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false),
      pointId: map['pointId'] as String? ?? '',
      window: rawWindow is Map
          ? DonationWindow.fromMap(rawWindow.cast<String, dynamic>())
          : null,
      termsAcceptedAt: parseDonationDate(map['termsAcceptedAt']),
      createdAt: parseDonationDate(map['createdAt']),
      updatedAt: parseDonationDate(map['updatedAt']),
      cancelReason: map['cancelReason'] as String?,
      refusalReason: map['refusalReason'] as String?,
      approvalMessage: map['approvalMessage'] as String?,
      receivedAt: parseDonationDate(map['receivedAt']),
      receivedItems: ((map['receivedItems'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ReceivedItemInfo.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false),
      impact: map['impact'] is Map
          ? DonationImpact.fromMap((map['impact'] as Map).cast<String, dynamic>())
          : null,
    );
  }

  /// Payload de criação (RF20): status inicial `pendente`; timestamps do servidor.
  Map<String, dynamic> toCreateMap() => {
        'donorId': donorId,
        'donorSnapshot': donorSnapshot.toMap(),
        'status': DonationStatus.pendente.value,
        'items': items.map((i) => i.toMap()).toList(),
        'pointId': pointId,
        'window': window?.toMap(),
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
