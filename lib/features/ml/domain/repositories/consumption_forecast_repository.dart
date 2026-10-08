import '../entities/consumption_forecast.dart';

abstract interface class ConsumptionForecastRepository {
  /// Stream em tempo real de todas as previsões de consumo.
  Stream<List<ConsumptionForecast>> watchForecasts();

  /// Retorna a previsão para um produto específico (ou null se não existir).
  Future<ConsumptionForecast?> getForecastForProduct(String productId);
}
