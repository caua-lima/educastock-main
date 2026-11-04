// Regressão da auditoria A01 (saída FEFO / acréscimo sem perder atualizações) e
// A10 (cadastro de lote com histórico atômico).
import 'package:educastock/features/batches/data/datasources/batches_remote_datasource.dart';
import 'package:educastock/features/batches/domain/entities/batch.dart';
import 'package:educastock/features/stock/data/datasources/stock_remote_datasource.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _batch(FakeFirebaseFirestore db, String id, int qty, String expiry,
    {String productId = 'p1'}) {
  return db.collection('batches').doc(id).set({
    'productId': productId,
    'productName': 'Leite',
    'quantity': qty,
    'initialQuantity': qty,
    'expiryDate': expiry,
    'noExpiry': false,
    'status': 'disponivel',
  });
}

Future<int> _qty(FakeFirebaseFirestore db, String id) async =>
    ((await db.collection('batches').doc(id).get()).data()!['quantity'] as num).toInt();

void main() {
  late FakeFirebaseFirestore db;
  late StockRemoteDatasource ds;
  const req = [ProductOutputRequest(productId: 'p1', productName: 'Leite', quantity: 8)];

  Future<Map<String, dynamic>> out(List<ProductOutputRequest> items, {String? op}) =>
      ds.registerBulkOutputFefo(
        items: items,
        performedBy: 'u1',
        performedByName: 'Ana',
        reasonCode: 'uso',
        operationId: op,
      );

  setUp(() async {
    db = FakeFirebaseFirestore();
    ds = StockRemoteDatasource(db: db);
    await _batch(db, 'cedo', 10, '2026-11-10T00:00:00.000');
    await _batch(db, 'tarde', 5, '2027-01-10T00:00:00.000');
  });

  test('FEFO: consome primeiro o lote que vence antes e grava tudo junto', () async {
    final r = await out(req);
    expect(await _qty(db, 'cedo'), 2);
    expect(await _qty(db, 'tarde'), 5);
    expect((await db.collection('stock_movements').get()).size, 1);
    expect((await db.collection('audit_logs').get()).size, 1);
    expect((await db.collection('outputs').doc(r['outputId'] as String).get()).exists, isTrue);
  });

  test('outra pessoa tira do lote no meio da operação: usa o saldo ATUAL', () async {
    // Entre a escolha dos lotes e a gravação, outro operador retira 6 do lote "cedo".
    ds.debugAfterPlanning = () => db.collection('batches').doc('cedo').update({'quantity': 4});
    await out(req); // pede 8: 4 do "cedo" (que agora tem 4) + 4 do "tarde"
    expect(await _qty(db, 'cedo'), 0);
    expect(await _qty(db, 'tarde'), 1);
    final cedo = (await db.collection('batches').doc('cedo').get()).data()!;
    expect(cedo['status'], 'distribuido');
    // A versão antiga gravaria "cedo = 2" (10 - 8) e apagaria a retirada do outro operador.
  });

  test('se o saldo atual não basta, falha sem gravar nada', () async {
    ds.debugAfterPlanning = () => db.collection('batches').doc('cedo').update({'quantity': 1});
    await expectLater(
      out(const [ProductOutputRequest(productId: 'p1', productName: 'Leite', quantity: 12)]),
      throwsA(isA<Exception>().having((e) => '$e', 'mensagem', contains('Estoque insuficiente'))),
    );
    expect(await _qty(db, 'cedo'), 1);
    expect(await _qty(db, 'tarde'), 5);
    expect((await db.collection('stock_movements').get()).size, 0);
    expect((await db.collection('outputs').get()).size, 0);
  });

  test('dois operadores pedindo 6 de um lote de 10: o segundo é recusado, saldo nunca negativo',
      () async {
    await db.collection('batches').doc('tarde').delete();
    const seis = [ProductOutputRequest(productId: 'p1', productName: 'Leite', quantity: 6)];
    await out(seis);
    await expectLater(out(seis), throwsA(isA<Exception>()));
    expect(await _qty(db, 'cedo'), 4);
    expect((await db.collection('stock_movements').get()).size, 1);
  });

  test('reenviar a mesma operação não desconta duas vezes', () async {
    await out(req, op: 'op-123');
    final again = await out(req, op: 'op-123');
    expect(again['alreadyApplied'], isTrue);
    expect(await _qty(db, 'cedo'), 2);
    expect((await db.collection('stock_movements').get()).size, 1);
  });

  test('acréscimo soma ao saldo atual do servidor e registra entrada e auditoria', () async {
    // A tela carregou "cedo = 10", mas outra pessoa já tirou 3.
    await db.collection('batches').doc('cedo').update({'quantity': 7});
    final after = await ds.addUnitsToBatch(
        batchId: 'cedo', amount: 5, performedBy: 'u1', performedByName: 'Ana');
    expect(after, 12);
    expect(await _qty(db, 'cedo'), 12);
    final mov = (await db.collection('stock_movements').get()).docs.single.data();
    expect(mov['type'], 'entrada');
    expect(mov['quantity'], 5);
    expect((await db.collection('audit_logs').get()).size, 1);
  });

  test('cadastro de lote novo grava lote, entrada e auditoria juntos', () async {
    final batchesDs = BatchesRemoteDatasource(db: db);
    final batch = Batch(
      id: '',
      productId: 'p2',
      productName: 'Arroz',
      quantity: 20,
      initialQuantity: 20,
      expiryDate: DateTime(2027, 3, 1),
      entryDate: DateTime(2026, 11, 4),
      origin: 'doacao',
      status: BatchStatus.disponivel,
      createdBy: 'u1',
      createdAt: DateTime(2026, 11, 4),
    );
    final id = await batchesDs.saveBatch(batch, entryMovement: {
      'productId': 'p2',
      'productName': 'Arroz',
      'type': 'entrada',
      'quantity': 20,
      'performedBy': 'u1',
      'performedByName': 'Ana',
      'performedAt': '2026-11-04T10:00:00.000',
    });
    expect((await db.collection('batches').doc(id).get()).exists, isTrue);
    final mov = (await db.collection('stock_movements').get()).docs.single.data();
    expect(mov['batchId'], id);
    final audit = (await db.collection('audit_logs').get()).docs.single.data();
    expect(audit['documentId'], id);
  });
}
