// Script de capturas: fica fora de test/ de propósito, mas usa os mesmos ganchos de teste.
// ignore_for_file: invalid_use_of_visible_for_testing_member
// Gera capturas das telas principais com dados de exemplo (sem Firebase), em celular e PC.
//
//   flutter test tool/capturas_test.dart --update-goldens
//
// As imagens ficam em tool/capturas/. Não roda no `flutter test` normal (está fora de
// test/), porque a renderização de fontes muda entre sistemas operacionais.
import 'dart:io';

import 'package:educastock/core/design_system/tokens/typography_tokens.dart';
import 'package:educastock/core/firebase/firebase_providers.dart';
import 'package:educastock/core/offline/offline_queue.dart';
import 'package:educastock/core/offline/offline_sync_controller.dart';
import 'package:educastock/core/router/app_router.dart';
import 'package:educastock/core/theme/app_theme.dart';
import 'package:educastock/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:educastock/features/auth/presentation/controllers/auth_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/fake_data.dart';

class _FakeAuth extends AuthRemoteDatasource {
  _FakeAuth(FakeFirebaseFirestore db) : super(firestore: db);
  @override
  bool get isEmailVerified => true;
}

Future<void> _fonts() async {
  // A mesma fonte empacotada no app (assets/fonts) e os ícones Material do SDK.
  Future<ByteData> b(File f) async => ByteData.sublistView(await f.readAsBytes());
  final loader = FontLoader(AppTypography.fontFamily);
  for (final f in Directory('assets/fonts').listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
    loader.addFont(b(f));
  }
  await loader.load();
  final dir = Directory('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
  await (FontLoader('MaterialIcons')..addFont(b(File('${dir.path}/materialicons-regular.otf')))).load();
}

const _telas = {
  'painel': '/dashboard',
  'estoque': '/products',
  'saida': '/movement?batchId=',
  'historico': '/history',
  'relatorios': '/reports',
  'doacoes': '/doacoes',
  'alertas': '/alerts',
  'configuracoes': '/settings',
  'scanner': '/scanner',
};
const _tamanhos = {'celular-390': Size(390, 844), 'pc-1440': Size(1440, 900)};

/// Variações: tema claro/escuro e fonte ampliada (200%, só no celular, onde aperta).
const _variacoes = <String, ({bool escuro, double fonte, bool soCelular})>{
  '': (escuro: false, fonte: 1.0, soCelular: false),
  '-escuro': (escuro: true, fonte: 1.0, soCelular: false),
  '-fonte200': (escuro: false, fonte: 2.0, soCelular: true),
};

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
    await _fonts();
    await precarregarTelasSobDemanda();
  });

  for (final tela in _telas.entries) {
    for (final tam in _tamanhos.entries) {
     for (final v in _variacoes.entries) {
      if (v.value.soCelular && !tam.key.startsWith('celular')) continue;
      testWidgets('captura ${tela.key} ${tam.key}${v.key}', (tester) async {
        final db = FakeFirebaseFirestore();
        await seedFakeData(db);
        final c = ProviderContainer(overrides: [
          firestoreProvider.overrideWithValue(db),
          authStateProvider.overrideWith((ref) => Stream.value(kAdminUser)),
          authDatasourceProvider.overrideWithValue(_FakeAuth(db)),
          offlineQueueProvider.overrideWithValue(OfflineQueue(InMemoryQueueStore())),
        ]);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = tam.value;
        await tester.pumpWidget(UncontrolledProviderScope(
          container: c,
          child: Consumer(
            builder: (_, ref, __) => MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: v.value.escuro ? ThemeMode.dark : ThemeMode.light,
              builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(v.value.fonte)),
                child: child!,
              ),
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
        c.read(routerProvider).go(tela.value);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('capturas/${tela.key}-${tam.key}${v.key}.png'));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        c.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
     }
    }
  }
}
