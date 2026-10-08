import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/consumption_forecast.dart';

// ─── TrendChip ────────────────────────────────────────────────────────────────

/// Chip de tendência de consumo (crescente / estável / decrescente).
class TrendChip extends StatelessWidget {
  final String trend;
  final double trendPercent;

  const TrendChip({
    super.key,
    required this.trend,
    required this.trendPercent,
  });

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (trend) {
      'increasing' => (
          '+${trendPercent.abs().toStringAsFixed(0)}%',
          Icons.trending_up_rounded,
          AppColors.danger600,
        ),
      'decreasing' => (
          '-${trendPercent.abs().toStringAsFixed(0)}%',
          Icons.trending_down_rounded,
          AppColors.success600,
        ),
      _ => ('Estável', Icons.trending_flat_rounded, AppColors.neutral500),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SourceBadge ─────────────────────────────────────────────────────────────

/// Badge mostrando a fonte do modelo (Prophet ou Média Móvel).
class SourceBadge extends StatelessWidget {
  final ConsumptionForecast forecast;

  const SourceBadge({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final isProphet = forecast.isProphet;
    final label = isProphet ? 'Prophet' : 'Média Móvel';
    final icon = isProphet ? Icons.psychology_rounded : Icons.bar_chart_rounded;
    final color = isProphet
        ? AppColors.brandPrimary600
        : AppColors.neutral500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ForecastSuggestionCard ───────────────────────────────────────────────────

/// Card compacto para o dashboard mostrando sugestão de reposição.
class ForecastSuggestionCard extends StatelessWidget {
  final ConsumptionForecast forecast;
  final VoidCallback? onTap;

  const ForecastSuggestionCard({
    super.key,
    required this.forecast,
    this.onTap,
  });

  Color _urgencyColor() {
    if (forecast.isCriticalStock) return AppColors.danger600;
    if (forecast.isLowStock) return AppColors.warning600;
    return AppColors.brandPrimary600;
  }

  IconData _urgencyIcon() {
    if (forecast.isCriticalStock) return Icons.priority_high_rounded;
    if (forecast.isLowStock) return Icons.warning_amber_rounded;
    return Icons.add_shopping_cart_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _urgencyColor();
    final daysLeft = forecast.daysOfStockRemaining.clamp(0, 999).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.07 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Barra colorida lateral
            Container(
              width: 4,
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.card),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Ícone
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(_urgencyIcon(), color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Conteúdo principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            forecast.productName,
                            style: AppTypography.productName(
                              size: 15,
                              weight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        TrendChip(
                          trend: forecast.trend,
                          trendPercent: forecast.trendPercent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      daysLeft < 999
                          ? 'Estoque p/ ~$daysLeft dias  •  Repor ${forecast.suggestedReplenishment} un.'
                          : 'Repor ${forecast.suggestedReplenishment} un.  •  Sem histórico',
                      style: AppTypography.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: _ForecastBar(
                            color: color,
                            forecastMonthly: forecast.forecastMonthly,
                            currentStock: forecast.currentStock,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SourceBadge(forecast: forecast),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _ForecastBar extends StatelessWidget {
  final Color color;
  final double forecastMonthly;
  final int currentStock;

  const _ForecastBar({
    required this.color,
    required this.forecastMonthly,
    required this.currentStock,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Target = consumo previsto × 1.2 (mesmo cálculo de suggestedReplenishment)
    final target = (forecastMonthly * 1.2).round();
    final ratio = target > 0
        ? (currentStock / target).clamp(0.0, 1.0)
        : 0.0;
    final pct = (ratio * 100).round();

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$pct% de $target',
          style: AppTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

// ─── ForecastDetailCard ───────────────────────────────────────────────────────

/// Card expandido para a página de previsão de consumo.
class ForecastDetailCard extends StatelessWidget {
  final ConsumptionForecast forecast;
  final VoidCallback? onTap;

  const ForecastDetailCard({
    super.key,
    required this.forecast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCi = forecast.ciLower != null && forecast.ciUpper != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: nome + badges
            Row(
              children: [
                Expanded(
                  child: Text(
                    forecast.productName,
                    style: AppTypography.labelLarge.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TrendChip(
                    trend: forecast.trend, trendPercent: forecast.trendPercent),
                const SizedBox(width: 4),
                SourceBadge(forecast: forecast),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Métricas em grid
            Row(
              children: [
                _MetricCell(
                  label: 'Próx. 7 dias',
                  value: forecast.forecastWeekly.toStringAsFixed(1),
                  unit: 'un.',
                  color: AppColors.brandPrimary600,
                  sub: hasCi
                      ? '${forecast.ciLower!.toStringAsFixed(0)}–${forecast.ciUpper!.toStringAsFixed(0)}'
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                _MetricCell(
                  label: 'Próx. 30 dias',
                  value: forecast.forecastMonthly.toStringAsFixed(1),
                  unit: 'un.',
                  color: AppColors.secondaryBlue600,
                ),
                const SizedBox(width: AppSpacing.sm),
                _MetricCell(
                  label: 'Estoque atual',
                  value: '${forecast.currentStock}',
                  unit: 'un.',
                  color: forecast.isCriticalStock
                      ? AppColors.danger600
                      : forecast.isLowStock
                          ? AppColors.warning600
                          : AppColors.success600,
                ),
              ],
            ),

            if (forecast.needsReplenishment) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning600.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                      color: AppColors.warning600.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_shopping_cart_rounded,
                        size: 16, color: AppColors.warning600),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Sugestão de reposição: ${forecast.suggestedReplenishment} un.',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.warning600,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xs),
            Text(
              '${forecast.dataPoints} registros de saída • Atualizado ${_relativeDate(forecast.generatedAt)}',
              style: AppTypography.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'agora há pouco';
    if (diff.inHours < 24) return 'hoje';
    if (diff.inDays == 1) return 'ontem';
    return 'há ${diff.inDays} dias';
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final String? sub;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.07),
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: AppTypography.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: AppTypography.bodySmall.copyWith(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            if (sub != null)
              Text(
                'IC: $sub',
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── ForecastEmptyState ───────────────────────────────────────────────────────

/// Estado vazio quando não há previsões disponíveis.
class ForecastEmptyState extends StatelessWidget {
  const ForecastEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.neutral500.withValues(alpha: 0.2), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(
            Icons.science_rounded,
            size: 40,
            color: AppColors.neutral500.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Previsão ainda não gerada',
            style: AppTypography.labelLarge
                .copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Execute o notebook Prophet no Google Colab para gerar as previsões de consumo. Os dados serão exibidos aqui automaticamente.',
            style: AppTypography.bodySmall
                .copyWith(color: cs.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
