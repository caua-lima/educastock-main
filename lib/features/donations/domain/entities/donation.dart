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
  });

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
