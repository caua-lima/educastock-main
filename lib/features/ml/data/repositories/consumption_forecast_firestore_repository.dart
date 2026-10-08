import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/consumption_forecast.dart';
import '../../domain/repositories/consumption_forecast_repository.dart';

/// Lê previsões de consumo gravadas pelo Colab/Prophet na coleção
/// `consumption_forecasts` do Firestore.
class ConsumptionForecastFirestoreRepository
    implements ConsumptionForecastRepository {
  final FirebaseFirestore _db;

  ConsumptionForecastFirestoreRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('consumption_forecasts');

  @override
  Stream<List<ConsumptionForecast>> watchForecasts() {
    return _col
        .orderBy('suggestedReplenishment', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ConsumptionForecast.fromMap(d.data()))
              .toList(),
        );
  }

  @override
  Future<ConsumptionForecast?> getForecastForProduct(
      String productId) async {
    final snap =
        await _col.where('productId', isEqualTo: productId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return ConsumptionForecast.fromMap(snap.docs.first.data());
  }
}
