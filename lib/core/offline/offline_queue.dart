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

  /// Conta que registrou a movimentação. Registros antigos (sem este campo) usam o
  /// `performedBy` da própria movimentação.
  final String? ownerId;

  /// Projeto Firebase em que a movimentação deve ser aplicada. Registros antigos
  /// (sem este campo) valem para o projeto atual.
  final String? projectId;

  /// Motivo de falha definitiva (estoque insuficiente, lote apagado, permissão).
  /// Com motivo, o registro NÃO é reenviado sozinho: fica guardado como conflito até a
  /// pessoa revisar e descartar (nada é apagado em silêncio).
  final String? failure;

  const PendingMovement({
    required this.opId,
    required this.movement,
    required this.batchId,
    required this.delta,
    required this.nextStatus,
    required this.createdAt,
    this.ownerId,
    this.projectId,
    this.failure,
  });

  String get productName => (movement['productName'] as String?) ?? 'produto';

  /// Dono efetivo (campo novo ou, em registros antigos, quem fez a movimentação).
  String? get owner => ownerId ?? movement['performedBy'] as String?;

  /// Pertence à conta [uid] no projeto [project]?
  bool belongsTo(String uid, String project) =>
      owner == uid && (projectId == null || projectId == project);

  PendingMovement withFailure(String reason) => PendingMovement(
        opId: opId,
        movement: movement,
        batchId: batchId,
        delta: delta,
        nextStatus: nextStatus,
        createdAt: createdAt,
        ownerId: ownerId,
        projectId: projectId,
        failure: reason,
      );

  Map<String, dynamic> toJson() => {
        'opId': opId,
        'movement': movement,
        'batchId': batchId,
        'delta': delta,
        'nextStatus': nextStatus,
        'createdAt': createdAt.toIso8601String(),
        if (ownerId != null) 'ownerId': ownerId,
        if (projectId != null) 'projectId': projectId,
        if (failure != null) 'failure': failure,
      };

  factory PendingMovement.fromJson(Map<String, dynamic> json) => PendingMovement(
        opId: json['opId'] as String,
        movement: Map<String, dynamic>.from(json['movement'] as Map),
        batchId: json['batchId'] as String,
        delta: (json['delta'] as num).toInt(),
        nextStatus: json['nextStatus'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        ownerId: json['ownerId'] as String?,
        projectId: json['projectId'] as String?,
        failure: json['failure'] as String?,
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

  /// Pendências da conta [uid] no projeto [project] ainda a enviar.
  List<PendingMovement> pendingFor(String uid, String project) =>
      pending().where((p) => p.failure == null && p.belongsTo(uid, project)).toList();

  /// Registros da conta que falharam e aguardam revisão.
  List<PendingMovement> conflictsFor(String uid, String project) =>
      pending().where((p) => p.failure != null && p.belongsTo(uid, project)).toList();

  /// Guarda o registro como conflito (não será reenviado sozinho).
  Future<void> markFailed(PendingMovement op, String reason) => enqueue(op.withFailure(reason));
}
