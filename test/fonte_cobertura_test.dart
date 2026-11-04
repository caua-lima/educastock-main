// A fonte empacotada (assets/fonts, recorte latino da Roboto) cobre todo caractere
// que o app escreve na tela. Se alguém colocar um emoji ou símbolo fora do recorte, o
// navegador baixaria outra fonte da internet (ou mostraria um quadrado sem internet):
// este teste falha antes disso chegar ao usuário.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Caracteres mapeados pela tabela `cmap` (formato 4) de um arquivo TrueType.
Set<int> _caracteresDaFonte(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  final numTabelas = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < numTabelas; i++) {
    final reg = 12 + 16 * i;
    if (String.fromCharCodes(bytes.sublist(reg, reg + 4)) == 'cmap') cmap = d.getUint32(reg + 8);
  }
  expect(cmap, isNot(-1), reason: 'fonte sem tabela cmap');
  final n = d.getUint16(cmap + 2);
  final saida = <int>{};
  for (var i = 0; i < n; i++) {
    final plataforma = d.getUint16(cmap + 4 + 8 * i);
    final codificacao = d.getUint16(cmap + 6 + 8 * i);
    final off = cmap + d.getUint32(cmap + 8 + 8 * i);
    if (plataforma != 3 || codificacao != 1 || d.getUint16(off) != 4) continue;
    final segX2 = d.getUint16(off + 6);
    final fins = off + 14;
    final inicios = fins + segX2 + 2;
    final deltas = inicios + segX2;
    final rangeOffsets = deltas + segX2;
    for (var s = 0; s < segX2 ~/ 2; s++) {
      final fim = d.getUint16(fins + 2 * s);
      final ini = d.getUint16(inicios + 2 * s);
      final delta = d.getInt16(deltas + 2 * s);
      final ro = d.getUint16(rangeOffsets + 2 * s);
      for (var c = ini; c <= fim && c != 0xFFFF; c++) {
        int glifo;
        if (ro == 0) {
          glifo = (c + delta) & 0xFFFF;
        } else {
          final pos = rangeOffsets + 2 * s + ro + 2 * (c - ini);
          final g = d.getUint16(pos);
          glifo = g == 0 ? 0 : (g + delta) & 0xFFFF;
        }
        if (glifo != 0) saida.add(c);
      }
    }
  }
  return saida;
}

bool _invisivel(int c) => (c >= 0x200B && c <= 0x200F) || c == 0xFEFF || c == 0xFE0F;

void main() {
  test('todo caractere do app existe nos quatro pesos da fonte empacotada', () {
    final fontes = Directory('assets/fonts').listSync().whereType<File>().where((f) => f.path.endsWith('.ttf')).toList();
    expect(fontes, hasLength(4));
    final cobertos = fontes.map((f) => _caracteresDaFonte(f.readAsBytesSync())).reduce((a, b) => a.intersection(b));
    expect(cobertos.contains('ç'.codeUnitAt(0)) && cobertos.contains('ã'.codeUnitAt(0)), isTrue);

    final faltando = <String>{};
    for (final arq in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final linhas = arq.readAsLinesSync();
      for (var i = 0; i < linhas.length; i++) {
        var l = linhas[i];
        if (l.trimLeft().startsWith('//')) continue;
        final comentario = l.indexOf(' // ');
        if (comentario >= 0) l = l.substring(0, comentario);
        for (final c in l.runes) {
          if (c > 0x7E && !_invisivel(c) && !cobertos.contains(c)) {
            faltando.add('${arq.path}:${i + 1} U+${c.toRadixString(16).toUpperCase()} "${String.fromCharCode(c)}"');
          }
        }
      }
    }
    expect(faltando, isEmpty, reason: 'caracteres fora da fonte:\n${faltando.join('\n')}');
  });
}
