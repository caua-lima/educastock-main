// Teste de responsividade: abre CADA tela do app em 5 tamanhos (celular pequeno, celular,
// tablet, notebook e monitor) com dados falsos parecidos com os reais, e falha se qualquer
// tela estourar o layout ("RenderFlex overflowed"), lançar exceção ou não montar.
//
// Roda sem Firebase: o Firestore é trocado por um falso com um único override
// (`firestoreProvider`) e o usuário logado é simulado.
import 'dart:io';

import 'package:educastock/core/design_system/tokens/typography_tokens.dart';
import 'package:educastock/core/firebase/firebase_providers.dart';
import 'package:educastock/core/offline/offline_queue.dart';
import 'package:educastock/core/offline/offline_sync_controller.dart';
import 'package:educastock/core/router/app_router.dart';
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
  'celular pequeno 360x740': Size(360, 740),
  'celular 412x915': Size(412, 915),
  'tablet 820x1180': Size(820, 1180),
  'notebook 1366x768': Size(1366, 768),
  'monitor 1920x1080': Size(1920, 1080),
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
  Future<ByteData> bytes(String name) async =>
      ByteData.sublistView(await File('${dir.path}/$name').readAsBytes());

  final families = <String>{
    'Roboto',
    AppTypography.fontNunito,
    AppTypography.fontPoppins,
    AppTypography.fontProductName,
  };
  for (final family in families) {
    final loader = FontLoader(family)
      ..addFont(bytes('roboto-regular.ttf'))
      ..addFont(bytes('roboto-medium.ttf'))
      ..addFont(bytes('roboto-bold.ttf'))
      ..addFont(bytes('roboto-black.ttf'));
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')..addFont(bytes('materialicons-regular.otf'));
  await icons.load();
}

/// Datasource de login sem Firebase Auth (e-mail já verificado).
class _FakeAuthDatasource extends AuthRemoteDatasource {
  _FakeAuthDatasource(FakeFirebaseFirestore db) : super(firestore: db);

  @override
  bool get isEmailVerified => true;
}

class _TestApp extends ConsumerWidget {
  final double textScale;
  const _TestApp({this.textScale = 1.0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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

/// Pontos que ainda estouram com fonte em 200% (dívida registrada, não escondida).
/// Qualquer estouro NOVO fora desta lista reprova o teste. Ao corrigir um, remova-o daqui.
const _knownBigTextIssues = {
  'lib/features/alerts/presentation/pages/alerts_page.dart:985', // linha hora + origem do alerta
  'lib/features/batches/presentation/pages/batch_form_page.dart:1195', // título de seção com ícone
  'lib/features/locations/presentation/pages/locations_page.dart:336', // cabeçalho de cômodo
  'lib/features/products/presentation/pages/product_detail_page.dart:473', // cabeçalho expansível
  'lib/features/products/presentation/pages/product_detail_page.dart:1476', // selos do lote
  'lib/features/reports/presentation/pages/reports_page.dart:3431', // resumo "Demais lotes"
  'lib/features/settings/presentation/pages/categories_settings_page.dart:113', // cabeçalho
  'lib/features/settings/presentation/pages/users_management_page.dart:204', // seletor de perfil
};

Future<void> _checkRoute(WidgetTester tester, String route, AppUser? user,
    {double textScale = 1.0, Map<String, Size> sizes = _sizes, Set<String> known = const {}}) async {
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
        container: container, child: _TestApp(textScale: textScale)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    container.read(routerProvider).go(route);

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

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    AppTypography.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
    await _loadRealFonts();
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

  // Fonte do sistema ampliada a 200% (acessibilidade), sem o limite do app.
  const bigText = {'celular 412x915': Size(412, 915), 'notebook 1366x768': Size(1366, 768)};
  group('Fonte 200%', () {
    for (final route in _staffRoutes) {
      testWidgets('layout 200% $route',
          (tester) => _checkRoute(tester, route, kAdminUser,
              textScale: 2.0, sizes: bigText, known: _knownBigTextIssues));
    }
    for (final route in _donorRoutes) {
      testWidgets('layout 200% $route',
          (tester) => _checkRoute(tester, route, kDonorUser,
              textScale: 2.0, sizes: bigText, known: _knownBigTextIssues));
    }
  });

  group('Público', () {
    for (final route in _publicRoutes) {
      testWidgets('layout $route', (tester) => _checkRoute(tester, route, null));
    }
  });
}
