// Tema (reauditoria R12): Claro/Escuro/Sistema numa fonte única de estado; a
// carga assíncrona não sobrescreve a escolha recente; a troca não perde o que
// foi digitado nem a rolagem.
import 'package:educastock/core/theme/app_theme.dart';
import 'package:educastock/core/theme/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('preferência gravada é lida antes da primeira tela; vazio = Claro', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
    expect(await ThemeModeController.lerPreferencia(), ThemeMode.system);
    SharedPreferences.setMockInitialValues({});
    expect(await ThemeModeController.lerPreferencia(), ThemeMode.light);
  });

  test('escolha feita enquanto a preferência antiga carrega NÃO é sobrescrita', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final c = ThemeModeController(); // carrega 'dark' em segundo plano
    await c.setThemeMode(ThemeMode.system); // pessoa escolhe antes da carga terminar
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(c.state, ThemeMode.system);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'system', reason: 'persistido para a próxima abertura');
    c.dispose();
  });

  test('com valor inicial (main) não há carga atrasada', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final c = ThemeModeController(inicial: ThemeMode.dark);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.state, ThemeMode.dark);
    c.dispose();
  });

  testWidgets('trocar o tema não perde o texto digitado, a rolagem nem a rota', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final rolagem = ScrollController();
    final campo = TextEditingController();
    addTearDown(rolagem.dispose);
    addTearDown(campo.dispose);
    late WidgetRef refApp;
    await tester.pumpWidget(ProviderScope(
      overrides: [themeModeProvider.overrideWith((ref) => ThemeModeController(inicial: ThemeMode.light))],
      child: Consumer(builder: (context, ref, _) {
        refApp = ref;
        return MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ref.watch(themeModeProvider),
          home: Scaffold(
            body: ListView(
              controller: rolagem,
              children: [
                TextField(controller: campo, key: const Key('campo')),
                for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('linha $i')),
              ],
            ),
          ),
        );
      }),
    ));
    await tester.enterText(find.byKey(const Key('campo')), 'rascunho do lote');
    // Quem troca o tema toca no seletor — o campo deixa de ter o foco.
    FocusManager.instance.primaryFocus?.unfocus();
    rolagem.jumpTo(600);
    await tester.pump();

    await refApp.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    final ctx = tester.element(find.textContaining('linha ').first);
    expect(Theme.of(ctx).brightness, Brightness.dark);
    expect(campo.text, 'rascunho do lote');
    expect(rolagem.offset, 600);

    // Sistema: segue o brilho do aparelho.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await refApp.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.textContaining('linha ').first)).brightness, Brightness.dark);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.textContaining('linha ').first)).brightness, Brightness.light);
    expect(campo.text, 'rascunho do lote');
  });
}
