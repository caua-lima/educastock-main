import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Item de ação para o [showCasaActionSheet] modernizado.
class CasaSheetItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
  final bool destructive;

  const CasaSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
    this.destructive = false,
  });
}

/// Mostra um bottom sheet moderno e estiloso com header colorido,
/// subtítulo e até 4 ações principais como cards.
///
/// Usa `useRootNavigator: true` para que o sheet apareça **acima da TabBar**
/// e qualquer outro elemento de shell.
///
/// Exemplo:
/// ```dart
/// showCasaActionSheet(
///   context: context,
///   title: 'Arroz',
///   subtitle: 'Vence em 5 dias',
///   headerColor: AppColors.danger600,
///   headerIcon: Icons.warning_amber_rounded,
///   actions: [
///     CasaSheetItem(icon: Icons.output_rounded, label: 'Distribuir', onTap: () {}),
///     CasaSheetItem(icon: Icons.edit_rounded, label: 'Editar', onTap: () {}),
///   ],
/// );
/// ```
Future<T?> showCasaActionSheet<T>({
  required BuildContext context,
  required String title,
  required String subtitle,
  required Color headerColor,
  required IconData headerIcon,
  required List<CasaSheetItem> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true, // <- aparece acima da TabBar
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return _CasaActionSheetContent(
        title: title,
        subtitle: subtitle,
        headerColor: headerColor,
        headerIcon: headerIcon,
        actions: actions,
      );
    },
  );
}

class _CasaActionSheetContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color headerColor;
  final IconData headerIcon;
  final List<CasaSheetItem> actions;

  const _CasaActionSheetContent({
    required this.title,
    required this.subtitle,
    required this.headerColor,
    required this.headerIcon,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.modal + 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle bar ──────────────────────────────────────────────
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Header com identidade colorida ──────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    headerColor.withValues(alpha: isDark ? 0.30 : 0.16),
                    headerColor.withValues(alpha: isDark ? 0.10 : 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.modal),
                border: Border.all(
                  color: headerColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          headerColor.withValues(alpha: 0.95),
                          headerColor.withValues(alpha: 0.55),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.small + 2),
                      boxShadow: [
                        BoxShadow(
                          color: headerColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(headerIcon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTypography.headingSmall.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.bodySmall.copyWith(
                            color: headerColor,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Ações como cards ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    _CasaActionCard(item: actions[i]),
                    if (i < actions.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _CasaActionCard extends StatelessWidget {
  final CasaSheetItem item;
  const _CasaActionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = item.destructive
        ? AppColors.danger600
        : (item.color ?? AppColors.brandPrimary600);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          // Fecha o sheet primeiro, depois executa a ação no próximo frame
          // (evita race entre pop + navigation/dialog).
          Navigator.of(context, rootNavigator: true).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) => item.onTap());
        },
        borderRadius: BorderRadius.circular(AppRadius.modal),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh.withValues(alpha: isDark ? 0.5 : 0.6),
            borderRadius: BorderRadius.circular(AppRadius.modal),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.25 : 0.18),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md - 2, AppSpacing.md, AppSpacing.md - 2),
            child: Row(
              children: [
                // Ícone com fundo colorido
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.95),
                        accent.withValues(alpha: 0.55),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.32),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                // Label + subtítulo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.label,
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          item.subtitle!,
                          style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: accent.withValues(alpha: 0.85), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
