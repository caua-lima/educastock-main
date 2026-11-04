// A consulta externa do scanner: o código vai codificado na URL (QR/Code128
// podem ter '/', '#', '%', '&'…), 404 = "não encontrado" e falha de rede é
// erro distinguível — não vira "produto inexistente". Sem rede: adaptador falso.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:educastock/features/scanner/data/datasources/open_food_facts_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adaptador implements HttpClientAdapter {
  final List<RequestOptions> pedidos = [];
  final ResponseBody Function(RequestOptions) responder;
  _Adaptador(this.responder);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    pedidos.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object corpo, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(corpo),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

Dio _dio(_Adaptador a) => Dio(BaseOptions(baseUrl: 'https://teste.invalid'))..httpClientAdapter = a;

void main() {
  test('código com caracteres especiais vai codificado no caminho do Open Food Facts', () async {
    final a = _Adaptador((_) => _json({'status': 0}));
    final ds = OpenFoodFactsDatasource(dio: _dio(a));
    expect(await ds.lookupOpenFoodFacts('AB/12#3%&+?'), isNull);
    expect(a.pedidos.single.uri.path, '/api/v0/product/AB%2F12%233%25%26%2B%3F.json');
  });

  test('zeros à esquerda são preservados', () async {
    final a = _Adaptador((_) => _json({'status': 0}));
    final ds = OpenFoodFactsDatasource(dio: _dio(a));
    await ds.lookupOpenFoodFacts('0012345678905');
    expect(a.pedidos.single.uri.path, '/api/v0/product/0012345678905.json');
  });

  test('produto encontrado devolve nome e o próprio código', () async {
    final a = _Adaptador((_) => _json({
          'status': 1,
          'product': {'product_name': 'Arroz Tipo 1', 'brands': 'Marca, Outra'},
        }));
    final r = await OpenFoodFactsDatasource(dio: _dio(a)).lookupOpenFoodFacts('7891000100103');
    expect(r?.found, isTrue);
    expect(r?.name, 'Arroz Tipo 1');
    expect(r?.brand, 'Marca');
    expect(r?.barcode, '7891000100103');
  });

  test('404 é "não encontrado" (null); 500 e falha de conexão são erro', () async {
    final nao = _Adaptador((_) => _json({'status': 0}, 404));
    expect(await OpenFoodFactsDatasource(dio: _dio(nao)).lookupOpenFoodFacts('1'), isNull);

    final fora = _Adaptador((_) => _json({'erro': 'x'}, 503));
    expect(OpenFoodFactsDatasource(dio: _dio(fora)).lookupOpenFoodFacts('1'),
        throwsA(isA<ProductLookupException>()));

    final semRede = _Adaptador((o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'));
    expect(OpenFoodFactsDatasource(upcDio: _dio(semRede)).lookupUpcItemDb('1'),
        throwsA(isA<ProductLookupException>()));
  });

  test('UPC Item DB recebe o código como parâmetro codificado', () async {
    final a = _Adaptador((_) => _json({'items': []}));
    final r = await OpenFoodFactsDatasource(upcDio: _dio(a)).lookupUpcItemDb('A&B=1');
    expect(r, isNull);
    expect(a.pedidos.single.uri.queryParameters['upc'], 'A&B=1');
  });

  test('busca completa (compatibilidade) continua sem lançar quando tudo falha', () async {
    final semRede = _Adaptador((o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'));
    final r = await OpenFoodFactsDatasource(dio: _dio(semRede), upcDio: _dio(semRede)).lookupBarcode('42');
    expect(r.found, isFalse);
  });
}
