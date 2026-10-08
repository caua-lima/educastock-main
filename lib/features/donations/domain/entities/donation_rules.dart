/// Regras configuráveis de doação — documento `settings/donation_rules`.
/// Os padrões abaixo valem enquanto a coordenação não configurar o documento.
class DonationRules {
  final int minShelfLifeDays;
  final int maxOpenPledges;
  final int maxItems;
  final List<String> blockedCategories;

  const DonationRules({
    this.minShelfLifeDays = 30,
    this.maxOpenPledges = 3,
    this.maxItems = 20,
    this.blockedCategories = const [],
  });

  factory DonationRules.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DonationRules();
    final blocked = (map['blockedCategories'] as List?) ?? const [];
    return DonationRules(
      minShelfLifeDays: (map['minShelfLifeDays'] as num?)?.toInt() ?? 30,
      maxOpenPledges: (map['maxOpenPledges'] as num?)?.toInt() ?? 3,
      maxItems: (map['maxItems'] as num?)?.toInt() ?? 20,
      blockedCategories: blocked.whereType<String>().toList(growable: false),
    );
  }

  bool isCategoryBlocked(String categoryId) =>
      blockedCategories.contains(categoryId);
}
