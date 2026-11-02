import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/controllers/auth_provider.dart';
import '../../features/stock/data/datasources/stock_remote_datasource.dart';
import '../../features/stock/presentation/controllers/stock_provider.dart';
import 'offline_queue.dart';

/// Estado mostrado no aviso de conexão.
class OfflineState {
  final bool online;
  final int pending;
  final bool syncing;

  /// Registros que não puderam ser aplicados (ex.: estoque insuficiente). Ficam aqui
  /// até a pessoa dispensar o aviso.
  final List<String> conflicts;

  const OfflineState({
    this.online = true,
    this.pending = 0,
    this.syncing = false,
    this.conflicts = const [],
  });

  OfflineState copyWith({
    bool? online,
    int? pending,
    bool? syncing,
    List<String>? conflicts,
  }) =>
      OfflineState(
        online: online ?? this.online,
        pending: pending ?? this.pending,
        syncing: syncing ?? this.syncing,
        conflicts: conflicts ?? this.conflicts,
      );
}

/// Fila de gravações feitas sem internet. É criada em `main()` (precisa do Hive aberto)
/// e injetada com `overrideWithValue`.
final offlineQueueProvider = Provider<OfflineQueue>(
  (_) => throw UnimplementedError('offlineQueueProvider não foi inicializado'),
);

class OfflineSyncController extends Notifier<OfflineState> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _running = false;

  OfflineQueue get _queue => ref.read(offlineQueueProvider);

  @override
  OfflineState build() {
    ref.onDispose(() => _sub?.cancel());
    // Quando a pessoa entra (ou troca de conta), tenta enviar o que ficou na fila.
    ref.listen(currentUserProvider, (_, user) {
      if (user != null) unawaited(sync());
    });
    unawaited(_start());
    return OfflineState(pending: _queue.length);
  }

  Future<void> _start() async {
    try {
      final first = await Connectivity().checkConnectivity();
      _setOnline(_isOnline(first));
      _sub = Connectivity().onConnectivityChanged.listen((results) {
        final online = _isOnline(results);
        final wasOffline = !state.online;
        _setOnline(online);
        if (online && wasOffline) unawaited(sync());
      });
      if (state.online) unawaited(sync());
    } catch (e) {
      debugPrint('[Offline] não foi possível monitorar a conexão: $e');
    }
  }

  static bool _isOnline(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  void _setOnline(bool online) {
    if (state.online != online) state = state.copyWith(online: online);
  }

  /// Guarda uma movimentação para enviar depois.
  Future<void> enqueue(PendingMovement op) async {
    await _queue.enqueue(op);
    state = state.copyWith(pending: _queue.length);
  }

  /// Marca o aparelho como sem conexão (ex.: a gravação falhou por rede mesmo com
  /// o sistema dizendo que havia internet).
  void markOffline() => _setOnline(false);

  void dismissConflicts() => state = state.copyWith(conflicts: const []);

  /// Envia a fila, da mais antiga para a mais nova. Para no primeiro erro de rede
  /// e tenta de novo quando a conexão voltar.
  Future<void> sync() async {
    if (_running || !state.online) return;
    if (ref.read(currentUserProvider) == null) return;
    final items = _queue.pending();
    if (items.isEmpty) {
      if (state.pending != 0) state = state.copyWith(pending: 0);
      return;
    }

    _running = true;
    state = state.copyWith(syncing: true);
    final ds = ref.read(stockDatasourceProvider);
    final conflicts = [...state.conflicts];
    try {
      for (final op in items) {
        try {
          final outcome = await ds.applyQueuedMovement(op);
          switch (outcome) {
            case QueuedMovementOutcome.applied:
            case QueuedMovementOutcome.alreadyApplied:
              break;
            case QueuedMovementOutcome.batchNotFound:
              conflicts.add('${op.productName}: o lote não existe mais.');
            case QueuedMovementOutcome.insufficientStock:
              conflicts.add('${op.productName}: estoque insuficiente no momento do envio.');
          }
          await _queue.remove(op.opId);
        } on FirebaseException catch (e) {
          if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
            _setOnline(false);
            break; // tenta de novo quando a conexão voltar
          }
          // Erro definitivo (ex.: permissão negada): tira da fila e avisa.
          conflicts.add('${op.productName}: não foi possível enviar (${e.code}).');
          await _queue.remove(op.opId);
        }
      }
    } finally {
      _running = false;
      state = state.copyWith(
        syncing: false,
        pending: _queue.length,
        conflicts: conflicts,
      );
    }
  }
}

final offlineSyncProvider =
    NotifierProvider<OfflineSyncController, OfflineState>(OfflineSyncController.new);
