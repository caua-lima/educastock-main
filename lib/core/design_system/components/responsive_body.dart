import 'package:flutter/material.dart';

/// Centraliza o conteúdo e limita a largura em telas muito largas (monitores ultrawide),
/// para gráficos e tabelas não esticarem até virar ilegíveis. No celular não muda nada:
/// o conteúdo ocupa toda a largura.
class ResponsiveBody extends StatelessWidget {
  final Widget child;

  /// Largura máxima do conteúdo, em pixels lógicos.
  final double maxWidth;

  const ResponsiveBody({super.key, required this.child, this.maxWidth = 1200});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
