import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/controllers/auth_provider.dart';
import '../firebase/firebase_providers.dart';
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

  String? get _uid => ref.read(currentUserProvider)?.id;
  String get _project => ref.read(firebaseProjectIdProvider);

  /// Contagens e conflitos da conta atual (pendências de outras contas não aparecem
  /// nem são enviadas — auditoria A07).
  OfflineState _forCurrentUser(OfflineState base) {
    final uid = _uid;
    if (uid == null) return base.copyWith(pending: 0, conflicts: const []);
    return base.copyWith(
      pending: _queue.pendingFor(uid, _project).length,
      conflicts: [
        for (final c in _queue.conflictsFor(uid, _project)) '${c.productName}: ${c.failure}',
      ],
    );
  }

  @override
  OfflineState build() {
    ref.onDispose(() => _sub?.cancel());
    // Quando a pessoa entra (ou troca de conta), mostra só a fila dela e tenta enviar.
    ref.listen(currentUserProvider, (prev, user) {
      if (prev?.id == user?.id) return;
      state = _forCurrentUser(state);
      if (user != null) unawaited(sync());
    });
    unawaited(_start());
    return _forCurrentUser(const OfflineState());
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
    state = _forCurrentUser(state);
  }

  /// Marca o aparelho como sem conexão (ex.: a gravação falhou por rede mesmo com
  /// o sistema dizendo que havia internet).
  void markOffline() => _setOnline(false);

  /// A pessoa revisou os conflitos e decidiu descartá-los (ação explícita).
  Future<void> dismissConflicts() async {
    final uid = _uid;
    if (uid != null) {
      for (final c in _queue.conflictsFor(uid, _project)) {
        await _queue.remove(c.opId);
      }
    }
    state = _forCurrentUser(state);
  }

  /// Envia a fila, da mais antiga para a mais nova. Para no primeiro erro de rede
  /// e tenta de novo quando a conexão voltar.
  Future<void> sync() async {
    if (_running || !state.online) return;
    final owner = _uid;
    if (owner == null) return;
    final project = _project;
    final items = _queue.pendingFor(owner, project);
    if (items.isEmpty) {
      state = _forCurrentUser(state);
      return;
    }

    _running = true;
    state = state.copyWith(syncing: true);
    final ds = ref.read(stockDatasourceProvider);
    try {
      for (final op in items) {
        // Saiu da conta (ou trocou) no meio do envio: para aqui; o resto fica guardado.
        if (_uid != owner) break;
        try {
          final outcome = await ds.applyQueuedMovement(op);
          switch (outcome) {
            case QueuedMovementOutcome.applied:
            case QueuedMovementOutcome.alreadyApplied:
              await _queue.remove(op.opId);
            case QueuedMovementOutcome.batchNotFound:
              await _queue.markFailed(op, 'o lote não existe mais.');
            case QueuedMovementOutcome.insufficientStock:
              await _queue.markFailed(op, 'estoque insuficiente no momento do envio.');
          }
        } on FirebaseException catch (e) {
          if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
            _setOnline(false);
            break; // tenta de novo quando a conexão voltar
          }
          // Erro definitivo (ex.: permissão negada): guarda como conflito para revisão.
          await _queue.markFailed(op, 'não foi possível enviar (${e.code}).');
        }
      }
    } finally {
      _running = false;
      state = _forCurrentUser(state.copyWith(syncing: false));
    }
  }
}

final offlineSyncProvider =
    NotifierProvider<OfflineSyncController, OfflineState>(OfflineSyncController.new);
