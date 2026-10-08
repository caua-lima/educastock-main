import '../../domain/entities/risk_prediction.dart';
import '../../domain/repositories/risk_classifier_repository.dart';
import '../../../batches/domain/entities/batch.dart';

/// Classificador baseado em regras determinísticas.
/// Funciona em todas as plataformas (web, Android, iOS, desktop).
/// Serve como fallback quando o modelo TFLite não está disponível
/// e como baseline para comparação.
class RuleBasedRiskClassifier implements RiskClassifierRepository {
  static const String _source = 'rule_based';

  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<RiskPrediction> classify(Batch batch) async {
    return _classifySync(batch);
  }

  @override
  Future<List<RiskPrediction>> classifyAll(List<Batch> batches) async {
    return batches.map(_classifySync).toList();
  }

  /// Variante síncrona pública — útil para previews em formulários,
  /// onde queremos classificar sem await/FutureBuilder.
  RiskPrediction classifySync(Batch batch) => _classifySync(batch);

  RiskPrediction _classifySync(Batch batch) {
    final f = BatchFeatures.fromBatch(batch);
    final (level, probs) = _applyRules(batch, f);

    return RiskPrediction(
      batchId: batch.id,
      productName: batch.productName,
      level: level,
      probabilities: probs,
      source: _source,
    );
  }

  (RiskLevel, List<double>) _applyRules(Batch batch, BatchFeatures f) {
    // Sem validade → sempre verde
    if (batch.noExpiry) {
      return (RiskLevel.verde, [0.9, 0.08, 0.02]);
    }

    // Vencido
    if (batch.isExpired) {
      return (RiskLevel.vermelho, [0.02, 0.08, 0.90]);
    }

    final days = batch.daysToExpiry;

    // Crítico: vence em até 7 dias
    if (days <= 7) {
      final urgency = (7 - days) / 7.0;
      final pR = (0.55 + 0.35 * urgency).clamp(0.0, 1.0);
      final pA = ((1.0 - pR) * 0.6).clamp(0.0, 1.0);
      final pV = (1.0 - pR - pA).clamp(0.0, 1.0);
      return (RiskLevel.vermelho, [pV, pA, pR]);
    }

    // Atenção: vence em 8..30 dias
    if (days <= 30) {
      // Penalidade extra se quantidade alta e saída lenta
      final slowMoving = f.quantityRatio > 0.8 && f.daysSinceEntryNorm > 0.05;
      if (slowMoving && days <= 20) {
        return (RiskLevel.vermelho, [0.08, 0.22, 0.70]);
      }
      return (RiskLevel.amarelo, [0.12, 0.72, 0.16]);
    }

    // Verde com alerta de giro baixo
    // Lote antigo (>60d em estoque) com >80% da quantidade intacta
    final stale = f.daysSinceEntryNorm > (60 / 365) && f.quantityRatio > 0.8;
    if (stale && days <= 90) {
      return (RiskLevel.amarelo, [0.20, 0.68, 0.12]);
    }

    // Ok
    return (RiskLevel.verde, [0.82, 0.14, 0.04]);
  }
}
