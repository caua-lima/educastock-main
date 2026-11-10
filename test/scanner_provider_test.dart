// Regressão da reauditoria R01–R03: a consulta do scanner pertence sempre ao
// código exibido, "Limpar" invalida respostas pendentes e um código pode ser
// consultado de novo depois de terminar. Datasource falso, sem rede nem câmera.
import 'dart:async';

import 'package:educastock/features/scanner/data/datasources/open_food_facts_datasource.dart';
import 'package:educastock/features/scanner/presentation/controllers/scanner_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cada consulta fica pendente até o teste decidir a resposta.
class _FonteControlada implements OpenFoodFactsDatasource {
  final Map<String, List<Completer<ProductApiResult?>>> pendentes = {};
  final List<String> chamadas = [];

  Completer<ProductApiResult?> _novo(String fonte, String codigo) {
    chamadas.add('$fonte:$codigo');
    final c = Completer<ProductApiResult?>();
    pendentes.putIfAbsent('$fonte:$codigo', () => []).add(c);
    return c;
  }

  /// Responde a consulta mais antiga ainda aberta daquela fonte/código.
  void responder(String fonte, String codigo, ProductApiResult? r) {
    final lista = pendentes['$fonte:$codigo']!;
    lista.firstWhere((c) => !c.isCompleted).complete(r);
  }

  void falhar(String fonte, String codigo, Object erro) {
    final lista = pendentes['$fonte:$codigo']!;
    lista.firstWhere((c) => !c.isCompleted).completeError(erro);
  }

  @override
  Future<ProductApiResult?> lookupOpenFoodFacts(String barcode) =>
      _novo('off', barcode).future;
  @override
  Future<ProductApiResult?> lookupUpcItemDb(String barcode) =>
      _novo('upc', barcode).future;
  @override
  Future<ProductApiResult?> lookupBarcodeLookupApi(String barcode) =>
      _novo('bl', barcode).future;
  @override
  Future<ProductApiResult> lookupBarcode(String barcode) =>
      throw UnimplementedError();
}

ProductApiResult _achado(String codigo, String nome) =>
    ProductApiResult(barcode: codigo, found: true, name: nome);

Future<void> _rodarMicrotarefas() => Future<void>.delayed(Duration.zero);

void main() {
  late _FonteControlada fonte;
  late ProviderContainer container;
  ScannerNotifier notifier() => container.read(scannerProvider.notifier);
  ScannerState estado() => container.read(scannerProvider);

  setUp(() {
    fonte = _FonteControlada();
    container = ProviderContainer(overrides: [
      openFoodFactsProvider.overrideWithValue(fonte),
    ]);
    // Mantém o provider vivo durante o teste.
    container.listen(scannerProvider, (_, __) {});
  });
  tearDown(() => container.dispose());

  test('R01: resposta antiga de A não substitui o resultado de B', () async {
    unawaited(notifier().onBarcodeDetected('7890000000011'));
    unawaited(notifier().onBarcodeDetected('7890000000028'));
    await _rodarMicrotarefas();

    fonte.responder(
        'off', '7890000000028', _achado('7890000000028', 'Feijão B'));
    await _rodarMicrotarefas();
    fonte.responder(
        'off', '7890000000011', _achado('7890000000011', 'Arroz A'));
    await _rodarMicrotarefas();

    expect(estado().lastBarcode, '7890000000028');
    final r = estado().apiResult.value;
    expect(r?.barcode, '7890000000028');
    expect(r?.name, 'Feijão B');
    expect(estado().searchStep, WebSearchStep.done);
  });

  test('R01: resposta antiga também não avança as etapas do código novo',
      () async {
    unawaited(notifier().onBarcodeDetected('111'));
    unawaited(notifier().onBarcodeDetected('222'));
    await _rodarMicrotarefas();
    // A não encontrou no OFF: não pode empurrar B para a etapa UPC.
    fonte.responder('off', '111', null);
    await _rodarMicrotarefas();
    expect(estado().searchStep, WebSearchStep.openFoodFacts);
    expect(fonte.chamadas.where((c) => c.startsWith('upc:')), isEmpty);
  });

  test('R02: limpar invalida a consulta pendente', () async {
    unawaited(notifier().onBarcodeDetected('7890000000011'));
    await _rodarMicrotarefas();
    notifier().reset();
    fonte.responder(
        'off', '7890000000011', _achado('7890000000011', 'Arroz A'));
    await _rodarMicrotarefas();

    expect(estado().searchStep, WebSearchStep.idle);
    expect(estado().apiResult.value, isNull);
    expect(estado().lastBarcode, isNull);
  });

  test(
      'R03: depois de "não encontrado", consultar o mesmo código de novo faz nova busca',
      () async {
    final primeira = notifier().onBarcodeDetected('5550001');
    await _rodarMicrotarefas();
    fonte.responder('off', '5550001', null);
    await _rodarMicrotarefas();
    fonte.responder('upc', '5550001', null);
    await _rodarMicrotarefas();
    fonte.responder('bl', '5550001', null);
    await primeira;
    expect(estado().apiResult.value?.found, isFalse);

    final segunda = notifier().onBarcodeDetected('5550001');
    await _rodarMicrotarefas();
    expect(fonte.chamadas.where((c) => c == 'off:5550001').length, 2);
    fonte.responder('off', '5550001', _achado('5550001', 'Achado agora'));
    await segunda;
    expect(estado().apiResult.value?.name, 'Achado agora');
  });

  test('mesmo código chegando duas vezes durante a busca: uma consulta só',
      () async {
    unawaited(notifier().onBarcodeDetected('333'));
    unawaited(notifier().onBarcodeDetected('333'));
    await _rodarMicrotarefas();
    expect(fonte.chamadas.where((c) => c == 'off:333').length, 1);
  });

  test(
      'produto encontrado: reabrir o mesmo código usa o resultado; "Tentar novamente" força nova consulta',
      () async {
    final f = notifier().onBarcodeDetected('444');
    await _rodarMicrotarefas();
    fonte.responder('off', '444', _achado('444', 'Leite'));
    await f;
    await notifier().onBarcodeDetected('444');
    expect(fonte.chamadas.where((c) => c == 'off:444').length, 1,
        reason: 'cache do resultado encontrado');

    final f2 = notifier().tentarNovamente();
    await _rodarMicrotarefas();
    expect(fonte.chamadas.where((c) => c == 'off:444').length, 2);
    fonte.responder('off', '444', _achado('444', 'Leite integral'));
    await f2;
    expect(estado().apiResult.value?.name, 'Leite integral');
  });

  test(
      'falha de rede em todas as bases: "consulta indisponível", não "produto inexistente"',
      () async {
    final f = notifier().onBarcodeDetected('555');
    await _rodarMicrotarefas();
    fonte.falhar('off', '555',
        const ProductLookupException('Open Food Facts', 'connectionError'));
    await _rodarMicrotarefas();
    fonte.responder('upc', '555', null);
    await _rodarMicrotarefas();
    fonte.responder('bl', '555', null);
    await f;
    expect(estado().searchStep, WebSearchStep.done);
    expect(estado().apiResult.hasError, isTrue);
    expect(estado().apiResult.error, isA<ScannerLookupUnavailable>());
  });

  test('uma falha e depois um achado em outra base: vale o achado', () async {
    final f = notifier().onBarcodeDetected('666');
    await _rodarMicrotarefas();
    fonte.falhar('off', '666',
        const ProductLookupException('Open Food Facts', 'timeout'));
    await _rodarMicrotarefas();
    fonte.responder('upc', '666', _achado('666', 'Sabonete'));
    await f;
    expect(estado().apiResult.value?.name, 'Sabonete');
  });

  test('base que devolve resultado de OUTRO código é ignorada', () async {
    final f = notifier().onBarcodeDetected('777');
    await _rodarMicrotarefas();
    fonte.responder('off', '777', _achado('999', 'Produto errado'));
    await _rodarMicrotarefas();
    fonte.responder('upc', '777', null);
    await _rodarMicrotarefas();
    fonte.responder('bl', '777', null);
    await f;
    expect(estado().apiResult.value?.found, isFalse);
    expect(estado().apiResult.value?.barcode, '777');
  });

  test(
      'consulta que nunca responde vira "indisponível" após o limite (não trava)',
      () async {
    final rapido = ProviderContainer(overrides: [
      openFoodFactsProvider.overrideWithValue(fonte),
      scannerLookupTimeoutProvider
          .overrideWithValue(const Duration(milliseconds: 20)),
    ]);
    addTearDown(rapido.dispose);
    rapido.listen(scannerProvider, (_, __) {});
    // Nenhuma das três bases responde.
    await rapido.read(scannerProvider.notifier).onBarcodeDetected('888');
    final s = rapido.read(scannerProvider);
    expect(s.searchStep, WebSearchStep.done);
    expect(s.apiResult.error, isA<ScannerLookupUnavailable>());
    expect(fonte.chamadas, ['off:888', 'upc:888', 'bl:888']);
  });

  test('descartar o provider (sair do fluxo) invalida a resposta pendente',
      () async {
    final outro = ProviderContainer(
        overrides: [openFoodFactsProvider.overrideWithValue(fonte)]);
    final sub = outro.listen(scannerProvider, (_, __) {});
    unawaited(outro.read(scannerProvider.notifier).onBarcodeDetected('121'));
    await _rodarMicrotarefas();
    sub.close();
    outro.dispose();
    // Responder depois do descarte não pode lançar nem gravar estado.
    fonte.responder('off', '121', _achado('121', 'Tarde demais'));
    await _rodarMicrotarefas();
  });

  test('código vazio ou só espaços não consulta', () async {
    await notifier().onBarcodeDetected('   ');
    expect(fonte.chamadas, isEmpty);
    expect(estado().searchStep, WebSearchStep.idle);
  });
}
