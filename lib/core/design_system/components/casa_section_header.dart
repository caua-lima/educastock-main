import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Cabeçalho de seção padrão do app — modernizado com:
///  - Hero bar gradient à esquerda (mais alta + arredondada)
///  - Título maior, mais peso e fonte de produto
///  - Badge de contagem pill com cor da seção
///  - Action "pill" estilizada com seta
class CasaSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final int? count;
  final IconData? icon;
  final Color? accentColor;

  const CasaSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.count,
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor ?? AppColors.brandPrimary600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          // ── Hero bar vertical com gradient
          Container(
            width: 4,
            height: 22,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, AppColors.secondaryBlue600],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 6),
          ],
          // ── Título
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.productName(
                size: 17,
                weight: FontWeight.w900,
                color: cs.onSurface,
                letterSpacing: -0.4,
              ),
            ),
          ),
          // ── Badge de contagem
          if (count != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: isDark ? 0.30 : 0.16),
                    accent.withValues(alpha: isDark ? 0.18 : 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: accent.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              child: Text(
                '$count',
                style: AppTypography.productName(
                  size: 12,
                  weight: FontWeight.w900,
                  color: accent,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
          const Spacer(),
          // ── Ação pill
          if (action != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: accent.withValues(alpha: isDark ? 0.40 : 0.20),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action!,
                        style: AppTypography.labelMedium.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
