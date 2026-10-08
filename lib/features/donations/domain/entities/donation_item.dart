import 'donation_dates.dart';

enum ItemCondition {
  novo('novo', 'Novo'),
  usado('usado', 'Usado em bom estado');

  const ItemCondition(this.value, this.label);
  final String value;
  final String label;

  static ItemCondition fromValue(String? raw) => ItemCondition.values
      .firstWhere((c) => c.value == raw, orElse: () => ItemCondition.novo);
}

/// Item de uma doação (elemento de `donations/{id}.items[]`).
class DonationItem {
  final String? needId;
  final String category; // ProductCategory.name
  final String description;
  final int quantity;
  final String unit;
  final DateTime? expiryDate;
  final bool hasExpiry;
  final ItemCondition condition;

  /// Validade abaixo do mínimo (RN-D03): segue "sujeito a avaliação" da equipe.
  final bool subjectToReview;

  const DonationItem({
    this.needId,
    required this.category,
    required this.description,
    required this.quantity,
    this.unit = 'un',
    this.expiryDate,
    this.hasExpiry = true,
    this.condition = ItemCondition.novo,
    this.subjectToReview = false,
  });

  factory DonationItem.fromMap(Map<String, dynamic> map) {
    return DonationItem(
      needId: map['needId'] as String?,
      category: map['category'] as String? ?? 'outro',
      description: map['description'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? 'un',
      expiryDate: parseDonationDate(map['expiryDate']),
      hasExpiry: map['hasExpiry'] as bool? ?? true,
      condition: ItemCondition.fromValue(map['condition'] as String?),
      subjectToReview: map['subjectToReview'] as bool? ?? false,
    );
  }

  /// Serialização para o Firestore (datas como Timestamp).
  Map<String, dynamic> toMap() => {
        'needId': needId,
        'category': category,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'expiryDate': toTimestamp(expiryDate),
        'hasExpiry': hasExpiry,
        'condition': condition.value,
        'subjectToReview': subjectToReview,
      };

  /// Serialização para o rascunho local (JSON puro, sem Timestamp).
  Map<String, dynamic> toJson() => {
        'needId': needId,
        'category': category,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'expiryDate': expiryDate?.toIso8601String(),
        'hasExpiry': hasExpiry,
        'condition': condition.value,
        'subjectToReview': subjectToReview,
      };

  DonationItem copyWith({
    String? needId,
    String? category,
    String? description,
    int? quantity,
    String? unit,
    DateTime? expiryDate,
    bool clearExpiry = false,
    bool? hasExpiry,
    ItemCondition? condition,
    bool? subjectToReview,
  }) =>
      DonationItem(
        needId: needId ?? this.needId,
        category: category ?? this.category,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
        hasExpiry: hasExpiry ?? this.hasExpiry,
        condition: condition ?? this.condition,
        subjectToReview: subjectToReview ?? this.subjectToReview,
      );
}
