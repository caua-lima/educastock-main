import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Um destino da navegação lateral.
class RailDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const RailDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });
}

/// Navegação lateral usada em tablet e computador (no celular fica a barra inferior).
///
/// - Recolhida (ícone + nome curto) entre 720 e 1199 px.
/// - Expandida (ícone + nome ao lado) a partir de 1200 px.
/// - A lista rola se a janela for baixa, então nunca estoura na vertical.
class AdaptiveSideRail extends StatelessWidget {
  final List<RailDestination> primary;
  final List<RailDestination> secondary;
  final bool extended;
  final String subtitle;
  final VoidCallback? onSearch;

  const AdaptiveSideRail({
    super.key,
    required this.primary,
    this.secondary = const [],
    required this.extended,
    required this.subtitle,
    this.onSearch,
  });

  static const double collapsedWidth = 88;
  static const double extendedWidth = 236;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: extended ? extendedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5), width: 0.8),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            _RailHeader(extended: extended, subtitle: subtitle),
            if (onSearch != null)
              Padding(
                padding: EdgeInsets.fromLTRB(extended ? 14 : 12, 4, extended ? 14 : 12, 8),
                child: _SearchButton(extended: extended, onTap: onSearch!),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                children: [
                  for (final d in primary) _RailItem(dest: d, extended: extended),
                  if (secondary.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      child: Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
                    ),
                    for (final d in secondary) _RailItem(dest: d, extended: extended),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailHeader extends StatelessWidget {
  final bool extended;
  final String subtitle;
  const _RailHeader({required this.extended, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/images/logo.png', width: 40, height: 40, fit: BoxFit.cover),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      child: extended
          ? Row(
              children: [
                logo,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'EducaStock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.productName(size: 16, color: cs.onSurface),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(child: Tooltip(message: 'EducaStock · $subtitle', child: logo)),
    );
  }
}

class _SearchButton extends StatelessWidget {
  final bool extended;
  final VoidCallback onTap;
  const _SearchButton({required this.extended, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!extended) {
      return Tooltip(
        message: 'Buscar (Ctrl+K)',
        child: IconButton.filledTonal(
          onPressed: onTap,
          icon: const Icon(Icons.search_rounded),
        ),
      );
    }
    return Semantics(
      button: true,
      label: 'Buscar produtos e telas',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Buscar…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text('Ctrl K',
                    style: AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final RailDestination dest;
  final bool extended;
  const _RailItem({required this.dest, required this.extended});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = dest.selected ? dest.color : cs.onSurfaceVariant;
    final bg = dest.selected ? dest.color.withValues(alpha: isDark ? 0.22 : 0.12) : Colors.transparent;

    final icon = Badge(
      isLabelVisible: dest.badge > 0,
      label: Text(dest.badge > 99 ? '99+' : '${dest.badge}'),
      backgroundColor: AppColors.danger600,
      child: Icon(dest.selected ? dest.activeIcon : dest.icon, size: 24, color: fg),
    );

    final content = extended
        ? Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  dest.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    color: dest.selected ? dest.color : cs.onSurface,
                    fontWeight: dest.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 4),
              Text(
                dest.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: fg,
                  fontSize: 11,
                  fontWeight: dest.selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: extended ? '' : dest.label,
        child: Semantics(
          button: true,
          selected: dest.selected,
          label: dest.label,
          excludeSemantics: true,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: dest.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: extended
                    ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
                    : const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
