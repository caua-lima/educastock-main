/// Previsão de consumo por produto gerada pelo modelo Prophet (ou média móvel
/// ponderada como fallback). Gravada no Firestore pela Cloud Function / Colab
/// e lida pelo app para sugestões de reposição no dashboard.
class ConsumptionForecast {
  final String productId;
  final String productName;
  final String? categoryId;

  /// Quantidade prevista de saída nos próximos 7 dias.
  final double forecastWeekly;

  /// Quantidade prevista de saída nos próximos 30 dias.
  final double forecastMonthly;

  /// Estoque atual (soma de todos os lotes disponíveis) no momento do cálculo.
  final int currentStock;

  /// Quantidade sugerida para reposição: max(0, monthly * 1.2 - currentStock).
  final int suggestedReplenishment;

  /// Intervalo de confiança inferior (semanal).
  final double? ciLower;

  /// Intervalo de confiança superior (semanal).
  final double? ciUpper;

  /// Tendência de consumo: 'increasing' | 'stable' | 'decreasing'.
  final String trend;

  /// Variação percentual em relação ao período anterior.
  final double trendPercent;

  /// Versão do modelo que gerou a previsão.
  final String modelVersion;

  /// Timestamp de quando a previsão foi gerada.
  final DateTime generatedAt;

  /// Número de observações históricas usadas no treinamento.
  final int dataPoints;

  /// Fonte: 'prophet' | 'moving_average' | 'insufficient_data'.
  final String source;

  const ConsumptionForecast({
    required this.productId,
    required this.productName,
    this.categoryId,
    required this.forecastWeekly,
    required this.forecastMonthly,
    required this.currentStock,
    required this.suggestedReplenishment,
    this.ciLower,
    this.ciUpper,
    required this.trend,
    required this.trendPercent,
    required this.modelVersion,
    required this.generatedAt,
    required this.dataPoints,
    required this.source,
  });

  /// Cria a partir de um documento Firestore.
  factory ConsumptionForecast.fromMap(Map<String, dynamic> map) {
    return ConsumptionForecast(
      productId: map['productId'] as String,
      productName: map['productName'] as String? ?? '',
      categoryId: map['categoryId'] as String?,
      forecastWeekly: (map['forecastWeekly'] as num?)?.toDouble() ?? 0,
      forecastMonthly: (map['forecastMonthly'] as num?)?.toDouble() ?? 0,
      currentStock: (map['currentStock'] as num?)?.toInt() ?? 0,
      suggestedReplenishment:
          (map['suggestedReplenishment'] as num?)?.toInt() ?? 0,
      ciLower: (map['ciLower'] as num?)?.toDouble(),
      ciUpper: (map['ciUpper'] as num?)?.toDouble(),
      trend: map['trend'] as String? ?? 'stable',
      trendPercent: (map['trendPercent'] as num?)?.toDouble() ?? 0,
      modelVersion: map['modelVersion'] as String? ?? 'unknown',
      generatedAt: map['generatedAt'] != null
          ? DateTime.tryParse(map['generatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dataPoints: (map['dataPoints'] as num?)?.toInt() ?? 0,
      source: map['source'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'categoryId': categoryId,
        'forecastWeekly': forecastWeekly,
        'forecastMonthly': forecastMonthly,
        'currentStock': currentStock,
        'suggestedReplenishment': suggestedReplenishment,
        'ciLower': ciLower,
        'ciUpper': ciUpper,
        'trend': trend,
        'trendPercent': trendPercent,
        'modelVersion': modelVersion,
        'generatedAt': generatedAt.toIso8601String(),
        'dataPoints': dataPoints,
        'source': source,
      };

  /// Dias de estoque restantes com base na previsão diária.
  double get daysOfStockRemaining {
    final dailyRate = forecastMonthly / 30;
    if (dailyRate <= 0) return 999;
    return currentStock / dailyRate;
  }

  bool get needsReplenishment => suggestedReplenishment > 0;
  bool get isLowStock => daysOfStockRemaining < 14;
  bool get isCriticalStock => daysOfStockRemaining < 7;

  bool get isProphet => source == 'prophet';
  bool get isMovingAverage => source == 'moving_average';

  /// Retorna uma cópia com o estoque atual sobrescrito e
  /// `suggestedReplenishment` recalculado (mesma fórmula do Colab:
  /// max(0, forecastMonthly * 1.2 - currentStock)).
  ConsumptionForecast copyWithLiveStock(int liveStock) {
    final target = (forecastMonthly * 1.2).round();
    final newSuggested = (target - liveStock).clamp(0, 1 << 31);
    return ConsumptionForecast(
      productId: productId,
      productName: productName,
      categoryId: categoryId,
      forecastWeekly: forecastWeekly,
      forecastMonthly: forecastMonthly,
      currentStock: liveStock,
      suggestedReplenishment: newSuggested,
      ciLower: ciLower,
      ciUpper: ciUpper,
      trend: trend,
      trendPercent: trendPercent,
      modelVersion: modelVersion,
      generatedAt: generatedAt,
      dataPoints: dataPoints,
      source: source,
    );
  }
}
