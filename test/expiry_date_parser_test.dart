import 'package:educastock/core/utils/expiry_date_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 28);

  List<DateTime> parse(String text) => extractExpiryDates(text, now: now);

  test('lê DD/MM/AAAA', () {
    expect(parse('FAB 01/05/2026 VAL 15/03/2027'), [DateTime(2027, 3, 15)]);
  });

  test('lê DD/MM/AA com ano de dois dígitos', () {
    expect(parse('VENC 20/12/26'), [DateTime(2026, 12, 20)]);
  });

  test('aceita separadores ponto, hífen e espaço', () {
    expect(parse('10.11.2026'), [DateTime(2026, 11, 10)]);
    expect(parse('10-11-2026'), [DateTime(2026, 11, 10)]);
    expect(parse('10 11 2026'), [DateTime(2026, 11, 10)]);
  });

  test('MM/AAAA usa o último dia do mês', () {
    expect(parse('VAL 02/2027'), [DateTime(2027, 2, 28)]);
    expect(parse('VAL 02/2028'), [DateTime(2028, 2, 29)]);
  });

  test('MM/AA só vale com palavra-chave de validade', () {
    expect(parse('VAL 03/27'), [DateTime(2027, 3, 31)]);
    expect(parse('LOTE 03/27'), isEmpty);
  });

  test('mês abreviado em português e inglês', () {
    expect(parse('VAL 15 MAR 2027'), [DateTime(2027, 3, 15)]);
    expect(parse('VAL: 15MAR27'), [DateTime(2027, 3, 15)]);
    expect(parse('EXP DEC/2026'), [DateTime(2026, 12, 31)]);
    expect(parse('VALIDADE FEV 2027'), [DateTime(2027, 2, 28)]);
  });

  test('ignora datas passadas e inválidas', () {
    expect(parse('FAB 01/01/2025'), isEmpty);
    expect(parse('31/02/2027'), [DateTime(2027, 2, 28)]); // cai no mês/ano
    expect(parse('99/99/9999'), isEmpty);
    expect(parse(''), isEmpty);
  });

  test('aceita a data de hoje, mas não a de ontem', () {
    expect(parse('28/10/2026'), [DateTime(2026, 10, 28)]);
    expect(parse('27/10/2026'), isEmpty);
  });

  test('corrige O no lugar de zero e devolve em ordem, sem repetir', () {
    expect(parse('VAL 1O/11/2026'), [DateTime(2026, 11, 10)]);
    expect(
      parse('B 20/12/2027  A 05/11/2026  A 05/11/2026'),
      [DateTime(2026, 11, 5), DateTime(2027, 12, 20)],
    );
  });
}
