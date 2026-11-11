import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/auth/presentation/widgets/faixa_visao_perfil.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/app_router.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/notifications/app_messenger.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/offline/offline_banner.dart';
import 'core/offline/offline_queue.dart';
import 'core/offline/offline_sync_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/alerts/presentation/controllers/alerts_provider.dart';
import 'features/auth/presentation/controllers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No web (incluindo PWA iOS), usa URLs path-based em vez de hash (#/...).
  // Isso garante que rotas como /dashboard funcionem corretamente quando o app
  // é aberto via Add-to-Home-Screen no iOS/iPadOS.
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  await _start();
}

/// Inicializa e abre o app. Se algo falhar (sem internet na primeira abertura, bloqueio
/// do navegador ao armazenamento local…), mostra uma tela com "Tentar de novo" em vez
/// de deixar a página em branco.
Future<void> _start() async {
  try {
    // Inicialização em paralelo: formatos de data, Firebase e a fila offline (Hive) não
    // dependem entre si, então o app abre mais rápido.
    final results = await Future.wait<Object?>([
      initializeDateFormatting('pt_BR'),
      FirebaseBootstrap.initialize(),
      HiveQueueStore.open(),
      // Tema lido antes da primeira tela: sem clarão do tema errado na abertura.
      ThemeModeController.lerPreferencia(),
    ]);
    // Fila de gravações feitas sem internet (guardada no aparelho).
    final queueStore = results[2]! as HiveQueueStore;
    final temaInicial = results[3]! as ThemeMode;
    runApp(
      ProviderScope(
        overrides: [
          offlineQueueProvider.overrideWithValue(OfflineQueue(queueStore)),
          themeModeProvider.overrideWith((ref) => ThemeModeController(inicial: temaInicial)),
        ],
        child: const EducaStockApp(),
      ),
    );
  } catch (error, stack) {
    debugPrint('[EducaStock] falha na inicialização: $error\n$stack');
    runApp(StartupErrorApp(onRetry: _start));
  }
}

/// Tela mostrada quando o app não consegue iniciar.
class StartupErrorApp extends StatelessWidget {
  final Future<void> Function() onRetry;
  const StartupErrorApp({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Não foi possível abrir o EducaStock agora.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Verifique a conexão com a internet e tente de novo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tentar de novo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EducaStockApp extends ConsumerWidget {
  const EducaStockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(pushNotificationsBootstrapProvider);
    ref.watch(alertsAutoCheckProvider);
    ref.watch(offlineSyncProvider); // mantém a sincronização ativa
    return MaterialApp.router(
      title: 'EducaStock',
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Localização pt-BR — date pickers, dialogs e formatos no idioma correto.
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      scrollBehavior: const _CasaScrollBehavior(),
      routerConfig: router,
      // Respeita a fonte maior do sistema até 200% (acessibilidade; validado pelo teste de
      // layout com fonte em 200%). Só evita letras menores que 85%.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.85,
        maxScaleFactor: 2.0,
        child: Column(
          children: [
            const FaixaVisaoPerfil(),
            const OfflineBanner(),
            Expanded(child: _EsperaASessao(child: child ?? const SizedBox.shrink())),
          ],
        ),
      ),
    );
  }
}

/// Enquanto o Firebase restaura a sessão (F5, link direto), nenhuma tela abre. Aberta sem
/// saber quem entrou, a tela mostra por um instante o menu errado e pede dados ao banco
/// sem login: o banco responde "sem permissão" e esses pedidos não se refazem depois do
/// login (os contadores de alertas ficavam zerados até o F5).
class _EsperaASessao extends ConsumerWidget {
  final Widget child;

  const _EsperaASessao({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carregando =
        ref.watch(authStateProvider.select((a) => a.isLoading && !a.hasValue));
    if (!carregando) return child;
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando'),
      ),
    );
  }
}

class _CasaScrollBehavior extends MaterialScrollBehavior {
  const _CasaScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}
