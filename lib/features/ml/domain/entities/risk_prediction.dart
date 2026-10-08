import '../../../../features/batches/domain/entities/batch.dart';

enum RiskLevel {
  verde,
  amarelo,
  vermelho;

  String get label {
    switch (this) {
      case RiskLevel.verde:
        return 'Seguro';
      case RiskLevel.amarelo:
        return 'Atenção';
      case RiskLevel.vermelho:
        return 'Crítico';
    }
  }

  String get description {
    switch (this) {
      case RiskLevel.verde:
        return 'Lote em condições normais.';
      case RiskLevel.amarelo:
        return 'Vencimento se aproximando ou estoque baixo.';
      case RiskLevel.vermelho:
        return 'Risco iminente de perda. Priorize a distribuição.';
    }
  }
}

class RiskPrediction {
  final String batchId;
  final String productName;
  final RiskLevel level;

  /// Probabilidades [verde, amarelo, vermelho] — somam 1.0
  final List<double> probabilities;

  /// Origem da classificação (rule_based | tflite)
  final String source;

  const RiskPrediction({
    required this.batchId,
    required this.productName,
    required this.level,
    required this.probabilities,
    required this.source,
  });

  double get confidence => probabilities.isNotEmpty ? probabilities[level.index] : 0;
}

/// Vetor de features normalizado para o classificador
class BatchFeatures {
  /// days_to_expiry / 365 (0..1, 1 = sem validade)
  final double daysToExpiryNorm;

  /// current_quantity / initial_quantity
  final double quantityRatio;

  /// days_since_entry / 365 (0..1)
  final double daysSinceEntryNorm;

  /// 1.0 = sem validade (noExpiry), 0.0 = perecível
  final double isNoExpiry;

  const BatchFeatures({
    required this.daysToExpiryNorm,
    required this.quantityRatio,
    required this.daysSinceEntryNorm,
    required this.isNoExpiry,
  });

  List<double> toList() => [daysToExpiryNorm, quantityRatio, daysSinceEntryNorm, isNoExpiry];

  factory BatchFeatures.fromBatch(Batch b) {
    const maxDays = 365.0;
    final daysToExpiry = b.noExpiry ? maxDays : b.daysToExpiry.clamp(0, maxDays).toDouble();
    final initialQty = b.initialQuantity > 0 ? b.initialQuantity : b.quantity;
    final quantityRatio = (b.quantity / initialQty).clamp(0.0, 1.0);
    final daysSinceEntry = DateTime.now().difference(b.entryDate).inDays;
    final daysSinceEntryNorm = (daysSinceEntry / maxDays).clamp(0.0, 1.0);

    return BatchFeatures(
      daysToExpiryNorm: daysToExpiry / maxDays,
      quantityRatio: quantityRatio,
      daysSinceEntryNorm: daysSinceEntryNorm,
      isNoExpiry: b.noExpiry ? 1.0 : 0.0,
    );
  }
}
