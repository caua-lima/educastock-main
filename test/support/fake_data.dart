import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:educastock/features/auth/domain/entities/app_user.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Usuários usados nos testes de layout.
final kAdminUser = AppUser(
  id: 'admin-1',
  name: 'Maria Aparecida dos Santos Oliveira',
  email: 'coordenacao@casadacrianca.test',
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime(2025, 1, 10),
);

final kDonorUser = AppUser(
  id: 'donor-1',
  name: 'Fernanda Cristina Albuquerque de Moraes',
  email: 'fernanda.doadora@exemplo.test',
  role: UserRole.doador,
  isActive: true,
  createdAt: DateTime(2025, 3, 2),
);

/// Popula um Firestore falso com dados parecidos com os reais (nomes longos de propósito,
/// para o teste pegar textos que estouram o layout).
Future<void> seedFakeData(FakeFirebaseFirestore db, {DateTime? now}) async {
  final n = now ?? DateTime.now();
  String iso(DateTime d) => d.toIso8601String();
  Timestamp ts(DateTime d) => Timestamp.fromDate(d);

  await db.collection('users').doc(kAdminUser.id).set({
    'name': kAdminUser.name,
    'email': kAdminUser.email,
    'role': 'admin',
    'isActive': true,
    'createdAt': iso(kAdminUser.createdAt),
  });
  await db.collection('users').doc('vol-1').set({
    'name': 'João Pedro Ferreira da Silva Junior',
    'email': 'voluntario@casadacrianca.test',
    'role': 'voluntario',
    'isActive': true,
    'createdAt': iso(DateTime(2025, 2, 1)),
  });
  await db.collection('users').doc(kDonorUser.id).set({
    'name': kDonorUser.name,
    'email': kDonorUser.email,
    'role': 'doador',
    'isActive': true,
    'createdAt': iso(kDonorUser.createdAt),
  });
  await db.collection('donors').doc(kDonorUser.id).set({
    'displayName': kDonorUser.name,
    'phone': '(19) 99876-5432',
    'city': 'Itapira',
    'donorType': 'pf',
    'termsVersion': '1.0',
    'consentAt': ts(n.subtract(const Duration(days: 200))),
    'prefs': {'notifyStatus': true},
  });

  // ── Produtos ──────────────────────────────────────────────────────────────
  final products = <(String, String, String, String, bool, int, String?)>[
    ('p-leite', 'Leite UHT integral caixinha 1 litro (longa vida)', 'alimento', 'L', true, 40, '7891000100103'),
    ('p-arroz', 'Arroz branco tipo 1 pacote 5 kg', 'alimento', 'kg', true, 20, '7896006716112'),
    ('p-feijao', 'Feijão carioca tipo 1', 'alimento', 'kg', true, 15, null),
    ('p-oleo', 'Óleo de soja refinado 900 mL', 'alimento', 'un', true, 10, null),
    ('p-banana', 'Banana nanica', 'alimento', 'kg', true, 8, null),
    ('p-pao', 'Pão francês', 'alimento', 'un', true, 30, null),
    ('p-achoc', 'Achocolatado em pó 400 g', 'bebida', 'un', true, 6, null),
    ('p-sabonete', 'Sabonete em barra glicerinado neutro 90 g', 'higienePessoal', 'un', true, 24, null),
    ('p-deterg', 'Detergente líquido neutro 500 mL', 'limpeza', 'un', true, 12, null),
    ('p-caderno', 'Caderno universitário 10 matérias capa dura', 'escolar', 'un', false, 20, null),
    ('p-lapis', 'Lápis de cor 24 cores', 'escolar', 'un', false, 10, null),
    ('p-camiseta', 'Camiseta infantil algodão tamanho 8', 'roupas', 'un', false, 5, null),
  ];
  for (final (id, name, cat, unit, perishable, min, barcode) in products) {
    await db.collection('products').doc(id).set({
      'name': name,
      'brand': cat == 'alimento' ? 'Marca Popular' : null,
      'category': cat,
      'unit': unit,
      'barcode': barcode,
      'imageUrl': null,
      'description': null,
      'isPerishable': perishable,
      'minimumStock': min,
      'createdAt': iso(DateTime(2025, 2, 1)),
      'createdBy': kAdminUser.id,
      'isActive': true,
    });
  }

  // ── Lotes (validades variadas: vencido, 2, 6, 20, 60, 200 dias, sem validade) ─
  final expiries = [-3, 2, 6, 20, 60, 200];
  var b = 0;
  for (final (id, name, _, _, perishable, _, _) in products) {
    for (var k = 0; k < 2; k++) {
      final days = expiries[(b + k) % expiries.length];
      final qty = 3 + ((b * 7 + k * 5) % 40);
      final batchId = 'b-${b.toString().padLeft(2, '0')}';
      await db.collection('batches').doc(batchId).set({
        'productId': id,
        'productName': name,
        'quantity': qty,
        'initialQuantity': qty + 10,
        'expiryDate': perishable ? iso(n.add(Duration(days: days))) : null,
        'noExpiry': !perishable,
        'entryDate': iso(n.subtract(Duration(days: 10 + b))),
        'origin': k == 0 ? 'doacao' : 'compra',
        'donor': k == 0 ? 'Supermercado Bom Preço Itapira Ltda.' : null,
        'supplier': k == 1 ? 'Atacadão Distribuidora Regional' : null,
        'unitPrice': 4.5 + b,
        'batchNumber': 'L${2400 + b}',
        'imageUrl': null,
        'shelfLocation': 'Despensa principal · Prateleira ${1 + b % 4} · Nível ${1 + k}',
        'notes': null,
        'status': 'disponivel',
        'createdBy': kAdminUser.id,
        'createdAt': iso(n.subtract(Duration(days: 10 + b))),
      });
      // Classificação de risco (ML) para cada lote.
      final level = days <= 3 ? 'vermelho' : (days <= 20 ? 'amarelo' : 'verde');
      await db.collection('risk_classifications').doc(batchId).set({
        'batchId': batchId,
        'productId': id,
        'productName': name,
        'level': level,
        'probabilities': level == 'vermelho'
            ? [0.05, 0.15, 0.80]
            : level == 'amarelo'
                ? [0.2, 0.6, 0.2]
                : [0.85, 0.1, 0.05],
        'source': 'random_forest',
      });
      b++;
    }
  }

  // ── Movimentações (últimos 30 dias) ─────────────────────────────────────────
  const types = ['entrada', 'saida', 'saida', 'descarte', 'ajusteNegativo', 'saida'];
  for (var i = 0; i < 40; i++) {
    final (pid, pname, _, _, _, _, _) = products[i % products.length];
    final type = types[i % types.length];
    final when = n.subtract(Duration(hours: 9 * i + 2));
    await db.collection('stock_movements').doc('m-$i').set({
      'productId': pid,
      'productName': pname,
      'batchId': 'b-${(i % 24).toString().padLeft(2, '0')}',
      'type': type,
      'quantity': 1 + (i * 3) % 12,
      'reasonCode': type == 'saida' ? 'consumo' : null,
      'reason': type == 'saida' ? 'Consumo no lanche da tarde das turmas do período integral' : 'Recebimento',
      'activity': type == 'saida' ? 'Lanche' : null,
      'performedBy': i.isEven ? kAdminUser.id : 'vol-1',
      'performedByName': i.isEven ? kAdminUser.name : 'João Pedro Ferreira da Silva Junior',
      'performedAt': iso(when),
      'isPendingSync': false,
    });
  }

  // ── Auditoria ────────────────────────────────────────────────────────────
  for (var i = 0; i < 12; i++) {
    final when = n.subtract(Duration(hours: 5 * i + 1));
    await db.collection('audit_logs').doc('a-$i').set({
      'action': i.isEven ? 'saida_estoque' : 'cadastro_lote',
      'entity': i.isEven ? 'stock_movement' : 'batch',
      'entityId': 'b-0$i',
      'performedBy': kAdminUser.id,
      'performedByName': kAdminUser.name,
      'performedAt': iso(when),
      'timestamp': ts(when),
      'before': {'quantity': 30 + i},
      'after': {'quantity': 25 + i},
      'details': 'Ajuste registrado pela coordenação após conferência do estoque',
    });
  }

  // ── Alertas ──────────────────────────────────────────────────────────────
  final alerts = [
    ('critical', 'Leite UHT integral caixinha 1 litro (longa vida)', 'Vence em 2 dias — 18 unidades', 'p-leite', 'b-01'),
    ('critical', 'Banana nanica', 'Lote vencido há 3 dias', 'p-banana', 'b-08'),
    ('warning', 'Pão francês', 'Vence em 6 dias', 'p-pao', 'b-10'),
    ('warning', 'Achocolatado em pó 400 g', 'Vence em 20 dias', 'p-achoc', 'b-12'),
    ('info', 'Caderno universitário 10 matérias capa dura', 'Estoque abaixo do mínimo (8 de 20)', 'p-caderno', null),
    ('info', 'Sabonete em barra glicerinado neutro 90 g', 'Estoque abaixo do mínimo', 'p-sabonete', null),
  ];
  for (var i = 0; i < alerts.length; i++) {
    final (level, name, msg, pid, bid) = alerts[i];
    await db.collection('alerts').doc('al-$i').set({
      'productId': pid,
      'productName': name,
      'batchId': bid,
      'level': level,
      'message': msg,
      'createdAt': ts(n.subtract(Duration(hours: i * 3))),
      'resolved': false,
    });
  }

  // ── Previsões de consumo ─────────────────────────────────────────────────
  const trends = ['increasing', 'stable', 'decreasing'];
  for (var i = 0; i < 8; i++) {
    final (pid, pname, cat, _, _, _, _) = products[i];
    await db.collection('consumption_forecasts').doc(pid).set({
      'productId': pid,
      'productName': pname,
      'categoryId': cat,
      'forecastWeekly': 12.5 + i,
      'forecastMonthly': 54.0 + i * 4,
      'ciLower': 40.0 + i,
      'ciUpper': 70.0 + i * 5,
      'currentStock': 10 + i * 3,
      'suggestedReplenishment': 20 + i * 2,
      'trend': trends[i % 3],
      'trendPercent': i.isEven ? 12.4 : -8.1,
      'dataPoints': 120,
      'modelVersion': 'prophet-1.1',
      'source': 'colab',
      'generatedAt': iso(n.subtract(const Duration(days: 2))),
    });
  }

  // ── Locais de armazenamento ──────────────────────────────────────────────
  final locs = [
    ('Cozinha', 'Despensa principal', 'Prateleira A', 'Nível 1'),
    ('Almoxarifado', 'Material escolar e de higiene', 'Estante 3', 'Nível 2'),
    ('Cozinha', 'Geladeira industrial', 'Porta', null),
  ];
  for (var i = 0; i < locs.length; i++) {
    final (room, section, shelf, level) = locs[i];
    await db.collection('storage_locations').doc('loc-$i').set({
      'room': room,
      'section': section,
      'shelf': shelf,
      'level': level,
      'locationName': '$room · $section',
      'normalizedKey': 'loc-$i',
      'capacity': 120,
      'shelvesCount': 4,
      'levelsCount': 3,
      'productsPerLevel': 10,
      'isActive': true,
      'createdAt': iso(DateTime(2025, 2, 10)),
    });
  }

  // ── Receitas (saída automática) ──────────────────────────────────────────
  await db.collection('recipes').doc('r-1').set({
    'name': 'Café da manhã reforçado das turmas do período integral',
    'description': 'Leite com achocolatado, pão francês e banana para 45 crianças',
    'items': [
      {'productId': 'p-leite', 'productName': 'Leite UHT integral caixinha 1 litro (longa vida)', 'quantity': 8},
      {'productId': 'p-achoc', 'productName': 'Achocolatado em pó 400 g', 'quantity': 1},
      {'productId': 'p-pao', 'productName': 'Pão francês', 'quantity': 45},
      {'productId': 'p-banana', 'productName': 'Banana nanica', 'quantity': 5},
    ],
    'isActive': true,
    'isPredefined': true,
    'createdBy': kAdminUser.id,
    'createdAt': iso(DateTime(2025, 3, 1)),
  });
  await db.collection('recipes').doc('r-2').set({
    'name': 'Almoço: arroz e feijão',
    'description': null,
    'items': [
      {'productId': 'p-arroz', 'productName': 'Arroz branco tipo 1 pacote 5 kg', 'quantity': 2},
      {'productId': 'p-feijao', 'productName': 'Feijão carioca tipo 1', 'quantity': 1},
    ],
    'isActive': true,
    'isPredefined': false,
    'createdBy': kAdminUser.id,
    'createdAt': iso(DateTime(2025, 3, 5)),
  });

  // ── Necessidades (Portal do Doador) ──────────────────────────────────────
  final needs = [
    ('n-1', 'Leite UHT integral caixinha 1 litro (longa vida)', 'alimento', 'L', 'critica', 120, 40),
    ('n-2', 'Arroz branco tipo 1', 'alimento', 'kg', 'critica', 60, 10),
    ('n-3', 'Sabonete em barra glicerinado neutro', 'higienePessoal', 'un', 'alta', 80, 0),
    ('n-4', 'Caderno universitário 10 matérias', 'escolar', 'un', 'alta', 50, 12),
    ('n-5', 'Detergente líquido neutro', 'limpeza', 'un', 'normal', 30, 0),
  ];
  for (final (id, title, cat, unit, prio, sugg, pledged) in needs) {
    await db.collection('donation_needs').doc(id).set({
      'title': title,
      'productName': title,
      'productId': null,
      'categoryId': cat,
      'unit': unit,
      'priority': prio,
      'priorityRank': prio == 'critica' ? 1 : (prio == 'alta' ? 2 : 3),
      'suggestedQty': sugg,
      'pledgedQty': pledged,
      'remainingQty': sugg - pledged,
      'minShelfLifeDays': cat == 'alimento' ? 30 : 0,
      'isActive': true,
      'source': 'auto',
      'note': prio == 'critica' ? 'Estoque acaba em menos de uma semana' : null,
      'updatedAt': ts(n.subtract(const Duration(days: 1))),
      'validUntil': ts(n.add(const Duration(days: 20))),
    });
  }

  // ── Doações (uma de cada status) ─────────────────────────────────────────
  final statuses = ['pendente', 'aprovada', 'recebida', 'recebida_parcial', 'recusada', 'cancelada', 'expirada', 'pendente'];
  for (var i = 0; i < statuses.length; i++) {
    final status = statuses[i];
    final created = n.subtract(Duration(days: i * 2 + 1));
    final mine = i < 4;
    await db.collection('donations').doc('d-$i').set({
      'protocol': 'DOA-${n.year}-${(1000 + i).toString().padLeft(6, '0')}',
      'donorId': mine ? kDonorUser.id : 'donor-x$i',
      'donorSnapshot': {
        'displayName': mine ? kDonorUser.name : 'Supermercado Bom Preço Itapira Ltda.',
        'phone': '(19) 99876-5432',
      },
      'status': status,
      'items': [
        {
          'description': 'Leite UHT integral caixinha 1 litro (longa vida)',
          'category': 'alimento',
          'quantity': 24,
          'unit': 'L',
          'hasExpiry': true,
          'expiryDate': ts(n.add(const Duration(days: 90))),
          'condition': 'novo',
          'needId': 'n-1',
        },
        {
          'description': 'Caderno universitário 10 matérias capa dura',
          'category': 'escolar',
          'quantity': 10,
          'unit': 'un',
          'hasExpiry': false,
          'condition': 'novo',
          'needId': 'n-4',
        },
      ],
      'pointId': 'sede',
      'window': {
        'from': ts(created.add(const Duration(days: 2, hours: 9))),
        'to': ts(created.add(const Duration(days: 2, hours: 11))),
      },
      'termsAcceptedAt': ts(created),
      'createdAt': ts(created),
      'updatedAt': ts(created.add(const Duration(hours: 5))),
      'refusalReason': status == 'recusada' ? 'Produto com validade inferior a 30 dias' : null,
      'cancelReason': status == 'cancelada' ? 'Não consegui levar no horário combinado' : null,
      'approvalMessage': status == 'aprovada' ? 'Obrigado! Pode trazer na sede, de manhã.' : null,
      if (status.startsWith('recebida')) 'receivedAt': ts(created.add(const Duration(days: 2, hours: 10))),
      if (status.startsWith('recebida'))
        'receivedItems': [
          {'index': 0, 'receivedQty': status == 'recebida' ? 24 : 12, 'batchId': 'b-00', 'note': null},
          {'index': 1, 'receivedQty': 10, 'batchId': 'b-18', 'note': null},
        ],
      if (status == 'recebida')
        'impact': {
          'sector': 'Cozinha',
          'message': 'Seu leite virou o café da manhã de 45 crianças nesta semana. Obrigado!',
          'usedAt': ts(created.add(const Duration(days: 4))),
          'byName': kAdminUser.name,
        },
    });
  }
}
