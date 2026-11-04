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
  final dir = Directory('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts');
  Future<ByteData> b(String n) async => ByteData.sublistView(await File('${dir.path}/$n').readAsBytes());
  for (final f in ['Roboto', AppTypography.fontNunito, AppTypography.fontPoppins, AppTypography.fontProductName]) {
    await (FontLoader(f)
          ..addFont(b('roboto-regular.ttf'))
          ..addFont(b('roboto-medium.ttf'))
          ..addFont(b('roboto-bold.ttf'))
          ..addFont(b('roboto-black.ttf')))
        .load();
  }
  await (FontLoader('MaterialIcons')..addFont(b('materialicons-regular.otf'))).load();
}

const _telas = {
  'painel': '/dashboard',
  'estoque': '/products',
  'saida': '/movement?batchId=',
  'historico': '/history',
  'relatorios': '/reports',
  'doacoes': '/doacoes',
};
const _tamanhos = {'celular-390': Size(390, 844), 'pc-1440': Size(1440, 900)};

void main() {
  setUpAll(() async {
    AppTypography.useGoogleFonts = false;
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
    await _fonts();
  });

  for (final tela in _telas.entries) {
    for (final tam in _tamanhos.entries) {
      testWidgets('captura ${tela.key} ${tam.key}', (tester) async {
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
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('capturas/${tela.key}-${tam.key}.png'));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
        c.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }
  }
}
