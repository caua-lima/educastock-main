import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:educastock/features/auth/domain/entities/app_user.dart';
import 'package:educastock/features/donation_ops/data/donation_ops_repository.dart';
import 'package:educastock/features/donations/domain/entities/donation.dart';
import 'package:educastock/features/donations/domain/entities/donation_status.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _staff({UserRole role = UserRole.estoquista}) => AppUser(
      id: 'staff-1',
      name: 'Marta Estoquista',
      email: 'marta@ong.org',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

Map<String, dynamic> _donationDoc({
  String status = 'pendente',
  String protocol = '',
  bool reservationApplied = false,
}) =>
    {
      'donorId': 'donor-1',
      'donorSnapshot': {'displayName': 'João Menezes', 'phone': null},
      'status': status,
      'protocol': protocol,
      'pointId': 'ponto-1',
      'reservationApplied': reservationApplied,
      'reservationReleased': false,
      'items': [
        {
          'needId': 'need-leite',
          'category': 'alimento',
          'description': 'Leite integral 1 L',
          'quantity': 24,
          'unit': 'un',
          'expiryDate': Timestamp.fromDate(DateTime(2027, 3, 1)),
          'hasExpiry': true,
          'condition': 'novo',
          'subjectToReview': false,
        },
        {
          'needId': null,
          'category': 'escolar',
          'description': 'Caderno universitário',
          'quantity': 10,
          'unit': 'un',
          'expiryDate': null,
          'hasExpiry': false,
          'condition': 'novo',
          'subjectToReview': false,
        },
      ],
    };

void main() {
  late FakeFirebaseFirestore db;
  late DonationOpsRepository repo;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = DonationOpsRepository(db: db);
    await db.collection('donation_needs').doc('need-leite').set({
      'productId': 'prod-leite',
      'title': 'Leite integral 1 L',
      'suggestedQty': 100,
      'pledgedQty': 0,
      'remainingQty': 100,
    });
    await db.collection('products').doc('prod-leite').set({
      'name': 'Leite integral 1 L',
      'category': 'alimento',
      'unit': 'un',
      'isPerishable': true,
    });
  });

  Future<Donation> load(String id) async {
    final snap = await db.collection('donations').doc(id).get();
    return Donation.fromMap(snap.data()!, snap.id);
  }

  test('findIdByProtocol acha a doação pelo protocolo do QR (RF22)', () async {
    await db.collection('donations').doc('d1').set(_donationDoc());
    await repo.decide(donationId: 'd1', approve: true, actor: _staff());
    final protocolo = (await load('d1')).protocol;

    expect(await repo.findIdByProtocol(protocolo), 'd1');
    expect(await repo.findIdByProtocol('DOA-1999-999999'), isNull);
  });

  group('decide (S02)', () {
    test('aprovar gera protocolo, reserva a quantidade e avisa o doador', () async {
      await db.collection('donations').doc('d1').set(_donationDoc());

      await repo.decide(
        donationId: 'd1',
        approve: true,
        actor: _staff(),
        message: 'Pode entregar de segunda a sexta.',
      );

      final d = await load('d1');
      expect(d.status, DonationStatus.aprovada);
      expect(d.protocol, matches(RegExp(r'^DOA-\d{4}-000001$')));
      expect(d.approvalMessage, 'Pode entregar de segunda a sexta.');

      final need = (await db.collection('donation_needs').doc('need-leite').get()).data()!;
      expect(need['pledgedQty'], 24);
      expect(need['remainingQty'], 76);

      final events = await db.collection('donations').doc('d1').collection('events').get();
      expect(events.docs.single.data()['toStatus'], 'aprovada');

      final notes = await db.collection('user_notifications').doc('donor-1').collection('items').get();
      expect(notes.docs.single.data()['title'], 'Doação aprovada');

      final audit = await db.collection('audit_logs').get();
      expect(audit.docs.single.data()['action'], 'donation_aprovada');
    });

    test('o contador de protocolo avança a cada doação aprovada', () async {
      await db.collection('donations').doc('d1').set(_donationDoc());
      await db.collection('donations').doc('d2').set(_donationDoc());

      await repo.decide(donationId: 'd1', approve: true, actor: _staff());
      await repo.decide(donationId: 'd2', approve: true, actor: _staff());

      expect((await load('d1')).protocol.endsWith('000001'), isTrue);
      expect((await load('d2')).protocol.endsWith('000002'), isTrue);
    });

    test('mantém o protocolo que a função de criação já gerou', () async {
      await db.collection('donations').doc('d1').set(_donationDoc(protocol: 'DOA-2026-000042'));
      await repo.decide(donationId: 'd1', approve: true, actor: _staff());
      expect((await load('d1')).protocol, 'DOA-2026-000042');
    });

    test('não reserva duas vezes se a função já tinha reservado', () async {
      await db.collection('donation_needs').doc('need-leite').update({'pledgedQty': 24, 'remainingQty': 76});
      await db
          .collection('donations')
          .doc('d1')
          .set(_donationDoc(protocol: 'DOA-2026-000001', reservationApplied: true));

      await repo.decide(donationId: 'd1', approve: true, actor: _staff());

      final need = (await db.collection('donation_needs').doc('need-leite').get()).data()!;
      expect(need['pledgedQty'], 24);
    });

    test('recusar grava o motivo e libera a reserva que existia', () async {
      await db.collection('donation_needs').doc('need-leite').update({'pledgedQty': 24, 'remainingQty': 76});
      await db
          .collection('donations')
          .doc('d1')
          .set(_donationDoc(protocol: 'DOA-2026-000001', reservationApplied: true));

      await repo.decide(
        donationId: 'd1',
        approve: false,
        actor: _staff(),
        refusalReason: 'Estoque suficiente deste item.',
      );

      final d = await load('d1');
      expect(d.status, DonationStatus.recusada);
      expect(d.refusalReason, 'Estoque suficiente deste item.');
      final need = (await db.collection('donation_needs').doc('need-leite').get()).data()!;
      expect(need['pledgedQty'], 0);
      expect(need['remainingQty'], 100);
    });

    test('não decide duas vezes a mesma doação', () async {
      await db.collection('donations').doc('d1').set(_donationDoc());
      await repo.decide(donationId: 'd1', approve: true, actor: _staff());

      expect(
        () => repo.decide(donationId: 'd1', approve: false, actor: _staff(), refusalReason: 'x'),
        throwsA(isA<DonationOpsException>()),
      );
    });
  });

  group('receive (S03)', () {
    Future<Donation> approved() async {
      await db.collection('donations').doc('d1').set(_donationDoc());
      await repo.decide(donationId: 'd1', approve: true, actor: _staff());
      return load('d1');
    }

    test('recebimento completo cria lotes, movimentos e muda o status', () async {
      final donation = await approved();

      await repo.receive(
        donation: donation,
        actor: _staff(),
        received: [
          ReceivedItemInput(index: 0, receivedQty: 24, expiryDate: DateTime(2027, 3, 1)),
          const ReceivedItemInput(index: 1, receivedQty: 10),
        ],
        sector: 'Cozinha da Creche (Lanches)',
        impactMessage: 'Obrigado pelo leite!',
        usedAt: DateTime(2026, 11, 5),
      );

      final d = await load('d1');
      expect(d.status, DonationStatus.recebida);
      expect(d.impact?.sector, 'Cozinha da Creche (Lanches)');
      expect(d.receivedItems.map((r) => r.receivedQty), [24, 10]);

      final batches = await db.collection('batches').get();
      expect(batches.docs, hasLength(2));
      final leite = batches.docs.firstWhere((b) => b.data()['productId'] == 'prod-leite').data();
      expect(leite['quantity'], 24);
      expect(leite['origin'], 'doacao');
      expect(leite['donationId'], 'd1');
      expect(leite['noExpiry'], false);
      final caderno = batches.docs.firstWhere((b) => b.data()['productName'] == 'Caderno universitário').data();
      expect(caderno['noExpiry'], true);
      expect(caderno['expiryDate'], isNull);

      final movements = await db.collection('stock_movements').get();
      expect(movements.docs, hasLength(2));
      expect(movements.docs.every((m) => m.data()['type'] == 'entrada' && m.data()['reasonCode'] == 'doacao'), isTrue);

      // Produto novo criado para o item sem cadastro.
      final products = await db.collection('products').get();
      expect(products.docs.any((p) => p.data()['name'] == 'Caderno universitário'), isTrue);

      // Reserva devolvida ao receber (a necessidade fica coberta pelo estoque real).
      final need = (await db.collection('donation_needs').doc('need-leite').get()).data()!;
      expect(need['pledgedQty'], 0);

      final notes = await db.collection('user_notifications').doc('donor-1').collection('items').get();
      expect(notes.docs.map((n) => n.data()['title']), containsAll(['Doação aprovada', 'Doação recebida']));
    });

    test('quantidade menor exige nota e resulta em recebida_parcial', () async {
      final donation = await approved();

      expect(
        () => repo.receive(
          donation: donation,
          actor: _staff(),
          received: [
            ReceivedItemInput(index: 0, receivedQty: 20, expiryDate: DateTime(2027, 3, 1)),
            const ReceivedItemInput(index: 1, receivedQty: 10),
          ],
        ),
        throwsA(isA<DonationOpsException>()),
      );

      await repo.receive(
        donation: donation,
        actor: _staff(),
        received: [
          ReceivedItemInput(index: 0, receivedQty: 20, expiryDate: DateTime(2027, 3, 1), note: '4 caixas amassadas'),
          const ReceivedItemInput(index: 1, receivedQty: 10),
        ],
      );
      final d = await load('d1');
      expect(d.status, DonationStatus.recebidaParcial);
      expect(d.receivedItems.first.note, '4 caixas amassadas');
      expect(d.impact, isNull);
      expect(d.needsDestination, isTrue);
    });

    test('perecível sem validade é recusado antes de gravar qualquer coisa', () async {
      final donation = await approved();
      expect(
        () => repo.receive(
          donation: donation,
          actor: _staff(),
          received: [
            const ReceivedItemInput(index: 0, receivedQty: 24),
            const ReceivedItemInput(index: 1, receivedQty: 10),
          ],
        ),
        throwsA(isA<DonationOpsException>()),
      );
      expect((await db.collection('batches').get()).docs, isEmpty);
    });

    test('é idempotente: receber duas vezes não duplica o estoque', () async {
      final donation = await approved();
      final input = [
        ReceivedItemInput(index: 0, receivedQty: 24, expiryDate: DateTime(2027, 3, 1)),
        const ReceivedItemInput(index: 1, receivedQty: 10),
      ];
      await repo.receive(donation: donation, actor: _staff(), received: input);

      expect(
        () => repo.receive(donation: donation, actor: _staff(), received: input),
        throwsA(isA<DonationOpsException>()),
      );
      expect((await db.collection('batches').get()).docs, hasLength(2));
    });

    test('doação pendente não pode ser recebida', () async {
      await db.collection('donations').doc('d1').set(_donationDoc());
      final donation = await load('d1');
      expect(
        () => repo.receive(
          donation: donation,
          actor: _staff(),
          received: [
            ReceivedItemInput(index: 0, receivedQty: 24, expiryDate: DateTime(2027, 3, 1)),
            const ReceivedItemInput(index: 1, receivedQty: 10),
          ],
        ),
        throwsA(isA<DonationOpsException>()),
      );
    });
  });

  group('saveImpact', () {
    test('registra o destino depois do recebimento e avisa o doador', () async {
      await db.collection('donations').doc('d1').set(_donationDoc());
      await repo.decide(donationId: 'd1', approve: true, actor: _staff());
      await repo.receive(
        donation: await load('d1'),
        actor: _staff(),
        received: [
          ReceivedItemInput(index: 0, receivedQty: 24, expiryDate: DateTime(2027, 3, 1)),
          const ReceivedItemInput(index: 1, receivedQty: 10),
        ],
      );
      expect((await load('d1')).needsDestination, isTrue);

      await repo.saveImpact(
        donation: await load('d1'),
        actor: _staff(),
        sector: 'Refeitório (Almoço/Jantar)',
        message: 'O leite foi servido no café da manhã.',
      );

      final d = await load('d1');
      expect(d.impact?.sector, 'Refeitório (Almoço/Jantar)');
      expect(d.needsDestination, isFalse);
      final notes = await db.collection('user_notifications').doc('donor-1').collection('items').get();
      expect(notes.docs.map((n) => n.data()['title']), contains('Veja o impacto da sua doação'));
    });

    test('exige doação já recebida', () async {
      await db.collection('donations').doc('d1').set(_donationDoc());
      expect(
        () async => repo.saveImpact(
          donation: await load('d1'),
          actor: _staff(),
          sector: 'Bazar Beneficente',
          message: 'x',
        ),
        throwsA(isA<DonationOpsException>()),
      );
    });
  });
}
