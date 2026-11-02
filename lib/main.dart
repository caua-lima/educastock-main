import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/router/app_router.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/offline/offline_banner.dart';
import 'core/offline/offline_queue.dart';
import 'core/offline/offline_sync_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/alerts/presentation/controllers/alerts_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // No web (incluindo PWA iOS), usa URLs path-based em vez de hash (#/...).
  // Isso garante que rotas como /dashboard funcionem corretamente quando o app
  // é aberto via Add-to-Home-Screen no iOS/iPadOS.
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  await initializeDateFormatting('pt_BR');
  await FirebaseBootstrap.initialize();
  // Fila de gravações feitas sem internet (guardada no aparelho).
  final queueStore = await HiveQueueStore.open();
  runApp(
    ProviderScope(
      overrides: [offlineQueueProvider.overrideWithValue(OfflineQueue(queueStore))],
      child: const EducaStockApp(),
    ),
  );
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
      builder: (context, child) => Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child ?? const SizedBox.shrink()),
        ],
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
