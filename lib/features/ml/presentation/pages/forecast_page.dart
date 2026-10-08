import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../controllers/consumption_forecast_provider.dart';
import '../widgets/forecast_widgets.dart';
import '../../domain/entities/consumption_forecast.dart';

final _keyForecastList = GlobalKey();
final _keyForecastInfo = GlobalKey();
final _keyForecastKpi = GlobalKey();
final _keyForecastFilter = GlobalKey();

class ForecastPage extends ConsumerStatefulWidget {
  const ForecastPage({super.key});

  @override
  ConsumerState<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends ConsumerState<ForecastPage> {
  _FilterMode _filter = _FilterMode.all;

  @override
  Widget build(BuildContext context) {
    final forecastsAsync = ref.watch(liveForecastsProvider);
    final replenishmentCount = ref.watch(replenishmentCountProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Previsão de Consumo',
        subtitle: 'Modelo Prophet de IA',
        pageIcon: Icons.trending_up_rounded,
        iconColor: const Color(0xFF22C55E),
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyForecastInfo,
                  title: 'Modelo Prophet (Meta)',
                  description: 'Este banner explica como as previsões são geradas: o algoritmo Prophet (da Meta/Facebook) analisa o histórico real de saídas, detecta tendências, sazonalidade e eventos especiais (datas comemorativas) e projeta o consumo futuro de cada produto.',
                  icon: Icons.psychology_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🤖 IA estatística rodando em Google Colab',
                    'Precisa de pelo menos 30 dias de histórico',
                    'Re-execute mensalmente ou após eventos atípicos',
                    'Mais histórico = previsões mais precisas',
                  ],
                ),
                TutorialStep(
                  key: _keyForecastKpi,
                  title: 'Indicadores Rápidos',
                  description: 'Os cards KPI no topo resumem o estado geral da previsão: total de produtos analisados, quantos precisam reposição urgente, consumo médio diário e tendência geral do estoque. Use para decisões rápidas de compra.',
                  icon: Icons.analytics_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Cards são interativos — toque para filtrar a lista',
                    'Indicadores atualizam em tempo real',
                    'Verde = situação controlada | Vermelho = ação imediata',
                    'Use estes números na reunião de compras',
                  ],
                ),
                TutorialStep(
                  key: _keyForecastFilter,
                  title: 'Filtros Inteligentes',
                  description: 'Os chips de filtro permitem focar em diferentes recortes: "Todos", "Precisam Reposição" (urgência), "Crítico" (menos de 7 dias) ou "Crescendo" (consumo subindo). Combine com outros para encontrar produtos específicos.',
                  icon: Icons.filter_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Filtro padrão: "Todos" mostra a lista completa',
                    '"Crescendo": produtos com tendência de alta',
                    'Use "Crítico" antes de compras emergenciais',
                    'O contador no header acompanha o filtro',
                  ],
                ),
                TutorialStep(
                  key: _keyForecastList,
                  title: 'Sugestões de Reposição',
                  description: 'Lista ordenada por urgência. Cada card mostra: produto, dias restantes de estoque, consumo médio, tendência (↑↓), quantidade sugerida para comprar (já com margem de 20%). O sistema sugere quantidade ideal para 30 dias.',
                  icon: Icons.add_shopping_cart_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    '🔴 Crítico: menos de 7 dias — comprar HOJE',
                    '🟡 Baixo: menos de 14 dias — compra programada',
                    '↗️ Tendência crescente: aumente a quantidade',
                    'Quantidade sugerida = consumo 30d × 1.2 - estoque atual',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: forecastsAsync.when(
          loading: () => _LoadingState(),
          error: (e, _) => _ErrorState(error: e.toString()),
          data: (forecasts) {
            if (forecasts.isEmpty) return const ForecastEmptyState();
            final filtered = _applyFilter(forecasts);
            return _ForecastBody(
              allForecasts: forecasts,
              filtered: filtered,
              replenishmentCount: replenishmentCount,
              filter: _filter,
              onFilterChanged: (f) => setState(() => _filter = f),
              forecastListKey: _keyForecastList,
              forecastInfoKey: _keyForecastInfo,
              forecastKpiKey: _keyForecastKpi,
              forecastFilterKey: _keyForecastFilter,
            );
          },
        ),
      ),
      ]),
    );
  }

  List<ConsumptionForecast> _applyFilter(List<ConsumptionForecast> all) {
    return switch (_filter) {
      _FilterMode.replenishment => all.where((f) => f.needsReplenishment).toList(),
      _FilterMode.critical => all.where((f) => f.isCriticalStock).toList(),
      _FilterMode.increasing =>
        all.where((f) => f.trend == 'increasing').toList(),
      _ => all,
    };
  }
}

// ---------------------------------------------------------------------------
// Body principal
// ---------------------------------------------------------------------------

class _ForecastBody extends StatelessWidget {
  final List<ConsumptionForecast> allForecasts;
  final List<ConsumptionForecast> filtered;
  final int replenishmentCount;
  final _FilterMode filter;
  final ValueChanged<_FilterMode> onFilterChanged;
  final GlobalKey forecastListKey;
  final GlobalKey forecastInfoKey;
  final GlobalKey forecastKpiKey;
  final GlobalKey forecastFilterKey;

  const _ForecastBody({
    required this.allForecasts,
    required this.filtered,
    required this.replenishmentCount,
    required this.filter,
    required this.onFilterChanged,
    required this.forecastListKey,
    required this.forecastInfoKey,
    required this.forecastKpiKey,
    required this.forecastFilterKey,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: [
        // ─── Banner de info do modelo ───────────────────────────────────
        KeyedSubtree(
          key: forecastInfoKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: _ModelInfoBanner(isDark: isDark),
          ),
        ),

        // ─── KPIs rápidos ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: KeyedSubtree(
            key: forecastKpiKey,
            child: _ForecastKpiRow(forecasts: allForecasts),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ─── Filtros ────────────────────────────────────────────────────
        Padding(
          key: forecastFilterKey,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _FilterMode.values
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChip(
                        label: Text(f.label),
                        selected: filter == f,
                        onSelected: (_) => onFilterChanged(f),
                        selectedColor:
                            AppColors.brandPrimary600.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.brandPrimary600,
                        labelStyle: AppTypography.labelSmall.copyWith(
                          color: filter == f
                              ? AppColors.brandPrimary600
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ─── Lista de produtos ──────────────────────────────────────────
        CasaSectionHeader(
          title: filter.label,
          count: filtered.length,
        ),
        const SizedBox(height: AppSpacing.sm),

        if (filtered.isEmpty)
          const CasaEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Nenhum produto neste filtro',
          )
        else
          KeyedSubtree(
            key: forecastListKey,
            child: Column(
              children: filtered
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                      child: ForecastDetailCard(forecast: f),
                    ),
                  )
                  .toList(),
            ),
          ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Banner informativo sobre o modelo
// ---------------------------------------------------------------------------

class _ModelInfoBanner extends StatelessWidget {
  final bool isDark;
  const _ModelInfoBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary600.withValues(alpha: 0.12),
            AppColors.secondaryBlue600.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.brandPrimary600.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_rounded,
              color: AppColors.brandPrimary600, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modelo Prophet (Meta) via Google Colab',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.brandPrimary600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Previsões baseadas no histórico real de saídas do estoque.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success600.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'Fase 2 ML',
              style: AppTypography.labelSmall.copyWith(
                  color: AppColors.success600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPIs rápidos
// ---------------------------------------------------------------------------

class _ForecastKpiRow extends StatelessWidget {
  final List<ConsumptionForecast> forecasts;
  const _ForecastKpiRow({required this.forecasts});

  @override
  Widget build(BuildContext context) {
    final needRepl = forecasts.where((f) => f.needsReplenishment).length;
    final critical = forecasts.where((f) => f.isCriticalStock).length;
    final totalMonthly =
        forecasts.fold<double>(0, (s, f) => s + f.forecastMonthly);

    return Row(
      children: [
        _KpiTile(
          icon: Icons.add_shopping_cart_rounded,
          value: '$needRepl',
          label: 'Precisam repor',
          color: AppColors.warning600,
        ),
        const SizedBox(width: AppSpacing.sm),
        _KpiTile(
          icon: Icons.priority_high_rounded,
          value: '$critical',
          label: 'Críticos',
          color: AppColors.danger600,
        ),
        const SizedBox(width: AppSpacing.sm),
        _KpiTile(
          icon: Icons.trending_up_rounded,
          value: totalMonthly.toStringAsFixed(0),
          label: 'Un./mês previsto',
          color: AppColors.brandPrimary600,
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _KpiTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
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
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.labelLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            Text(
              label,
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
}

// ---------------------------------------------------------------------------
// Estados auxiliares
// ---------------------------------------------------------------------------

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: List.generate(
        5,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: CasaCardSkeleton(),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'Erro ao carregar previsões: $error',
          style: AppTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Enum de filtros
// ---------------------------------------------------------------------------

enum _FilterMode {
  all('Todos'),
  replenishment('Precisa repor'),
  critical('Críticos'),
  increasing('Crescendo');

  final String label;
  const _FilterMode(this.label);
}
