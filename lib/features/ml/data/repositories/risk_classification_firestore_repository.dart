import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/risk_prediction.dart';

/// Lê as classificações de risco gravadas pelo notebook do Colab
/// (Random Forest) na coleção `risk_classifications` do Firestore.
///
/// O app NÃO treina, NÃO infere e NÃO embarca modelo de ML.
/// Apenas observa o resultado pré-calculado por lote (1 documento por lote).
///
/// Schema esperado de cada documento (gerado pelo notebook
/// scripts/ml/train_risk_model.ipynb):
/// ```
/// {
///   "batchId": "lote_abc123",
///   "productName": "Arroz tipo 1 - 5kg",
///   "level": "vermelho",                  // verde | amarelo | vermelho
///   "probabilities": [0.05, 0.18, 0.77],
///   "source": "random_forest",
///   "modelVersion": "rf_v1",
///   "generatedAt": "2026-05-25T00:00:00Z"
/// }
/// ```
class RiskClassificationFirestoreRepository {
  final FirebaseFirestore _db;

  RiskClassificationFirestoreRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('risk_classifications');

  /// Stream em tempo real de todas as classificações.
  Stream<List<RiskPrediction>> watchAll() {
    return _col.snapshots().map(
          (snap) => snap.docs.map((d) => _fromMap(d.data(), d.id)).toList(),
        );
  }

  /// Busca pontual de todas as classificações.
  Future<List<RiskPrediction>> fetchAll() async {
    final snap = await _col.get();
    return snap.docs.map((d) => _fromMap(d.data(), d.id)).toList();
  }

  /// Classificação de um lote específico (null se ainda não foi classificado).
  Future<RiskPrediction?> getForBatch(String batchId) async {
    final doc = await _col.doc(batchId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    return _fromMap(data, doc.id);
  }

  RiskPrediction _fromMap(Map<String, dynamic> map, String docId) {
    final batchId = (map['batchId'] as String?) ?? docId;
    final productName = (map['productName'] as String?) ?? '';
    final levelStr = (map['level'] as String?) ?? 'verde';
    final probsRaw = (map['probabilities'] as List?) ?? const [];
    final probs = probsRaw
        .map((e) => (e as num).toDouble())
        .toList(growable: false);

    final level = RiskLevel.values.firstWhere(
      (l) => l.name == levelStr,
      orElse: () => RiskLevel.verde,
    );

    return RiskPrediction(
      batchId: batchId,
      productName: productName,
      level: level,
      probabilities: probs.length == 3 ? probs : _padProbs(probs),
      source: (map['source'] as String?) ?? 'random_forest',
    );
  }

  List<double> _padProbs(List<double> probs) {
    final padded = List<double>.filled(3, 0.0);
    for (var i = 0; i < probs.length && i < 3; i++) {
      padded[i] = probs[i];
    }
    return padded;
  }
}
