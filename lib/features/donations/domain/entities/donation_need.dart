import 'donation_dates.dart';

/// Prioridade da necessidade (RN-D04). `rank` alimenta `priorityRank` no
/// Firestore (1 = mais urgente) e a ordenação do painel.
enum NeedPriority {
  critica('critica', 'Crítica', 1),
  alta('alta', 'Alta', 2),
  normal('normal', 'Normal', 3);

  const NeedPriority(this.value, this.label, this.rank);
  final String value;
  final String label;
  final int rank;

  static NeedPriority fromValue(String? raw) => NeedPriority.values
      .firstWhere((p) => p.value == raw, orElse: () => NeedPriority.normal);
}

enum NeedSource {
  auto('auto'),
  manual('manual');

  const NeedSource(this.value);
  final String value;

  static NeedSource fromValue(String? raw) => NeedSource.values
      .firstWhere((s) => s.value == raw, orElse: () => NeedSource.manual);
}

/// Necessidade da ONG exibida ao doador — documento `donation_needs/{id}`.
class DonationNeed {
  final String id;
  final NeedSource source;
  final String? productId;
  final String categoryId; // ProductCategory.name
  final String title; // nome exibido ao doador
  final String unit;
  final NeedPriority priority;
  final int priorityRank;
  final int suggestedQty;
  final int pledgedQty;
  final int remainingQty;
  final int minShelfLifeDays;
  final DateTime? validUntil;
  final bool isActive;
  final String? note;
  final DateTime? updatedAt;

  const DonationNeed({
    required this.id,
    this.source = NeedSource.manual,
    this.productId,
    required this.categoryId,
    required this.title,
    this.unit = 'un',
    required this.priority,
    required this.priorityRank,
    required this.suggestedQty,
    required this.pledgedQty,
    required this.remainingQty,
    this.minShelfLifeDays = 0,
    this.validUntil,
    this.isActive = true,
    this.note,
    this.updatedAt,
  });

  /// Atendida quando não resta nada a cobrir (some do painel ou vira "atendida").
  bool get isCovered => remainingQty <= 0;

  /// Progresso 0..1 de quanto da meta já foi prometido.
  double get pledgedProgress =>
      suggestedQty <= 0 ? 1.0 : (pledgedQty / suggestedQty).clamp(0.0, 1.0);

  factory DonationNeed.fromMap(Map<String, dynamic> map, String id) {
    final priority = NeedPriority.fromValue(map['priority'] as String?);
    final suggested = (map['suggestedQty'] as num?)?.toInt() ?? 0;
    final pledged = (map['pledgedQty'] as num?)?.toInt() ?? 0;
    final int remaining = (map['remainingQty'] as num?)?.toInt() ??
        (suggested - pledged < 0 ? 0 : suggested - pledged);
    return DonationNeed(
      id: id,
      source: NeedSource.fromValue(map['source'] as String?),
      productId: map['productId'] as String?,
      categoryId: map['categoryId'] as String? ?? 'outro',
      title: (map['title'] as String?) ??
          (map['productName'] as String?) ??
          'Item sem nome',
      unit: map['unit'] as String? ?? 'un',
      priority: priority,
      priorityRank: (map['priorityRank'] as num?)?.toInt() ?? priority.rank,
      suggestedQty: suggested,
      pledgedQty: pledged,
      remainingQty: remaining,
      minShelfLifeDays: (map['minShelfLifeDays'] as num?)?.toInt() ?? 0,
      validUntil: parseDonationDate(map['validUntil']),
      isActive: map['isActive'] as bool? ?? true,
      note: map['note'] as String?,
      updatedAt: parseDonationDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'source': source.value,
        'productId': productId,
        'categoryId': categoryId,
        'title': title,
        'unit': unit,
        'priority': priority.value,
        'priorityRank': priorityRank,
        'suggestedQty': suggestedQty,
        'pledgedQty': pledgedQty,
        'remainingQty': remainingQty,
        'minShelfLifeDays': minShelfLifeDays,
        'validUntil': validUntil?.toIso8601String(),
        'isActive': isActive,
        'note': note,
      };
}
