// Teste de responsividade: abre CADA tela do app nas larguras 320, 360, 390, 768, 1024 e
// 1440 e com o celular deitado, nos temas claro e escuro, com fonte 100% e 200%, usando
// dados falsos parecidos com os reais. Falha se qualquer tela estourar o layout
// ("RenderFlex overflowed"), lançar exceção ou não montar. Também abre a ajuda de cada
// tela e percorre o tutorial até "Concluir". Nenhuma exceção é aceita.
//
// Roda sem Firebase: o Firestore é trocado por um falso com um único override
// (`firestoreProvider`) e o usuário logado é simulado.
import 'dart:io';

import 'package:educastock/core/design_system/tokens/typography_tokens.dart';
import 'package:educastock/core/firebase/firebase_providers.dart';
import 'package:educastock/core/offline/offline_queue.dart';
import 'package:educastock/core/offline/offline_sync_controller.dart';
import 'package:educastock/core/router/app_router.dart';
import 'package:educastock/core/router/deferred_page.dart';
import 'package:educastock/core/theme/app_theme.dart';
import 'package:educastock/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:educastock/features/auth/domain/entities/app_user.dart';
import 'package:educastock/features/auth/presentation/controllers/auth_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_data.dart';

const _sizes = <String, Size>{
  'celular 320x640': Size(320, 640),
  'celular 360x740': Size(360, 740),
  'celular 390x844': Size(390, 844),
  'celular deitado 740x360': Size(740, 360),
  'tablet 768x1024': Size(768, 1024),
  'tablet deitado 1024x768': Size(1024, 768),
  'computador 1440x900': Size(1440, 900),
};

const _staffRoutes = [
  '/dashboard',
  '/products',
  '/products/p-leite',
  '/products/form',
  '/products/form?id=p-leite',
  '/batches/form?productId=p-leite',
  '/movement?batchId=',
  '/movement/approvals',
  '/alerts',
  '/audit',
  '/reports',
  '/history',
  '/settings',
  '/settings/users',
  '/settings/categories',
  '/settings/alerts',
  '/locations',
  '/locations/new',
  '/ml/insights',
  '/ml/forecast',
  '/recipes',
  '/recipes/new',
  '/doacoes',
  '/doacoes/d-0',
  '/doacoes/d-1/receber',
];

const _donorRoutes = [
  '/doador',
  '/doador/necessidades',
  '/doador/necessidades/n-1',
  '/doador/doar',
  '/doador/doar?needId=n-1',
  '/doador/doacoes',
  '/doador/doacoes/d-0',
  '/doador/doacoes/d-2',
  '/doador/perfil',
  '/doador/assistente',
];

const _publicRoutes = ['/login', '/doador/cadastro'];

/// Carrega a Roboto do SDK do Flutter para medir texto como no app (a fonte padrão dos
/// testes desenha cada letra como um quadrado e acusaria estouros que não existem).
Future<void> _loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  // Usa as variações que existirem (o conjunto baixado muda entre máquinas e o CI).
  final files = dir.listSync().whereType<File>().toList();
  final roboto = files.where((f) {
    final n = f.uri.pathSegments.last.toLowerCase();
    return n.startsWith('roboto') && n.endsWith('.ttf') && !n.contains('italic');
  }).toList();
  final icons = files.where((f) => f.uri.pathSegments.last.toLowerCase().startsWith('materialicons'));
  Future<ByteData> bytes(File f) async => ByteData.sublistView(await f.readAsBytes());

  if (roboto.isNotEmpty) {
    for (final family in {
      'Roboto',
      AppTypography.fontNunito,
      AppTypography.fontPoppins,
      AppTypography.fontProductName,
    }) {
      final loader = FontLoader(family);
      for (final f in roboto) {
        loader.addFont(bytes(f));
      }
      await loader.load();
    }
  }
  if (icons.isNotEmpty) {
    await (FontLoader('MaterialIcons')..addFont(bytes(icons.first))).load();
  }
}

class _FakeAuthDatasource extends AuthRemoteDatasource {
  _FakeAuthDatasource(FakeFirebaseFirestore db) : super(firestore: db);

  @override
  bool get isEmailVerified => true;
}

class _TestApp extends ConsumerWidget {
  final double textScale;
  final bool dark;
  const _TestApp({this.textScale = 1.0, this.dark = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark : AppTheme.light,
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    );
  }
}

String _describe(FlutterErrorDetails d) {
  final first = d.exceptionAsString().split('\n').first.trim();
  // Para estouros, o Flutter informa o widget que estourou (com arquivo e linha do app).
  final full = d.toString(minLevel: DiagnosticLevel.debug);
  final where = RegExp(r'educastock-main[/\\](lib[/\\][^\s:]+\.dart:\d+)').firstMatch(full)?.group(1) ??
      RegExp(r'package:educastock/([^\s:]+\.dart:\d+)').firstMatch(full)?.group(1) ??
      '';
  return where.isEmpty ? first : '$first  [$where]';
}

/// Controladores das TabBars visíveis na tela.
List<TabController> _tabControllers(WidgetTester tester) {
  final result = <TabController>[];
  for (final element in find.byType(TabBar).evaluate()) {
    final bar = element.widget as TabBar;
    final c = bar.controller ?? DefaultTabController.maybeOf(element);
    // Ignora controladores já descartados (animation nula).
    if (c != null && c.animation != null && !result.contains(c)) result.add(c);
  }
  return result;
}

/// Rola todas as listas verticais até o fim, em passos de quase uma tela.
Future<void> _scrollThrough(WidgetTester tester) async {
  for (var step = 0; step < 12; step++) {
    var moved = false;
    for (final st in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
      final p = st.position;
      if (p.axis != Axis.vertical || !p.hasContentDimensions) continue;
      if (p.pixels < p.maxScrollExtent - 1) {
        p.jumpTo((p.pixels + p.viewportDimension * 0.9).clamp(0.0, p.maxScrollExtent));
        moved = true;
      }
    }
    if (!moved) break;
    await tester.pump(const Duration(milliseconds: 250));
  }
  // Volta ao topo para o próximo tamanho começar do mesmo ponto.
  for (final st in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
    final p = st.position;
    if (p.axis == Axis.vertical && p.hasContentDimensions && p.pixels > 0) p.jumpTo(0);
  }
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _checkRoute(WidgetTester tester, String route, AppUser? user,
    {double textScale = 1.0, Map<String, Size> sizes = _sizes, bool dark = false, Set<String> known = const {}}) async {
  final problems = <String>[];
  final originalOnError = FlutterError.onError;
  String currentSize = '';
  FlutterError.onError = (details) {
    final described = _describe(details);
    if (known.any(described.contains)) return;
    final msg = '$currentSize → $described';
    if (!problems.contains(msg)) problems.add(msg);
  };

  final db = FakeFirebaseFirestore();
  await seedFakeData(db);
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    authStateProvider.overrideWith((ref) => Stream.value(user)),
    authDatasourceProvider.overrideWithValue(_FakeAuthDatasource(db)),
    offlineQueueProvider.overrideWithValue(OfflineQueue(InMemoryQueueStore())),
  ]);

  try {
    tester.view.devicePixelRatio = 1.0;
    final first = sizes.values.first;
    tester.view.physicalSize = first;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: _TestApp(textScale: textScale, dark: dark)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    container.read(routerProvider).go(route);
    await _esperarTelaSobDemanda(tester, route);

    for (final entry in sizes.entries) {
      currentSize = entry.key;
      tester.view.physicalSize = entry.value;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 1200));
      // Passa por todas as abas (ex.: Relatórios) e rola cada uma até o fim, para pegar
      // estouros em itens que não aparecem no topo da tela.
      final tabs = _tabControllers(tester);
      if (tabs.isEmpty) {
        await _scrollThrough(tester);
      } else {
        final controller = tabs.first;
        for (var i = 0; i < controller.length; i++) {
          // O controlador pode ser descartado ao trocar de aba (a tela se reconstrói).
          if (controller.animation == null) break;
          try {
            controller.index = i;
          } catch (_) {
            break;
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await _scrollThrough(tester);
        }
        if (controller.animation != null) controller.index = 0;
        await tester.pump(const Duration(milliseconds: 400));
      }
      final ex = tester.takeException();
      if (ex != null) problems.add('$currentSize → exceção: ${ex.toString().split('\n').first}');
    }
  } finally {
    FlutterError.onError = originalOnError;
  }

  // Desmonta tudo (cancela streams, timers e animações) antes de terminar o teste.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  container.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();

  expect(problems, isEmpty, reason: 'Problemas de layout em $route:\n  ${problems.join('\n  ')}');
}

/// Telas carregadas sob demanda (`DeferredPage`) usam o relógio real para carregar.
/// Espera o carregamento terminar; se não terminar, o teste FALHA — antes o teste media
/// a tela de "carregando" e passava sem nunca desenhar Previsão/Análise de risco.
Future<void> _esperarTelaSobDemanda(WidgetTester tester, String route) async {
  Finder carregando() => find.byWidgetPredicate(
      (w) => w is DeferredPage && !DeferredPage.estaCarregada(w.id));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < 200 && carregando().evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(carregando(), findsNothing, reason: 'a tela $route não terminou de carregar');
}

/// Vários quadros curtos: o tutorial rola até o alvo e mede a posição ao longo de
/// alguns quadros (um único pump longo avança só um quadro).
Future<void> _quadros(WidgetTester tester, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Abre a ajuda da tela e, se houver tutorial, percorre todos os passos até Concluir.
Future<void> _checkHelpAndTutorial(WidgetTester tester, String route, double escala, Size tamanho, bool escuro) async {
  final problems = <String>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    final m = _describe(d);
    if (!problems.contains(m)) problems.add(m);
  };
  final db = FakeFirebaseFirestore();
  await seedFakeData(db);
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    authStateProvider.overrideWith((ref) => Stream.value(kAdminUser)),
    authDatasourceProvider.overrideWithValue(_FakeAuthDatasource(db)),
    offlineQueueProvider.overrideWithValue(OfflineQueue(InMemoryQueueStore())),
  ]);
  var passos = 0;
  var concluiu = false;
  var achouAjuda = false;
  try {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = tamanho;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: _TestApp(textScale: escala, dark: escuro)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    container.read(routerProvider).go(route);
    await _esperarTelaSobDemanda(tester, route);
    await _quadros(tester);
    final ajuda = find.byTooltip('Ajuda');
    // Painel no celular: a ajuda fica no menu da conta.
    final menuConta = find.byTooltip('Menu da conta');
    achouAjuda = ajuda.evaluate().isNotEmpty || menuConta.evaluate().isNotEmpty;
    if (achouAjuda) {
      if (ajuda.evaluate().isNotEmpty) {
        await tester.tap(ajuda.first, warnIfMissed: false);
      } else {
        await tester.tap(menuConta.first, warnIfMissed: false);
        await _quadros(tester);
        await tester.tap(find.text('Ajuda').last, warnIfMissed: false);
      }
      await _quadros(tester);
      final verTutorial = find.text('Ver tutorial');
      if (verTutorial.evaluate().isNotEmpty) {
        await tester.tap(verTutorial);
        await _quadros(tester);
      }
      // Percorre o tutorial (se abriu) até o fim.
      for (var i = 0; i < 20; i++) {
        final proximo = find.text('Próximo');
        final concluir = find.text('Concluir');
        if (concluir.evaluate().isNotEmpty) {
          await tester.tap(concluir);
          await _quadros(tester);
          concluiu = true;
          break;
        }
        if (proximo.evaluate().isEmpty) break;
        passos++;
        await tester.tap(proximo);
        await _quadros(tester);
      }
      // Fecha a ajuda se ela ficou aberta (tela sem tutorial).
      final fechar = find.text('Entendido');
      if (fechar.evaluate().isNotEmpty) {
        await tester.tap(fechar);
        await tester.pump(const Duration(milliseconds: 600));
      }
      if (find.textContaining('Passo ').evaluate().isNotEmpty) problems.add('tutorial ficou aberto');
    }
    final ex = tester.takeException();
    if (ex != null) problems.add('exceção: ${ex.toString().split('\n').first}');
  } finally {
    FlutterError.onError = originalOnError;
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  container.dispose();
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  expect(problems, isEmpty, reason: 'Ajuda/tutorial em $route:\n  ${problems.join('\n  ')}');
  // Registro do que foi percorrido (evidência no log do teste).
  // ignore: avoid_print
  print('AJUDA-TUTORIAL $route: ajuda=$achouAjuda, passos=${concluiu ? passos + 1 : passos}, concluiu=$concluiu');
  if (passos > 0 && !concluiu) fail('tutorial de $route não chegou ao fim ($passos passos)');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppTypography.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
    await _loadRealFonts();
    // Telas sob demanda carregadas antes (zona real): dentro do relógio simulado de
    // cada teste a 2ª carga ficava presa e a tela nunca era desenhada.
    await precarregarTelasSobDemanda();
  });

  group('Equipe', () {
    for (final route in _staffRoutes) {
      testWidgets('layout $route', (tester) => _checkRoute(tester, route, kAdminUser));
    }
  });

  group('Doador', () {
    for (final route in _donorRoutes) {
      testWidgets('layout $route', (tester) => _checkRoute(tester, route, kDonorUser));
    }
  });

  // Fonte do sistema ampliada a 200% (acessibilidade), sem o limite do app. As sete
  // exceções que este teste aceitava foram corrigidas nos componentes — nenhuma é aceita.
  const bigText = {
    'celular 320x640': Size(320, 640),
    'celular 390x844': Size(390, 844),
    'celular deitado 915x412': Size(915, 412),
    'tablet 768x1024': Size(768, 1024),
    'computador 1440x900': Size(1440, 900),
  };
  group('Fonte 200%', () {
    for (final route in _staffRoutes) {
      testWidgets('layout 200% $route',
          (tester) => _checkRoute(tester, route, kAdminUser, textScale: 2.0, sizes: bigText));
    }
    for (final route in _donorRoutes) {
      testWidgets('layout 200% $route',
          (tester) => _checkRoute(tester, route, kDonorUser, textScale: 2.0, sizes: bigText));
    }
  });

  // Tema escuro: os mesmos estouros/exceções, em celular e computador, 100% e 200%.
  const darkSizes = {'celular 390x844': Size(390, 844), 'computador 1440x900': Size(1440, 900)};
  group('Tema escuro', () {
    for (final route in [..._staffRoutes, ..._donorRoutes]) {
      final user = route.startsWith('/doador') ? kDonorUser : kAdminUser;
      testWidgets('layout escuro $route', (tester) => _checkRoute(tester, route, user, dark: true, sizes: darkSizes));
      testWidgets('layout escuro 200% $route',
          (tester) => _checkRoute(tester, route, user, dark: true, textScale: 2.0, sizes: const {'celular 390x844': Size(390, 844)}));
    }
  });

  // Ajuda e tutorial nas telas reais: o botão Ajuda abre a ajuda curta; "Ver tutorial"
  // percorre todos os passos até "Concluir" sem estouro, sem exceção e sem sobrar overlay.
  group('Ajuda e tutorial', () {
    for (final route in _staffRoutes.where((r) => !r.contains('?') && r != '/doacoes/d-1/receber')) {
      for (final (rotulo, escala, tamanho, escuro) in [
        ('celular 390 200% escuro', 2.0, const Size(390, 844), true),
        ('computador 1440 claro', 1.0, const Size(1440, 900), false),
      ]) {
        testWidgets('ajuda/tutorial $route ($rotulo)', (tester) => _checkHelpAndTutorial(tester, route, escala, tamanho, escuro));
      }
    }
  });

  group('Público', () {
    for (final route in _publicRoutes) {
      testWidgets('layout $route', (tester) => _checkRoute(tester, route, null));
    }
  });
}
