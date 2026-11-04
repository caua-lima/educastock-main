// Código lido/digitado (reauditoria R05): preservado como texto, validado com
// mensagem útil e sempre codificado na rota.
import 'package:educastock/core/router/app_router.dart';
import 'package:educastock/features/scanner/domain/codigo_barras.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('normaliza sem mexer em zeros nem símbolos', () {
    expect(normalizarCodigo('  0012345678905\n'), '0012345678905');
    expect(normalizarCodigo('​AB&C#1+2%3'), 'AB&C#1+2%3');
  });

  test('dígito verificador GTIN: EAN-13, EAN-8, UPC-A e GTIN-14', () {
    expect(gtinValido('7891000100103'), isTrue);
    expect(gtinValido('7891000100104'), isFalse);
    expect(gtinValido('96385074'), isTrue);
    expect(gtinValido('036000291452'), isTrue);
    expect(gtinValido('10012345678902'), isTrue);
  });

  test('validação: vazio, longo, EAN com dígito errado; alfanumérico passa', () {
    expect(validarCodigo('   '), isNotNull);
    expect(validarCodigo('9' * 300), contains('muito longo'));
    expect(validarCodigo('7891000100104'), contains('último dígito'));
    expect(validarCodigo('7891000100103'), isNull);
    expect(validarCodigo('0012345'), isNull, reason: 'código interno numérico curto');
    expect(validarCodigo('CODE-128/ABC'), isNull);
    expect(validarCodigo('https://exemplo.org/?a=1&b=2#x'), isNull);
  });

  test('endereço de QR é reconhecido (para avisar, nunca abrir)', () {
    expect(pareceEndereco('https://exemplo.org'), isTrue);
    expect(pareceEndereco('www.exemplo.org'), isTrue);
    expect(pareceEndereco('7891000100103'), isFalse);
  });

  test('rota de revisão codifica o código e o go_router devolve o mesmo texto', () {
    for (final codigo in ['0012345678905', 'A&B=1', 'X#Y', '1+2', '100%', 'a b', 'https://x.org/?q=1&r=2#f']) {
      final rota = rotaRevisao(codigo);
      expect(rota.startsWith(AppRoutes.productReview), isTrue);
      final uri = Uri.parse(rota);
      expect(uri.queryParameters['barcode'], codigo, reason: rota);
      expect(uri.queryParameters.keys, ['barcode'], reason: 'nenhum parâmetro extra criado por & no código');
      expect(uri.fragment, isEmpty, reason: '# no código não vira âncora');
    }
  });

  test('rota com vários parâmetros ignora os nulos', () {
    final r = rotaComParametros('/x', {'a': '1&2', 'b': null});
    expect(Uri.parse(r).queryParameters, {'a': '1&2'});
    expect(rotaComParametros('/x', {}), '/x');
  });

  testWidgets('a rota chega à tela com o código idêntico (go_router real)', (tester) async {
    String? recebido;
    final router = GoRouter(
      initialLocation: rotaRevisao('A&B#C+1%'),
      routes: [
        GoRoute(
          path: AppRoutes.productReview,
          builder: (_, s) {
            recebido = s.uri.queryParameters['barcode'];
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(_App(router));
    expect(recebido, 'A&B#C+1%');
  });
}

class _App extends StatelessWidget {
  final GoRouter router;
  const _App(this.router);
  @override
  Widget build(BuildContext context) => WidgetsApp.router(routerConfig: router, color: const Color(0xFF000000));
}
