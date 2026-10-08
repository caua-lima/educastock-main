import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/consumption_forecast.dart';
import '../../data/repositories/consumption_forecast_firestore_repository.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';

// ---------------------------------------------------------------------------
// Repositório (singleton)
// ---------------------------------------------------------------------------

final consumptionForecastRepositoryProvider =
    Provider<ConsumptionForecastFirestoreRepository>(
  (_) => ConsumptionForecastFirestoreRepository(),
);

// ---------------------------------------------------------------------------
// Stream de todas as previsões
// ---------------------------------------------------------------------------

/// Lista completa de previsões (estoque vindo do Firestore, congelado no treino).
final consumptionForecastsProvider =
    StreamProvider<List<ConsumptionForecast>>((ref) {
  final repo = ref.watch(consumptionForecastRepositoryProvider);
  return repo.watchForecasts();
});

// ---------------------------------------------------------------------------
// Derivados
// ---------------------------------------------------------------------------

/// Previsões com `currentStock` sobrescrito pelo estoque ao vivo dos batches
/// e `suggestedReplenishment` recalculado. Reordenado pelo novo valor.
/// Esta é a fonte oficial para UI — evita mostrar estoque zerado quando o
/// usuário acabou de cadastrar lotes após a última execução do Colab.
final liveForecastsProvider =
    Provider<AsyncValue<List<ConsumptionForecast>>>((ref) {
  final raw = ref.watch(consumptionForecastsProvider);
  final liveStock = ref.watch(productAvailableQtyMapProvider);
  return raw.whenData((list) {
    final merged = list
        .map((f) => f.copyWithLiveStock(liveStock[f.productId] ?? 0))
        .toList();
    merged.sort((a, b) =>
        b.suggestedReplenishment.compareTo(a.suggestedReplenishment));
    return merged;
  });
});

/// Apenas produtos que precisam de reposição (suggestedReplenishment > 0),
/// limitado aos 5 mais urgentes para o dashboard.
final topReplenishmentForecastsProvider =
    Provider<AsyncValue<List<ConsumptionForecast>>>((ref) {
  return ref.watch(liveForecastsProvider).whenData(
        (list) => list
            .where((f) => f.needsReplenishment)
            .take(5)
            .toList(),
      );
});

/// Previsão de um único produto por ID, com estoque ao vivo aplicado.
final forecastForProductProvider =
    FutureProvider.family<ConsumptionForecast?, String>((ref, productId) async {
  final repo = ref.watch(consumptionForecastRepositoryProvider);
  final raw = await repo.getForecastForProduct(productId);
  if (raw == null) return null;
  final liveStock = ref.watch(productAvailableQtyMapProvider)[productId] ?? 0;
  return raw.copyWithLiveStock(liveStock);
});

/// Indica se existe ao menos uma previsão disponível.
final hasForecastDataProvider = Provider<bool>((ref) {
  return ref
      .watch(consumptionForecastsProvider)
      .maybeWhen(data: (list) => list.isNotEmpty, orElse: () => false);
});

/// Contagem de produtos que precisam de reposição (usa estoque ao vivo).
final replenishmentCountProvider = Provider<int>((ref) {
  return ref.watch(liveForecastsProvider).maybeWhen(
        data: (list) => list.where((f) => f.needsReplenishment).length,
        orElse: () => 0,
      );
});
