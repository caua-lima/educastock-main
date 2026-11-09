// Testes por requisito do Plano de Teste (Fatec, IQS004) que ainda não tinham cobertura
// automática: RF01 (perfis e rotas), RF04 (risco e previsão), RF05 (alertas) e RF18/RNF06
// (rascunho da doação sobrevive ao fechamento do app). Sem Firebase real.
import 'package:educastock/core/firebase/firebase_providers.dart';
import 'package:educastock/core/offline/offline_queue.dart';
import 'package:educastock/core/offline/offline_sync_controller.dart';
import 'package:educastock/core/router/app_router.dart';
import 'package:educastock/features/alerts/data/datasources/alert_checker_service.dart';
import 'package:educastock/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:educastock/features/auth/domain/entities/app_user.dart';
import 'package:educastock/features/auth/presentation/controllers/auth_provider.dart';
import 'package:educastock/features/batches/data/datasources/batches_remote_datasource.dart';
import 'package:educastock/features/batches/domain/entities/batch.dart';
import 'package:educastock/features/donations/domain/entities/donation_rules.dart';
import 'package:educastock/features/donations/presentation/controllers/donation_draft_notifier.dart';
import 'package:educastock/features/ml/data/repositories/rule_based_risk_classifier.dart';
import 'package:educastock/features/ml/domain/entities/consumption_forecast.dart';
import 'package:educastock/features/ml/domain/entities/risk_prediction.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_data.dart';

class _FakeAuth extends AuthRemoteDatasource {
  _FakeAuth(FakeFirebaseFirestore db) : super(firestore: db);
  @override
  bool get isEmailVerified => true;
}

AppUser _user(String id, UserRole role, {bool active = true}) => AppUser(
      id: id,
      name: 'Pessoa $id',
      email: '$id@teste.test',
      role: role,
      isActive: active,
      createdAt: DateTime(2026, 1, 1),
    );

Batch _batch(String id, {DateTime? expiry, bool noExpiry = false, int qty = 10, int initial = 10}) => Batch(
      id: id,
      productId: 'p-$id',
      productName: 'Produto $id',
      quantity: qty,
      initialQuantity: initial,
      expiryDate: expiry,
      noExpiry: noExpiry,
      entryDate: DateTime.now().subtract(const Duration(days: 3)),
      origin: 'doacao',
      createdBy: 'u',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Abre o app com [user] logado, tenta ir para [route] e devolve onde ele parou
/// (o redirecionamento por papel decide). Layout é coberto em responsive_layout_test.
Future<String> _landing(WidgetTester tester, AppUser? user, String route) async {
  final db = FakeFirebaseFirestore();
  await seedFakeData(db);
  final c = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    authStateProvider.overrideWith((ref) => Stream.value(user)),
    authDatasourceProvider.overrideWithValue(_FakeAuth(db)),
    offlineQueueProvider.overrideWithValue(OfflineQueue(InMemoryQueueStore())),
  ]);
  final original = FlutterError.onError;
  FlutterError.onError = (_) {}; // só o destino importa aqui
  String path;
  try {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: Consumer(
        builder: (_, ref, __) => MaterialApp.router(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    c.read(routerProvider).go(route);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    path = c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  } finally {
    FlutterError.onError = original;
    tester.takeException();
  }
  c.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  return path;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
  });

  group('RF01 — autenticação multi-perfil e rotas por papel', () {
    testWidgets('sem login, qualquer tela leva ao login', (tester) async {
      expect(await _landing(tester, null, '/dashboard'), '/login');
      expect(await _landing(tester, null, '/doador'), '/login');
    });

    testWidgets('equipe entra no painel; doador entra no portal do doador', (tester) async {
      expect(await _landing(tester, _user('a', UserRole.admin), '/login'), '/dashboard');
      expect(await _landing(tester, _user('d', UserRole.doador), '/login'), '/doador');
    });

    testWidgets('doador não acessa telas da equipe (estoque, relatórios)', (tester) async {
      expect(await _landing(tester, _user('d', UserRole.doador), '/products'), '/doador');
      expect(await _landing(tester, _user('d', UserRole.doador), '/reports'), '/doador');
    });

    testWidgets('equipe não entra na área do doador', (tester) async {
      expect(await _landing(tester, _user('e', UserRole.estoquista), '/doador/doar'), '/dashboard');
    });

    testWidgets('fila de doações: só admin e estoquista; voluntário e consulta voltam ao painel',
        (tester) async {
      expect(await _landing(tester, _user('e', UserRole.estoquista), '/doacoes'), '/doacoes');
      expect(await _landing(tester, _user('v', UserRole.voluntario), '/doacoes'), '/dashboard');
      expect(await _landing(tester, _user('c', UserRole.consulta), '/doacoes'), '/dashboard');
    });
  });

  group('RF04 — risco de vencimento (semáforo) e previsão de demanda', () {
    final classifier = RuleBasedRiskClassifier();
    RiskLevel level(Batch b) => classifier.classifySync(b).level;

    test('vencido e até 7 dias = vermelho; 8 a 30 dias = amarelo; longe = verde', () {
      final t = _today();
      expect(level(_batch('venc', expiry: t.subtract(const Duration(days: 2)))), RiskLevel.vermelho);
      expect(level(_batch('5d', expiry: t.add(const Duration(days: 5)))), RiskLevel.vermelho);
      expect(level(_batch('20d', expiry: t.add(const Duration(days: 20)), qty: 3)), RiskLevel.amarelo);
      expect(level(_batch('200d', expiry: t.add(const Duration(days: 200)))), RiskLevel.verde);
      expect(level(_batch('sem', noExpiry: true)), RiskLevel.verde);
    });

    test('probabilidades do semáforo somam 1', () {
      final p = classifier.classifySync(_batch('5d', expiry: _today().add(const Duration(days: 5))));
      expect(p.probabilities.fold<double>(0, (a, b) => a + b), closeTo(1.0, 0.001));
    });

    test('previsão: sugestão de compra = consumo mensal × 1,2 − estoque atual (nunca negativa)', () {
      final f = ConsumptionForecast.fromMap({
        'productId': 'p1',
        'productName': 'Leite',
        'forecastWeekly': 25.0,
        'forecastMonthly': 100.0,
        'currentStock': 0,
        'suggestedReplenishment': 0,
        'trend': 'stable',
      });
      expect(f.copyWithLiveStock(30).suggestedReplenishment, 90); // 120 − 30
      expect(f.copyWithLiveStock(30).needsReplenishment, isTrue);
      expect(f.copyWithLiveStock(500).suggestedReplenishment, 0);
      expect(f.copyWithLiveStock(500).needsReplenishment, isFalse);
    });
  });

  group('RF05 — alertas automáticos de vencimento', () {
    late FakeFirebaseFirestore db;
    late AlertCheckerService checker;

    Future<void> lote(String id, DateTime expiry) => db.collection('batches').doc(id).set({
          ..._batch(id, expiry: expiry).toMap(),
          'status': 'disponivel',
        });

    setUp(() {
      db = FakeFirebaseFirestore();
      checker = AlertCheckerService(batchesDs: BatchesRemoteDatasource(db: db), db: db);
    });

    test('cria alerta crítico (≤7 dias) e de atenção (≤30 dias); longe não gera alerta', () async {
      final t = _today();
      await lote('crit', t.add(const Duration(days: 3)));
      await lote('aten', t.add(const Duration(days: 20)));
      await lote('longe', t.add(const Duration(days: 90)));
      await checker.checkAndCreateAlerts();
      final alerts = (await db.collection('alerts').get()).docs.map((d) => d.data()).toList();
      expect(alerts.length, 2);
      expect(alerts.firstWhere((a) => a['batchId'] == 'crit')['level'], 'critical');
      expect(alerts.firstWhere((a) => a['batchId'] == 'aten')['level'], 'warning');
    });

    test('rodar de novo não duplica alertas abertos', () async {
      await lote('crit', _today().add(const Duration(days: 3)));
      await checker.checkAndCreateAlerts();
      await checker.checkAndCreateAlerts();
      expect((await db.collection('alerts').get()).size, 1);
    });

    test('lote que vence HOJE é crítico, mas não é anunciado como vencido', () async {
      await lote('hoje', _today());
      await checker.checkAndCreateAlerts();
      final a = (await db.collection('alerts').get()).docs.single.data();
      expect(a['level'], 'critical');
      expect(a['message'], isNot(contains('VENCIDO')));
      expect(a['message'], contains('hoje'));
    });

    test('lote já vencido gera alerta de descarte', () async {
      await lote('venc', _today().subtract(const Duration(days: 1)));
      await checker.checkAndCreateAlerts();
      expect((await db.collection('alerts').get()).docs.single.data()['message'], contains('VENCIDO'));
    });

    test('lote consumido sai da janela e o alerta é encerrado sozinho', () async {
      await lote('crit', _today().add(const Duration(days: 3)));
      await checker.checkAndCreateAlerts();
      await db.collection('batches').doc('crit').update({'status': 'distribuido'});
      await checker.checkAndCreateAlerts();
      expect((await db.collection('alerts').get()).docs.single.data()['resolved'], isTrue);
    });
  });

  group('RF18 / RNF06 — rascunho da doação sobrevive ao fechamento do app', () {
    test('itens do rascunho voltam depois de "fechar e abrir" o app', () async {
      SharedPreferences.setMockInitialValues({});
      final donor = _user('doador-1', UserRole.doador);
      ProviderContainer open() => ProviderContainer(overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(donor)),
          ]);

      final first = open();
      first.listen(currentUserProvider, (_, __) {});
      await first.read(authStateProvider.future);
      final draft = first.read(donationDraftProvider.notifier);
      draft.startCustom();
      draft.updateEditing(first.read(donationDraftProvider).editing!.copyWith(
            description: 'Leite em pó',
            quantity: 6,
            expiryDate: _today().add(const Duration(days: 120)),
          ));
      expect(draft.commitEditing(const DonationRules()), isNull);
      draft.setPoint('sede');
      await Future<void>.delayed(const Duration(milliseconds: 50)); // grava no aparelho
      first.dispose(); // "fechamento repentino"

      final second = open();
      second.listen(currentUserProvider, (_, __) {});
      await second.read(authStateProvider.future);
      await second.read(donationDraftProvider.notifier).restore();
      final restored = second.read(donationDraftProvider);
      expect(restored.items.single.description, 'Leite em pó');
      expect(restored.items.single.quantity, 6);
      expect(restored.pointId, 'sede');
      second.dispose();
    });
  });
}
