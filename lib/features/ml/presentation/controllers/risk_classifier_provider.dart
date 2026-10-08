import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/risk_prediction.dart';
import '../../data/repositories/rule_based_risk_classifier.dart';
import '../../data/repositories/risk_classification_firestore_repository.dart';
import '../../../../features/batches/domain/entities/batch.dart';
import '../../../../features/batches/presentation/controllers/batches_provider.dart';

// ---------------------------------------------------------------------------
// Repositório do Firestore (singleton)
// ---------------------------------------------------------------------------
//
// O ML #1 (Classificação de Risco) NÃO roda mais no dispositivo.
// O modelo Random Forest é treinado no Colab e grava o resultado por lote
// na coleção `risk_classifications` do Firestore. O app apenas observa.
//
// Para lotes sem classificação na nuvem (recém-cadastrados, coleção vazia
// ou notebook nunca executado), usamos o RuleBasedRiskClassifier local
// como plano B determinístico.

final riskClassificationRepoProvider =
    Provider<RiskClassificationFirestoreRepository>(
  (ref) => RiskClassificationFirestoreRepository(),
);

final _ruleFallbackProvider = Provider<RuleBasedRiskClassifier>(
  (ref) => RuleBasedRiskClassifier(),
);

// ---------------------------------------------------------------------------
// Stream das classificações do Firestore (todas, em tempo real)
// ---------------------------------------------------------------------------

final riskClassificationsStreamProvider =
    StreamProvider<List<RiskPrediction>>((ref) {
  final repo = ref.watch(riskClassificationRepoProvider);
  return repo.watchAll();
});

// ---------------------------------------------------------------------------
// Predições combinadas (Firestore + plano B local para o que faltar)
// ---------------------------------------------------------------------------

/// Predição de risco para todos os lotes disponíveis.
/// Cruza:
///   - lotes ativos do estoque (allAvailableBatchesProvider)
///   - classificações pré-calculadas no Firestore (risk_classifications)
/// Quando não há classificação na nuvem para um lote, gera localmente
/// via RuleBasedRiskClassifier (determinístico, sempre disponível).
final batchRiskPredictionsProvider =
    FutureProvider<List<RiskPrediction>>((ref) async {
  final cloudAsync = ref.watch(riskClassificationsStreamProvider);
  final batchesAsync = ref.watch(allAvailableBatchesProvider);

  final batches = batchesAsync.valueOrNull ?? const <Batch>[];
  if (batches.isEmpty) return const <RiskPrediction>[];

  final cloud = cloudAsync.valueOrNull ?? const <RiskPrediction>[];
  final cloudById = <String, RiskPrediction>{
    for (final p in cloud) p.batchId: p,
  };

  final fallback = ref.read(_ruleFallbackProvider);

  final results = <RiskPrediction>[];
  for (final b in batches) {
    final fromCloud = cloudById[b.id];
    if (fromCloud != null) {
      results.add(fromCloud);
    } else {
      results.add(await fallback.classify(b));
    }
  }
  return results;
});

/// Predição de risco para um único lote por ID.
final batchRiskProvider = FutureProvider.family<RiskPrediction?, String>(
  (ref, batchId) async {
    final predictions = await ref.watch(batchRiskPredictionsProvider.future);
    try {
      return predictions.firstWhere((p) => p.batchId == batchId);
    } catch (_) {
      return null;
    }
  },
);

/// Contadores por nível de risco.
final riskCountsProvider = FutureProvider<Map<RiskLevel, int>>((ref) async {
  final predictions = await ref.watch(batchRiskPredictionsProvider.future);
  final counts = <RiskLevel, int>{
    RiskLevel.verde: 0,
    RiskLevel.amarelo: 0,
    RiskLevel.vermelho: 0,
  };
  for (final p in predictions) {
    counts[p.level] = (counts[p.level] ?? 0) + 1;
  }
  return counts;
});

/// Lotes classificados como vermelho em ordem de confiança decrescente.
final criticalBatchPredictionsProvider =
    FutureProvider<List<RiskPrediction>>((ref) async {
  final predictions = await ref.watch(batchRiskPredictionsProvider.future);
  final critical = predictions
      .where((p) => p.level == RiskLevel.vermelho)
      .toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  return critical;
});

/// Fonte predominante da classificação atual:
///   - 'random_forest' quando há classificações vindas do Colab/Firestore
///   - 'rule_based'    quando o app está usando apenas o plano B local
final classifierSourceProvider = FutureProvider<String>((ref) async {
  final predictions = await ref.watch(batchRiskPredictionsProvider.future);
  if (predictions.isEmpty) return 'rule_based';
  final fromCloud =
      predictions.where((p) => p.source == 'random_forest').length;
  // Maioria define a fonte exibida no rótulo do app.
  return fromCloud >= predictions.length / 2 ? 'random_forest' : 'rule_based';
});
