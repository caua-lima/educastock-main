import '../entities/risk_prediction.dart';
import '../../../batches/domain/entities/batch.dart';

abstract interface class RiskClassifierRepository {
  /// Classifica um único lote e retorna a predição.
  Future<RiskPrediction> classify(Batch batch);

  /// Classifica vários lotes em batch.
  Future<List<RiskPrediction>> classifyAll(List<Batch> batches);

  /// Indica se o classificador está disponível e pronto.
  Future<bool> get isAvailable;
}
