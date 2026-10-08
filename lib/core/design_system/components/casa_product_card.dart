import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../tokens/typography_tokens.dart';

/// Card unificado para exibir produto em listas (Estoque, Saída, Receita).
/// Layout: 2 cards por linha, imagem grande no topo, nome com fonte distinta,
/// metadata embaixo e área opcional de ações (ex: stepper de quantidade).
///
/// Áreas:
///  - [headerBadgeLeft] / [headerBadgeRight]: pequenos badges sobrepostos
///    ao header (ex: badge de risco ML, badge de validade).
///  - [trailingBadge]: badge maior no canto do card (ex: ∞ sem validade).
///  - [footer]: linha opcional sob o nome (ex: estoque/categoria).
///  - [actionFooter]: faixa de ação no rodapé (ex: stepper +/− para saída).
class CasaProductCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final IconData fallbackIcon;
  final List<Color> palette; // [accent, accentDark]
  final VoidCallback? onTap;
  final Widget? headerBadgeLeft;
  final Widget? headerBadgeRight;
  final Widget? trailingBadge;
  final Widget? footer;
  final Widget? actionFooter;
  final bool inactive;
  final int animationIndex;

  const CasaProductCard({
    super.key,
    required this.name,
    required this.palette,
    required this.fallbackIcon,
    this.imageUrl,
    this.onTap,
    this.headerBadgeLeft,
    this.headerBadgeRight,
    this.trailingBadge,
    this.footer,
    this.actionFooter,
    this.inactive = false,
    this.animationIndex = 0,
  });

  static const palettePrimary = [Color(0xFF1D5FA8), Color(0xFF1A3A6B)];
  static const paletteRed     = [Color(0xFFDC2626), Color(0xFFB91C1C)];
  static const paletteYellow  = [Color(0xFFD97706), Color(0xFFB45309)];
  static const paletteGreen   = [Color(0xFF059669), Color(0xFF047857)];
  static const paletteBlue    = [Color(0xFF2563EB), Color(0xFF1D4ED8)];
  static const paletteGray    = [Color(0xFF6B7280), Color(0xFF4B5563)];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final accent = palette[0];
    final accentDark = palette[1];
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = accent.withValues(alpha: isDark ? 0.35 : 0.18);

    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header com imagem grande / ícone categoria ─────────────
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  // Background gradient (visível como fallback)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accentDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  // Círculo decorativo
                  Positioned(
                    right: -16,
                    top: -16,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                  ),
                  // Imagem real OU ícone grande
                  Positioned.fill(
                    child: imageUrl != null && imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Center(
                              child: Icon(
                                fallbackIcon,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 42,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.32),
                                    width: 1.4,
                                  ),
                                ),
                                child: Icon(fallbackIcon,
                                    color: Colors.white, size: 26),
                              ),
                            ),
                          )
                        : Center(
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.32),
                                  width: 1.4,
                                ),
                              ),
                              child: Icon(
                                fallbackIcon,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                  ),
                  if (headerBadgeLeft != null)
                    Positioned(top: 8, left: 8, child: headerBadgeLeft!),
                  if (headerBadgeRight != null)
                    Positioned(top: 8, right: 8, child: headerBadgeRight!),
                  if (trailingBadge != null)
                    Positioned(bottom: 8, right: 8, child: trailingBadge!),
                ],
              ),
            ),
            // ─── Corpo (altura fixa pra posições consistentes) ────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, actionFooter != null ? 4 : 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome com altura RESERVADA de 2 linhas (mesmo se 1 linha)
                    SizedBox(
                      height: 34,
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.productName(
                          size: 14,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    if (footer != null) ...[
                      const Spacer(),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
            // ─── Action footer (stepper / botão) — colado na borda ────
            if (actionFooter != null) actionFooter!,
          ],
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 240 + animationIndex * 12),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v * (inactive ? 0.62 : 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - v)),
          child: child,
        ),
      ),
      child: card,
    );
  }
}

/// Stepper compacto +/- número para usar como [actionFooter] na Saída.
class CasaProductStepper extends StatelessWidget {
  final int qty;
  final int max;
  final Color accent;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const CasaProductStepper({
    super.key,
    required this.qty,
    required this.max,
    required this.accent,
    this.onDecrement,
    this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final canDec = qty > 0 && onDecrement != null;
    final canInc = qty < max && onIncrement != null;
    final active = qty > 0;

    return Container(
      decoration: BoxDecoration(
        color: active
            ? accent.withValues(alpha: isDark ? 0.18 : 0.08)
            : cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: accent.withValues(alpha: isDark ? 0.28 : 0.15),
            width: 1,
          ),
        ),
        // Cantos inferiores arredondados pra ficar colado na borda do card
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(18),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            enabled: canDec,
            color: accent,
            onTap: onDecrement,
          ),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Text(
                  '$qty',
                  key: ValueKey(qty),
                  style: AppTypography.productName(
                    size: 17,
                    weight: FontWeight.w900,
                    color: active ? accent : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            enabled: canInc,
            color: accent,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: enabled
          ? color.withValues(alpha: isDark ? 0.30 : 0.16)
          : color.withValues(alpha: isDark ? 0.10 : 0.05),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            icon,
            size: 18,
            color: enabled
                ? color
                : Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// Badge dark blur reutilizável (validade, status, etc).
class CasaProductBadge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color accent;
  const CasaProductBadge({
    super.key,
    this.icon,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: accent.withValues(alpha: 0.65), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: accent),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
