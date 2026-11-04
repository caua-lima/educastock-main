// Regressão da auditoria A07: a fila offline não mistura contas nem projetos,
// para ao sair da conta e guarda os conflitos em vez de apagá-los.
import 'dart:async';

import 'package:educastock/core/firebase/firebase_providers.dart';
import 'package:educastock/core/offline/offline_queue.dart';
import 'package:educastock/core/offline/offline_sync_controller.dart';
import 'package:educastock/features/auth/domain/entities/app_user.dart';
import 'package:educastock/features/auth/presentation/controllers/auth_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user(String id) => AppUser(
      id: id,
      name: 'Pessoa $id',
      email: '$id@teste.test',
      role: UserRole.estoquista,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

PendingMovement _op(String id, String owner, {int delta = -2, String? project = 'proj-a'}) =>
    PendingMovement(
      opId: id,
      movement: {
        'productId': 'p1',
        'productName': 'Arroz',
        'batchId': 'b1',
        'type': 'saida',
        'quantity': -delta,
        'performedBy': owner,
        'performedByName': 'Pessoa $owner',
        'performedAt': '2026-11-04T10:00:00.000',
      },
      batchId: 'b1',
      delta: delta,
      nextStatus: null,
      createdAt: DateTime(2026, 11, 4, 10),
      ownerId: owner,
      projectId: project,
    );

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late OfflineQueue queue;
  late StreamController<AppUser?> auth;
  late ProviderContainer c;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.collection('batches').doc('b1').set({
      'productId': 'p1', 'productName': 'Arroz', 'quantity': 10, 'status': 'disponivel',
    });
    queue = OfflineQueue(InMemoryQueueStore());
    auth = StreamController<AppUser?>.broadcast();
    c = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseProjectIdProvider.overrideWithValue('proj-a'),
      offlineQueueProvider.overrideWithValue(queue),
      authStateProvider.overrideWith((ref) => auth.stream),
    ]);
    c.listen(offlineSyncProvider, (_, __) {});
    c.listen(currentUserProvider, (_, __) {});
  });

  tearDown(() async {
    c.dispose();
    await auth.close();
  });

  Future<int> qty() async =>
      ((await db.collection('batches').doc('b1').get()).data()!['quantity'] as num).toInt();

  test('envia só as pendências da conta logada; as de outra conta ficam guardadas', () async {
    await queue.enqueue(_op('da-ana', 'ana'));
    await queue.enqueue(_op('do-beto', 'beto', delta: -3));

    auth.add(_user('ana'));
    await _settle();
    await c.read(offlineSyncProvider.notifier).sync();
    await _settle();

    expect(await qty(), 8, reason: 'só a saída da Ana (2) foi aplicada');
    expect(queue.pending().map((p) => p.opId), ['do-beto']);
    expect(c.read(offlineSyncProvider).pending, 0, reason: 'a Ana não vê a fila do Beto');

    // Beto entra no mesmo aparelho: agora a pendência dele é enviada, com o nome dele.
    auth.add(_user('beto'));
    await _settle();
    await c.read(offlineSyncProvider.notifier).sync();
    await _settle();
    expect(await qty(), 5);
    expect(queue.pending(), isEmpty);
    final mov = (await db.collection('stock_movements').doc('do-beto').get()).data()!;
    expect(mov['performedBy'], 'beto');
  });

  test('pendência de outro projeto Firebase nunca é enviada', () async {
    await queue.enqueue(_op('outro-projeto', 'ana', project: 'proj-b'));
    auth.add(_user('ana'));
    await _settle();
    await c.read(offlineSyncProvider.notifier).sync();
    await _settle();
    expect(await qty(), 10);
    expect(queue.pending().single.opId, 'outro-projeto');
  });

  test('registro antigo (sem dono gravado) usa quem fez a movimentação', () async {
    final legacy = PendingMovement.fromJson({
      ..._op('antigo', 'ana', project: null).toJson()..remove('ownerId'),
    });
    expect(legacy.ownerId, isNull);
    expect(legacy.belongsTo('ana', 'proj-a'), isTrue);
    expect(legacy.belongsTo('beto', 'proj-a'), isFalse);
  });

  test('sem ninguém logado nada é enviado', () async {
    await queue.enqueue(_op('da-ana', 'ana'));
    auth.add(null);
    await _settle();
    await c.read(offlineSyncProvider.notifier).sync();
    expect(await qty(), 10);
    expect(queue.length, 1);
  });

  test('estoque insuficiente vira conflito guardado; some só quando a pessoa descarta', () async {
    await queue.enqueue(_op('grande', 'ana', delta: -50));
    auth.add(_user('ana'));
    await _settle();
    await c.read(offlineSyncProvider.notifier).sync();
    await _settle();

    expect(await qty(), 10);
    expect(queue.length, 1, reason: 'o registro não foi apagado em silêncio');
    expect(c.read(offlineSyncProvider).conflicts.single, contains('estoque insuficiente'));
    expect(c.read(offlineSyncProvider).pending, 0, reason: 'conflito não é reenviado sozinho');

    await c.read(offlineSyncProvider.notifier).dismissConflicts();
    expect(queue.length, 0);
    expect(c.read(offlineSyncProvider).conflicts, isEmpty);
  });
}
