// Tutorial (reauditoria R09–R11): Concluir ≠ Pular, onFinish exatamente uma
// vez, todas as saídas limpam o estado global e devolvem o foco; controles
// acessíveis em tela deitada e fonte 200%; alvo ausente não trava.
import 'package:educastock/core/design_system/components/casa_help_modal.dart';
import 'package:educastock/core/design_system/components/casa_tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tela extends StatelessWidget {
  final List<GlobalKey> chaves;
  final void Function(BuildContext) abrir;
  final ThemeData? tema;
  const _Tela({required this.chaves, required this.abrir, this.tema});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: tema,
      home: Scaffold(
        body: ListView(
          children: [
            for (var i = 0; i < chaves.length; i++)
              Container(key: chaves[i], height: 260, margin: const EdgeInsets.all(8), color: Colors.blue, child: Text('Bloco $i')),
            Builder(builder: (ctx) => ElevatedButton(onPressed: () => abrir(ctx), child: const Text('Abrir tutorial'))),
          ],
        ),
      ),
    );
  }
}

List<TutorialStep> _passos(List<GlobalKey> chaves) => [
      for (var i = 0; i < chaves.length; i++)
        TutorialStep(key: chaves[i], title: 'Passo ${i + 1}', description: 'Explicação do bloco $i', icon: Icons.info),
    ];

Future<void> _abrir(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Abrir tutorial'), 300);
  await tester.tap(find.text('Abrir tutorial'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TutorialProgresso.usuarioAtual = 'u-teste';
  });
  tearDown(() => expect(tutorialActiveNotifier.value, isFalse, reason: 'estado global limpo em toda saída'));

  testWidgets('Concluir chama onFinish exatamente uma vez (e não onSkip); progresso fica salvo', (tester) async {
    final chaves = List.generate(3, (_) => GlobalKey());
    var fim = 0, pulo = 0;
    await tester.pumpWidget(_Tela(
      chaves: chaves,
      abrir: (ctx) => showCasaTutorial(context: ctx, steps: _passos(chaves), id: 'teste', onFinish: () => fim++, onSkip: () => pulo++),
    ));
    await _abrir(tester);
    expect(tutorialActiveNotifier.value, isTrue);
    expect(find.text('Passo 1 de 3'), findsOneWidget);
    expect(find.text('Voltar'), findsNothing, reason: 'primeiro passo não tem Voltar');

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Passo 2 de 3'), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Passo 1 de 3'), findsOneWidget);
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Concluir'), findsOneWidget);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(fim, 1);
    expect(pulo, 0);
    expect(find.text('Passo 3 de 3'), findsNothing, reason: 'overlay removido');
    expect(await TutorialProgresso.concluido('teste'), isTrue);
  });

  testWidgets('Pular cancela: onSkip, nunca onFinish, e não marca como concluído', (tester) async {
    final chaves = List.generate(2, (_) => GlobalKey());
    var fim = 0, pulo = 0;
    await tester.pumpWidget(_Tela(
      chaves: chaves,
      abrir: (ctx) => showCasaTutorial(context: ctx, steps: _passos(chaves), id: 'pulo', onFinish: () => fim++, onSkip: () => pulo++),
    ));
    await _abrir(tester);
    await tester.tap(find.text('Pular tutorial'));
    await tester.pumpAndSettle();
    expect((fim, pulo), (0, 1));
    expect(find.textContaining('Passo'), findsNothing);
    expect(await TutorialProgresso.concluido('pulo'), isFalse);
  });

  testWidgets('Escape e Voltar do aparelho saem como "pular" e devolvem o foco a quem abriu', (tester) async {
    final chaves = List.generate(2, (_) => GlobalKey());
    var pulo = 0;
    await tester.pumpWidget(_Tela(
      chaves: chaves,
      abrir: (ctx) => showCasaTutorial(context: ctx, steps: _passos(chaves), onSkip: () => pulo++),
    ));
    // Foco no botão que abre.
    await tester.scrollUntilVisible(find.text('Abrir tutorial'), 300);
    final botao = find.widgetWithText(ElevatedButton, 'Abrir tutorial');
    Focus.of(tester.element(find.text('Abrir tutorial'))).requestFocus();
    await tester.pump();
    await tester.tap(botao);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(pulo, 1);
    expect(find.textContaining('Passo'), findsNothing);
    final foco = FocusManager.instance.primaryFocus;
    expect(foco?.context?.findAncestorWidgetOfExactType<ElevatedButton>(), isNotNull,
        reason: 'foco volta ao botão que abriu o tutorial');

    // Botão Voltar do sistema.
    await tester.tap(botao);
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(pulo, 2);
    expect(find.textContaining('Passo'), findsNothing);
  });

  testWidgets('teclado: seta direita avança; Concluir pelo teclado também finaliza uma vez', (tester) async {
    final chaves = List.generate(2, (_) => GlobalKey());
    var fim = 0;
    await tester.pumpWidget(_Tela(chaves: chaves, abrir: (ctx) => showCasaTutorial(context: ctx, steps: _passos(chaves), onFinish: () => fim++)));
    await _abrir(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Passo 2 de 2'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(fim, 1);
  });

  testWidgets('alvo ausente (lista preguiçosa / sem permissão): mostra o passo sem destaque, sem travar', (tester) async {
    final presente = GlobalKey();
    final ausente = GlobalKey(); // nunca montado
    await tester.pumpWidget(_Tela(
      chaves: [presente],
      abrir: (ctx) => showCasaTutorial(context: ctx, steps: [
        TutorialStep(key: presente, title: 'Presente', description: 'ok', icon: Icons.info),
        TutorialStep(key: ausente, title: 'Ausente', description: 'some', icon: Icons.info),
      ]),
    ));
    await _abrir(tester);
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Ausente'), findsOneWidget);
    expect(find.textContaining('não está visível agora'), findsOneWidget);
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
  });

  for (final (nome, tamanho) in [('celular deitado', Size(740, 360)), ('celular 320', Size(320, 640)), ('computador', Size(1440, 900))]) {
    testWidgets('fonte 200% + $nome, claro e escuro: Pular, Voltar e Próximo à vista e sem estouro', (tester) async {
      for (final tema in [ThemeData.light(), ThemeData.dark()]) {
        tester.view.physicalSize = tamanho;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final chaves = List.generate(3, (_) => GlobalKey());
        await tester.pumpWidget(_Tela(tema: tema, chaves: chaves, abrir: (ctx) => showCasaTutorial(context: ctx, steps: _passos(chaves))));
        await _abrir(tester);
        await tester.tap(find.text('Próximo'));
        await tester.pumpAndSettle();
        for (final rotulo in ['Pular tutorial', 'Voltar', 'Próximo']) {
          final f = find.text(rotulo);
          expect(f, findsOneWidget, reason: rotulo);
          final r = tester.getRect(f);
          expect(r.top >= 0 && r.bottom <= tamanho.height && r.left >= 0 && r.right <= tamanho.width, isTrue,
              reason: '$rotulo dentro da tela ($r)');
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Pular tutorial'));
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('ajuda curta: mostra dúvidas e "Ver tutorial" (ou "Rever" depois de concluir)', (tester) async {
    var tutorial = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showCasaHelpModal(
                context: ctx,
                pageTitle: 'Estoque',
                pageDescription: 'Produtos e saldos.',
                tips: const [HelpTip(icon: Icons.search, title: 'Buscar', description: 'Por nome.')],
                faq: const [HelpFaq(pergunta: 'Pergunta?', resposta: 'Resposta.')],
                tutorialId: 'estoque',
                onVerTutorial: () => tutorial++,
              ),
              child: const Text('Ajuda'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Ajuda'));
    await tester.pumpAndSettle();
    expect(find.text('Ajuda: Estoque'), findsOneWidget);
    await tester.tap(find.text('Pergunta?'));
    await tester.pumpAndSettle();
    expect(find.text('Resposta.'), findsOneWidget);
    await tester.tap(find.text('Ver tutorial'));
    await tester.pumpAndSettle();
    expect(tutorial, 1);

    await TutorialProgresso.marcarConcluido('estoque');
    await tester.tap(find.text('Ajuda'));
    await tester.pumpAndSettle();
    expect(find.text('Rever tutorial'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(tutorial, 1, reason: 'Fechar não abre o tutorial');
  });

  testWidgets('botão Ajuda: nome acessível, dica e alvo de 48', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [Builder(builder: (ctx) => buildHelpButton(context: ctx, onPressed: () {}))]),
      ),
    ));
    expect(find.bySemanticsLabel('Ajuda desta tela'), findsOneWidget);
    expect(find.byTooltip('Ajuda'), findsOneWidget);
    final tam = tester.getSize(find.byType(InkWell).first);
    expect(tam.width >= 48 && tam.height >= 48, isTrue);
    handle.dispose();
  });
}
