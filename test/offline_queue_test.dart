import 'package:educastock/core/offline/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

PendingMovement _op(String id, DateTime at, {int delta = -2, String? status}) =>
    PendingMovement(
      opId: id,
      movement: {
        'productName': 'Arroz 5kg',
        'batchId': 'lote-1',
        'type': 'saida',
        'quantity': -delta,
      },
      batchId: 'lote-1',
      delta: delta,
      nextStatus: status,
      createdAt: at,
    );

void main() {
  test('guarda e devolve a movimentação sem perder nenhum campo', () async {
    final queue = OfflineQueue(InMemoryQueueStore());
    final at = DateTime(2026, 10, 28, 9, 30);
    await queue.enqueue(_op('a', at, delta: -3, status: 'distribuido'));

    final item = queue.pending().single;
    expect(item.opId, 'a');
    expect(item.batchId, 'lote-1');
    expect(item.delta, -3);
    expect(item.nextStatus, 'distribuido');
    expect(item.createdAt, at);
    expect(item.productName, 'Arroz 5kg');
    expect(item.movement['type'], 'saida');
  });

  test('devolve da mais antiga para a mais nova', () async {
    final queue = OfflineQueue(InMemoryQueueStore());
    await queue.enqueue(_op('nova', DateTime(2026, 10, 28, 10)));
    await queue.enqueue(_op('antiga', DateTime(2026, 10, 28, 8)));
    await queue.enqueue(_op('meio', DateTime(2026, 10, 28, 9)));

    expect(queue.pending().map((e) => e.opId), ['antiga', 'meio', 'nova']);
    expect(queue.length, 3);
  });

  test('remover tira só o item pedido', () async {
    final queue = OfflineQueue(InMemoryQueueStore());
    await queue.enqueue(_op('a', DateTime(2026, 10, 28, 8)));
    await queue.enqueue(_op('b', DateTime(2026, 10, 28, 9)));
    await queue.remove('a');

    expect(queue.pending().map((e) => e.opId), ['b']);
  });

  test('enfileirar o mesmo opId duas vezes não duplica', () async {
    final queue = OfflineQueue(InMemoryQueueStore());
    await queue.enqueue(_op('a', DateTime(2026, 10, 28, 8)));
    await queue.enqueue(_op('a', DateTime(2026, 10, 28, 8)));

    expect(queue.length, 1);
  });

  test('registro corrompido é ignorado e não trava a fila', () async {
    final store = InMemoryQueueStore();
    final queue = OfflineQueue(store);
    await store.put('lixo', '{isto nao e json');
    await queue.enqueue(_op('ok', DateTime(2026, 10, 28, 8)));

    expect(queue.pending().map((e) => e.opId), ['ok']);
  });
}
