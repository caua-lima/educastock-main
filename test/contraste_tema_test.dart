// Contraste AA das cores do tema (claro e escuro): texto normal 4,5:1 e elementos
// grandes/ícones 3:1. Referência: WCAG 2.2, critério 1.4.3 (contraste mínimo).
import 'package:educastock/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final claro = la > lb ? la : lb;
  final escuro = la > lb ? lb : la;
  return (claro + 0.05) / (escuro + 0.05);
}

void main() {
  for (final tema in {'claro': AppTheme.light, 'escuro': AppTheme.dark}.entries) {
    final cs = tema.value.colorScheme;
    // Pares texto/fundo usados nas telas.
    final textoNormal = <String, (Color, Color)>{
      'onSurface / surface': (cs.onSurface, cs.surface),
      'onSurfaceVariant / surface': (cs.onSurfaceVariant, cs.surface),
      'onSurfaceVariant / surfaceContainerLow': (cs.onSurfaceVariant, cs.surfaceContainerLow),
      'onSurfaceVariant / surfaceContainerHighest': (cs.onSurfaceVariant, cs.surfaceContainerHighest),
      'onPrimary / primary': (cs.onPrimary, cs.primary),
      'onPrimaryContainer / primaryContainer': (cs.onPrimaryContainer, cs.primaryContainer),
      'onSecondaryContainer / secondaryContainer': (cs.onSecondaryContainer, cs.secondaryContainer),
      'onErrorContainer / errorContainer': (cs.onErrorContainer, cs.errorContainer),
      'onError / error': (cs.onError, cs.error),
      'primary / surface (links e botões de texto)': (cs.primary, cs.surface),
      'error / surface (mensagens de erro)': (cs.error, cs.surface),
    };
    group('tema ${tema.key}', () {
      textoNormal.forEach((nome, par) {
        test('texto normal $nome ≥ 4,5:1', () {
          final c = _contraste(par.$1, par.$2);
          expect(c, greaterThanOrEqualTo(4.5), reason: '$nome = ${c.toStringAsFixed(2)}:1');
        });
      });
      test('contorno de campo (outline / surface) ≥ 3:1', () {
        final c = _contraste(cs.outline, cs.surface);
        expect(c, greaterThanOrEqualTo(3.0), reason: 'outline = ${c.toStringAsFixed(2)}:1');
      });
    });
  }
}
