// Tela do scanner (reauditoria R04–R07), sem câmera física: no ambiente de
// teste a câmera não existe (o plugin não responde), então a tela precisa
// explicar o motivo e manter a digitação funcionando. A digitação valida, guarda
// no histórico uma vez e abre a revisão com o código intacto (rota codificada).
import 'package:educastock/core/router/app_router.dart';
import 'package:educastock/features/scanner/data/scan_history_repository.dart';
import 'package:educastock/features/scanner/presentation/pages/scanner_page.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Historico extends ScanHistoryRepository {
  _Historico() : super(db: FakeFirebaseFirestore());
  final registros = <(String, String)>[];
  @override
  Future<void> record(String code, {required String source}) async => registros.add((code, source));
}

class _Montagem {
  final _Historico historico = _Historico();
  final List<String> revisoes = [];
  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.scanner,
    routes: [
      GoRoute(path: AppRoutes.scanner, builder: (_, __) => const ScannerPage(limiteCamera: Duration(milliseconds: 500))),
      GoRoute(
        path: AppRoutes.productReview,
        builder: (_, s) {
          revisoes.add(s.uri.queryParameters['barcode'] ?? '');
          return Scaffold(body: Text('Revisão de ${s.uri.queryParameters['barcode']}'));
        },
      ),
    ],
  );

  Widget app() => ProviderScope(
        overrides: [scanHistoryRepositoryProvider.overrideWithValue(historico)],
        child: MaterialApp.router(routerConfig: router),
      );
}

/// Deixa as tentativas automáticas de abrir a câmera terminarem.
Future<void> _esperarCamera(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() {
    // Tela de celular.
  });

  testWidgets('sem câmera: explica o motivo e oferece "Digitar código" e "Tentar novamente"', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = _Montagem();
    await tester.pumpWidget(m.app());
    await _esperarCamera(tester);
    expect(find.text('Digitar código'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    // O diagnóstico técnico não aparece na interface comum.
    expect(find.byTooltip('Mostrar diagnóstico técnico'), findsNothing);
    // Controles com nome acessível.
    expect(find.byTooltip('Digitar o código'), findsOneWidget);
    expect(find.byTooltip('Ajuda do scanner'), findsOneWidget);
  });

  testWidgets('digitação: código inválido mostra o motivo; válido com símbolos vai intacto para a revisão, uma vez', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final m = _Montagem();
    await tester.pumpWidget(m.app());
    await _esperarCamera(tester);

    await tester.tap(find.byTooltip('Digitar o código'));
    await tester.pumpAndSettle();
    // EAN-13 com dígito verificador errado.
    await tester.enterText(find.byType(TextField), '7891000100104');
    await tester.tap(find.text('Buscar produto'));
    await tester.pumpAndSettle();
    expect(find.textContaining('último dígito'), findsOneWidget);
    expect(m.revisoes, isEmpty);

    // Código alfanumérico com &, #, + e %.
    await tester.tap(find.text('O código tem letras ou símbolos'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'AB&C#1+2%');
    await tester.tap(find.text('Buscar produto'));
    await tester.pumpAndSettle();
    expect(m.revisoes, ['AB&C#1+2%']);
    expect(find.text('Revisão de AB&C#1+2%'), findsOneWidget);
    expect(m.historico.registros, [('AB&C#1+2%', 'typed')]);

    // Voltar da revisão: nenhuma navegação ou registro duplicado.
    m.router.pop();
    await tester.pumpAndSettle();
    await _esperarCamera(tester);
    expect(m.revisoes.length, 1);
    expect(m.historico.registros.length, 1);
  });

  testWidgets('zeros à esquerda chegam à revisão sem perda', (tester) async {
    final m = _Montagem();
    await tester.pumpWidget(m.app());
    await _esperarCamera(tester);
    await tester.tap(find.byTooltip('Digitar o código'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0012345678905');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(m.revisoes, ['0012345678905']);
  });

  testWidgets('fechar a digitação sem código não navega', (tester) async {
    final m = _Montagem();
    await tester.pumpWidget(m.app());
    await _esperarCamera(tester);
    await tester.tap(find.byTooltip('Digitar o código'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // fora da folha
    await tester.pumpAndSettle();
    expect(m.revisoes, isEmpty);
    expect(find.byType(TextField), findsNothing);
    await _esperarCamera(tester); // a câmera volta a ser tentada ao fechar
  });

  testWidgets('fonte 200% em 320 px: aviso de câmera e ações sem estouro', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final m = _Montagem();
    await tester.pumpWidget(m.app());
    await _esperarCamera(tester);
    expect(find.text('Digitar código'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
