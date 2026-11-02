import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Movimentação de estoque feita sem internet, guardada no aparelho até poder ser enviada.
///
/// Guarda a **variação** de quantidade (delta) e não o valor final: ao sincronizar, a
/// quantidade é recalculada em cima do que está no servidor naquele momento, então
/// outra pessoa ter mexido no mesmo lote nesse intervalo não é sobrescrito.
class PendingMovement {
  /// Identificador gerado no aparelho. Vira o id do documento em `stock_movements`,
  /// o que impede duplicar o registro se o envio for repetido.
  final String opId;
  final Map<String, dynamic> movement;
  final String batchId;
  final int delta;
  final String? nextStatus;
  final DateTime createdAt;

  const PendingMovement({
    required this.opId,
    required this.movement,
    required this.batchId,
    required this.delta,
    required this.nextStatus,
    required this.createdAt,
  });

  String get productName => (movement['productName'] as String?) ?? 'produto';

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'movement': movement,
        'batchId': batchId,
        'delta': delta,
        'nextStatus': nextStatus,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingMovement.fromJson(Map<String, dynamic> json) => PendingMovement(
        opId: json['opId'] as String,
        movement: Map<String, dynamic>.from(json['movement'] as Map),
        batchId: json['batchId'] as String,
        delta: (json['delta'] as num).toInt(),
        nextStatus: json['nextStatus'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Armazenamento chave → texto. Em produção é o Hive; nos testes, um mapa em memória.
abstract class QueueStore {
  List<String> readAll();
  Future<void> put(String key, String value);
  Future<void> delete(String key);
}

class HiveQueueStore implements QueueStore {
  static const boxName = 'offline_queue_v1';
  final Box<String> _box;

  HiveQueueStore(this._box);

  static Future<HiveQueueStore> open() async {
    await Hive.initFlutter();
    return HiveQueueStore(await Hive.openBox<String>(boxName));
  }

  @override
  List<String> readAll() => _box.values.toList();

  @override
  Future<void> put(String key, String value) => _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);
}

class InMemoryQueueStore implements QueueStore {
  final Map<String, String> _data = {};

  @override
  List<String> readAll() => _data.values.toList();

  @override
  Future<void> put(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Fila de movimentações pendentes, ordenada da mais antiga para a mais nova.
class OfflineQueue {
  final QueueStore _store;

  OfflineQueue(this._store);

  Future<void> enqueue(PendingMovement op) =>
      _store.put(op.opId, jsonEncode(op.toJson()));

  Future<void> remove(String opId) => _store.delete(opId);

  List<PendingMovement> pending() {
    final items = <PendingMovement>[];
    for (final raw in _store.readAll()) {
      try {
        items.add(PendingMovement.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Registro corrompido: ignora em vez de travar toda a fila.
      }
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  int get length => pending().length;
}
