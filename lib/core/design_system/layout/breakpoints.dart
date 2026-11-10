import 'package:flutter/material.dart';

/// Pontos de quebra do layout (em pixels lógicos), alinhados ao Material 3.
///
/// - **compacto** (< 600): celular — navegação na barra inferior, uma coluna.
/// - **médio** (600–1199): tablet / janela estreita — navegação lateral recolhida.
/// - **expandido** (≥ 1200): computador — navegação lateral com nomes, conteúdo centralizado.
abstract class AppBreakpoints {
  static const double compact = 600;

  /// A partir desta largura a barra inferior vira navegação lateral.
  static const double rail = 720;
  static const double expanded = 1200;

  /// Largura máxima do conteúdo das telas principais (painéis, listas, relatórios).
  static const double contentMaxWidth = 1320;

  /// Largura máxima de formulários e telas de leitura (cadastros, configurações, detalhes).
  static const double formMaxWidth = 860;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompactScreen => screenWidth < AppBreakpoints.compact;
  bool get usesSideRail => screenWidth >= AppBreakpoints.rail;
}

/// Quantas colunas cabem numa largura, dado o tamanho mínimo de cada item.
///
/// Substitui `crossAxisCount` fixo: no celular dá 2, no tablet 3–4, no computador mais.
int responsiveColumns(
  double width, {
  double minItemWidth = 160,
  double spacing = 12,
  int min = 1,
  int max = 6,
}) {
  if (!width.isFinite || width <= 0) return min;
  final n = ((width + spacing) / (minItemWidth + spacing)).floor();
  return n.clamp(min, max);
}

/// Grade para [CasaProductCard]: colunas pela largura disponível (mínimo 2 no celular) e
/// altura calculada — cabeçalho de altura fixa (84) + corpo que cresce com a fonte.
///
/// Antes as grades usavam 2 colunas fixas e proporção fixa: no celular pequeno o corpo do
/// cartão estourava, e no computador cada cartão ficava com ~600 × 700 px.
SliverGridDelegate productCardGridDelegate(
  double width, {
  double minItemWidth = 160,
  double bodyHeight = 126,
  double spacing = 14,
  int maxColumns = 6,
  double textScale = 1,
}) {
  final cols = responsiveColumns(width,
      minItemWidth: minItemWidth, spacing: spacing, min: 2, max: maxColumns);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: cols,
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
    // O corpo do cartão cresce com a fonte do sistema (acessibilidade). O cabeçalho
    // (foto/ícone) tem altura fixa: antes era 16:9 da célula e, com cartões largos, a
    // foto/placeholder ocupava mais espaço que o nome.
    mainAxisExtent: 84 + bodyHeight * textScale.clamp(1.0, 2.0),
  );
}

/// Centraliza uma página inteira (inclusive a AppBar) com largura máxima.
///
/// Em telas largas a página vira uma "folha" no meio, com bordas discretas dos lados,
/// em vez de campos de formulário esticados por 1.900 px. No celular não muda nada.
class ResponsivePageFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsivePageFrame({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.formMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth + 32) return child;
        final cs = Theme.of(context).colorScheme;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                border: Border.symmetric(
                  vertical: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.45)),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
