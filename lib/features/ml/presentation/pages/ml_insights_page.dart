import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../controllers/risk_classifier_provider.dart';
import '../../domain/entities/risk_prediction.dart';

final _keyCriticalSection = GlobalKey();
final _keyRiskChart = GlobalKey();

enum _RiskFilter { todos, vermelho, amarelo, verde }

class MlInsightsPage extends ConsumerStatefulWidget {
  const MlInsightsPage({super.key});

  @override
  ConsumerState<MlInsightsPage> createState() => _MlInsightsPageState();
}

class _MlInsightsPageState extends ConsumerState<MlInsightsPage> {
  _RiskFilter _filter = _RiskFilter.todos;

  @override
  Widget build(BuildContext context) {
    final predictionsAsync = ref.watch(batchRiskPredictionsProvider);
    final countsAsync = ref.watch(riskCountsProvider);
    final allBatches =
        ref.watch(allAvailableBatchesProvider).valueOrNull ?? const [];
    final batchesMap = <String, Batch>{for (final b in allBatches) b.id: b};

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
        ModernProfileAppBar(
          title: 'Análise de Risco',
          subtitle: 'Classificação ML de lotes',
          pageIcon: Icons.psychology_rounded,
          iconColor: const Color(0xFFEC4899),
          showBackButton: true,
          actions: [
            buildHelpButton(
              context: context,
              onPressed: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyRiskChart,
                    title: 'Distribuição por Risco',
                    description:
                        'O donut mostra a proporção de lotes em cada nível. Use os chips para filtrar os cards abaixo.',
                    icon: Icons.donut_large_rounded,
                    align: ContentAlign.bottom,
                  ),
                  TutorialStep(
                    key: _keyCriticalSection,
                    title: 'Cards de Lote com Ações',
                    description:
                        'Cada card mostra o lote, produto, quantidade e probabilidade de desperdício. Toque em "Saída" para registrar saída ou no "…" para mais opções.',
                    icon: Icons.psychology_rounded,
                    align: ContentAlign.top,
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(batchRiskPredictionsProvider);
              await Future.delayed(const Duration(milliseconds: 400));
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                // ─── Donut chart ───────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: KeyedSubtree(
                    key: _keyRiskChart,
                    child: countsAsync.when(
                      data: (counts) => _RiskDonutCard(counts: counts),
                      loading: () => const _DonutSkeleton(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ─── Filtros (chips) ───────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: countsAsync.maybeWhen(
                    data: (counts) => _FilterChipsBar(
                      current: _filter,
                      counts: counts,
                      onChanged: (f) => setState(() => _filter = f),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // ─── Grid de lotes ─────────────────────────────────────────
                KeyedSubtree(
                  key: _keyCriticalSection,
                  child: CasaSectionHeader(
                    title: _filter == _RiskFilter.todos
                        ? 'Lotes classificados'
                        : 'Lotes — ${_filter.label}',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Builder(
                  builder: (_) => predictionsAsync.when(
                    data: (all) {
                      final filtered = _applyFilter(all);
                      if (filtered.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg),
                          child: CasaEmptyState(
                            icon: _filter == _RiskFilter.todos
                                ? Icons.inventory_2_outlined
                                : Icons.check_circle_outline_rounded,
                            title: _filter == _RiskFilter.todos
                                ? 'Nenhum lote disponível'
                                : 'Nenhum lote em "${_filter.label}"',
                          ),
                        );
                      }
                      final sorted = [...filtered]..sort(_sortByRisk);
                      return _RiskCardGrid(
                        predictions: sorted,
                        batchesMap: batchesMap,
                      );
                    },
                    loading: () => const _GridSkeleton(),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      child: Text('Erro: $e', style: AppTypography.bodySmall),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  List<RiskPrediction> _applyFilter(List<RiskPrediction> all) {
    return switch (_filter) {
      _RiskFilter.todos => all,
      _RiskFilter.vermelho =>
        all.where((p) => p.level == RiskLevel.vermelho).toList(),
      _RiskFilter.amarelo =>
        all.where((p) => p.level == RiskLevel.amarelo).toList(),
      _RiskFilter.verde =>
        all.where((p) => p.level == RiskLevel.verde).toList(),
    };
  }

  int _sortByRisk(RiskPrediction a, RiskPrediction b) {
    const order = {
      RiskLevel.vermelho: 0,
      RiskLevel.amarelo: 1,
      RiskLevel.verde: 2,
    };
    final cmp = order[a.level]!.compareTo(order[b.level]!);
    if (cmp != 0) return cmp;
    return b.confidence.compareTo(a.confidence);
  }
}

extension on _RiskFilter {
  String get label => switch (this) {
        _RiskFilter.todos => 'Todos',
        _RiskFilter.vermelho => 'Crítico',
        _RiskFilter.amarelo => 'Atenção',
        _RiskFilter.verde => 'Seguro',
      };
}

// ---------------------------------------------------------------------------
// Donut card (igual ao dashboard, mas em tela cheia)
// ---------------------------------------------------------------------------

class _RiskDonutCard extends StatelessWidget {
  final Map<RiskLevel, int> counts;
  const _RiskDonutCard({required this.counts});

  Color _colorFor(RiskLevel level) {
    switch (level) {
      case RiskLevel.verde:
        return AppColors.success600;
      case RiskLevel.amarelo:
        return AppColors.warning600;
      case RiskLevel.vermelho:
        return AppColors.danger600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = counts.values.fold<int>(0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary600
                .withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: total == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded,
                            color: cs.onSurfaceVariant, size: 32),
                        const SizedBox(height: 4),
                        Text('Sem dados',
                            style: AppTypography.bodySmall
                                .copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 36,
                          startDegreeOffset: -90,
                          sections: RiskLevel.values.map((level) {
                            final value = (counts[level] ?? 0).toDouble();
                            final color = _colorFor(level);
                            return PieChartSectionData(
                              color: color,
                              value: value <= 0 ? 0.0001 : value,
                              title: '',
                              radius: 20,
                            );
                          }).toList(),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$total',
                            style: AppTypography.headingLarge.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                          Text(
                            'lotes',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: RiskLevel.values.map((level) {
                final count = counts[level] ?? 0;
                final pct = total == 0 ? 0.0 : count / total;
                final color = _colorFor(level);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    level.label,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$count',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${(pct * 100).toStringAsFixed(0)}%)',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 4,
                                backgroundColor: color.withValues(
                                    alpha: isDark ? 0.15 : 0.10),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutSkeleton extends StatelessWidget {
  const _DonutSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 152,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips
// ---------------------------------------------------------------------------

class _FilterChipsBar extends StatelessWidget {
  final _RiskFilter current;
  final Map<RiskLevel, int> counts;
  final ValueChanged<_RiskFilter> onChanged;

  const _FilterChipsBar({
    required this.current,
    required this.counts,
    required this.onChanged,
  });

  Color _colorFor(_RiskFilter f) {
    switch (f) {
      case _RiskFilter.todos:
        return AppColors.brandPrimary600;
      case _RiskFilter.vermelho:
        return AppColors.danger600;
      case _RiskFilter.amarelo:
        return AppColors.warning600;
      case _RiskFilter.verde:
        return AppColors.success600;
    }
  }

  int _countFor(_RiskFilter f) {
    switch (f) {
      case _RiskFilter.todos:
        return counts.values.fold(0, (s, v) => s + v);
      case _RiskFilter.vermelho:
        return counts[RiskLevel.vermelho] ?? 0;
      case _RiskFilter.amarelo:
        return counts[RiskLevel.amarelo] ?? 0;
      case _RiskFilter.verde:
        return counts[RiskLevel.verde] ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _RiskFilter.values.map((f) {
          final selected = f == current;
          final color = _colorFor(f);
          final count = _countFor(f);
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: GestureDetector(
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? color
                      : color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: color.withValues(alpha: selected ? 1 : 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.label,
                      style: AppTypography.labelMedium.copyWith(
                        color: selected ? Colors.white : color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.25)
                            : color.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$count',
                        style: AppTypography.labelSmall.copyWith(
                          color: selected ? Colors.white : color,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid de cards
// ---------------------------------------------------------------------------

class _RiskCardGrid extends StatelessWidget {
  final List<RiskPrediction> predictions;
  final Map<String, Batch> batchesMap;

  const _RiskCardGrid({
    required this.predictions,
    required this.batchesMap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth >= 900
            ? 5
            : constraints.maxWidth >= 620
                ? 4
                : 3;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              childAspectRatio: 0.78,
            ),
            itemCount: predictions.length,
            itemBuilder: (_, i) {
              final p = predictions[i];
              return _RiskGridCard(
                prediction: p,
                batch: batchesMap[p.batchId],
                index: i,
              );
            },
          ),
        );
      },
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 0.78,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => const CasaCardSkeleton(),
      ),
    );
  }
}

// ─── Card individual ────────────────────────────────────────────────────────

class _RiskGridCard extends StatelessWidget {
  final RiskPrediction prediction;
  final Batch? batch;
  final int index;

  const _RiskGridCard({
    required this.prediction,
    required this.batch,
    required this.index,
  });

  static const _paletteRed = [Color(0xFFDC2626), Color(0xFFB91C1C)];
  static const _paletteYellow = [Color(0xFFD97706), Color(0xFFB45309)];
  static const _paletteGreen = [Color(0xFF059669), Color(0xFF047857)];

  List<Color> _paletteForLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.verde:
        return _paletteGreen;
      case RiskLevel.amarelo:
        return _paletteYellow;
      case RiskLevel.vermelho:
        return _paletteRed;
    }
  }

  IconData _iconForLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.verde:
        return Icons.check_circle_rounded;
      case RiskLevel.amarelo:
        return Icons.schedule_rounded;
      case RiskLevel.vermelho:
        return Icons.warning_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final palette = _paletteForLevel(prediction.level);
    final accent = palette[0];
    final accentDark = palette[1];
    final pct = (prediction.confidence * 100).clamp(0, 100).toInt();
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;

    final dateFmt = DateFormat('dd/MM');
    final b = batch;
    final qty = b?.quantity ?? 0;
    final dExp = b == null
        ? null
        : (b.noExpiry ? null : b.daysToExpiry);
    final expDate = b?.expiryDate;
    final expLabel = b == null
        ? '—'
        : b.noExpiry
            ? '∞'
            : (expDate != null
                ? '${dateFmt.format(expDate)} · ${dExp}d'
                : 'sem data');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + index * 10),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
      ),
      child: GestureDetector(
        onTap: () => _openProduct(context),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.35 : 0.20),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.20 : 0.10),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header compacto ─────────────────────────────────────
              Stack(
                children: [
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accentDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(13)),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Center(
                          child: Icon(
                            _iconForLevel(prediction.level),
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badge confiança canto direito
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '$pct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Corpo compacto ──────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        prediction.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMedium.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          height: 1.1,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.inventory_2_rounded,
                                  size: 9, color: cs.onSurfaceVariant),
                              const SizedBox(width: 2),
                              Text(
                                '$qty',
                                style: AppTypography.labelSmall.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.event_rounded, size: 9, color: accent),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  expLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _MiniActionButton(
                                  icon: Icons.outbound_rounded,
                                  label: 'Saída',
                                  color: accent,
                                  onTap: () => _openMovement(context),
                                ),
                              ),
                              const SizedBox(width: 3),
                              _MiniIconButton(
                                icon: Icons.more_horiz_rounded,
                                color: cs.onSurfaceVariant,
                                onTap: () => _openActionsSheet(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProduct(BuildContext context) {
    final b = batch;
    if (b == null) return;
    context.push('/products/${b.productId}');
  }

  void _openMovement(BuildContext context, {String? reason}) {
    final b = batch;
    if (b == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lote não encontrado no estoque atual'),
            duration: Duration(seconds: 2)),
      );
      return;
    }
    final reasonParam = reason != null ? '&reason=$reason' : '';
    context.push(
      '${AppRoutes.movement}?batchId=${b.id}&productId=${b.productId}$reasonParam',
    );
  }

  void _openActionsSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Text(
              prediction.productName,
              style: AppTypography.labelLarge.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nível ${prediction.level.label} • '
              '${(prediction.confidence * 100).toStringAsFixed(0)}% confiança',
              style: AppTypography.bodySmall
                  .copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            _ActionTile(
              icon: Icons.outbound_rounded,
              label: 'Registrar saída',
              color: AppColors.brandPrimary600,
              onTap: () {
                Navigator.pop(context);
                _openMovement(context);
              },
            ),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Registrar descarte',
              color: AppColors.danger600,
              onTap: () {
                Navigator.pop(context);
                _openMovement(context, reason: 'validade');
              },
            ),
            _ActionTile(
              icon: Icons.info_outline_rounded,
              label: 'Ver detalhes do produto',
              color: AppColors.secondaryBlue600,
              onTap: () {
                Navigator.pop(context);
                _openProduct(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.small),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 10),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.small),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: 12),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

