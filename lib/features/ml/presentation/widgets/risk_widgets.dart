import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../data/repositories/rule_based_risk_classifier.dart';
import '../../domain/entities/risk_prediction.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _fgForLevel(RiskLevel level) {
  switch (level) {
    case RiskLevel.verde:
      return AppColors.success600;
    case RiskLevel.amarelo:
      return AppColors.warning600;
    case RiskLevel.vermelho:
      return AppColors.danger600;
  }
}

Color _bgForLevel(RiskLevel level, bool isDark) {
  final fg = _fgForLevel(level);
  return fg.withValues(alpha: isDark ? 0.18 : 0.10);
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

// ─── RiskBadge ────────────────────────────────────────────────────────────────

/// Badge compacto exibindo o nível de risco ML de um lote.
class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  final bool compact;

  const RiskBadge({super.key, required this.level, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _fgForLevel(level);
    final bg = _bgForLevel(level, isDark);

    if (compact) {
      return Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Icon(_iconForLevel(level), size: 14, color: fg),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForLevel(level), size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            level.label,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RiskInsightCard ─────────────────────────────────────────────────────────

/// Card de insight para o dashboard/página de ML.
class RiskInsightCard extends StatelessWidget {
  final RiskPrediction prediction;
  final VoidCallback? onTap;

  const RiskInsightCard({super.key, required this.prediction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final fg = _fgForLevel(prediction.level);
    final pct = (prediction.confidence * 100).clamp(0, 100).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: fg.withValues(alpha: isDark ? 0.3 : 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: fg.withValues(alpha: isDark ? 0.08 : 0.05),
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
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [fg, fg.withValues(alpha: 0.5)],
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
                color: _bgForLevel(prediction.level, isDark),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(_iconForLevel(prediction.level), color: fg, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Conteúdo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.productName,
                      style: AppTypography.labelLarge.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      prediction.level.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Barra de confiança
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: prediction.confidence.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(fg),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '$pct%',
                          style: AppTypography.labelSmall.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── RiskSummaryRow ──────────────────────────────────────────────────────────

/// Linha de resumo de contadores por nível (Verde/Amarelo/Vermelho).
class RiskSummaryRow extends StatelessWidget {
  final Map<RiskLevel, int> counts;

  const RiskSummaryRow({super.key, required this.counts});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: RiskLevel.values.asMap().entries.map((e) {
        final i = e.key;
        final level = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : AppSpacing.xs,
              right: i == RiskLevel.values.length - 1 ? 0 : AppSpacing.xs,
            ),
            child: _RiskCounter(level: level, count: counts[level] ?? 0),
          ),
        );
      }).toList(),
    );
  }
}

class _RiskCounter extends StatelessWidget {
  final RiskLevel level;
  final int count;
  const _RiskCounter({required this.level, required this.count});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _fgForLevel(level);
    final bg = _bgForLevel(level, isDark);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [fg, fg.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: fg.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$count',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            level.label,
            style: AppTypography.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── RiskPreviewBanner ──────────────────────────────────────────────────────

/// Calcula em tempo real (regras síncronas) o risco previsto para um lote em
/// criação/edição, antes de salvar. Aparece como um banner colorido com
/// recomendação acionável.
///
/// Útil para alimentar o usuário com feedback ML imediato no batch_form_page,
/// scanner review etc., sem precisar de TFLite (que requer build com batches).
class RiskPreviewBanner extends StatelessWidget {
  final DateTime? expiryDate;
  final bool noExpiry;
  final int quantity;
  final DateTime entryDate;

  const RiskPreviewBanner({
    super.key,
    required this.expiryDate,
    required this.noExpiry,
    required this.quantity,
    required this.entryDate,
  });

  RiskPrediction get _prediction {
    final fake = Batch(
      id: '_preview',
      productId: '_preview',
      productName: '',
      quantity: quantity < 1 ? 1 : quantity,
      initialQuantity: quantity < 1 ? 1 : quantity,
      expiryDate: noExpiry ? null : expiryDate,
      noExpiry: noExpiry,
      entryDate: entryDate,
      origin: 'doacao',
      createdBy: '_preview',
      createdAt: entryDate,
    );
    return RuleBasedRiskClassifier().classifySync(fake);
  }

  String _recommendation(RiskLevel level, bool noExpiry) {
    if (noExpiry) return 'Sem validade — risco baixo de perda.';
    switch (level) {
      case RiskLevel.verde:
        return 'Lote em condição ideal. Distribua normalmente.';
      case RiskLevel.amarelo:
        return 'Vencimento próximo. Acompanhe para evitar perda.';
      case RiskLevel.vermelho:
        return 'Risco alto. Priorize distribuição rápida.';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Quando não há data e não está marcado "sem validade", não exibe preview.
    if (!noExpiry && expiryDate == null) return const SizedBox.shrink();

    final p = _prediction;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _fgForLevel(p.level);
    final bg = _bgForLevel(p.level, isDark);
    final pct = (p.confidence * 100).toInt();

    // Posiciona o indicador na barra de risco contínua: 0..1
    // verde = ~0.18, amarelo = ~0.55, vermelho = ~0.85 (do nível + confiança).
    final basePos = switch (p.level) {
      RiskLevel.verde => 0.18,
      RiskLevel.amarelo => 0.55,
      RiskLevel.vermelho => 0.85,
    };
    final progress = basePos.clamp(0.0, 1.0);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: Container(
        key: ValueKey(p.level),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: fg.withValues(alpha: 0.40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [fg, Color.lerp(fg, Colors.black, 0.18)!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: fg.withValues(alpha: 0.45),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(_iconForLevel(p.level),
                      color: Colors.white, size: 19),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Risco previsto: ${p.level.label}',
                            style: AppTypography.productName(
                              size: 14,
                              weight: FontWeight.w900,
                              color: fg,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: fg.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '$pct%',
                              style: AppTypography.labelSmall.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _recommendation(p.level, noExpiry),
                        style: AppTypography.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: 0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // ── Barra de progresso de risco ─────────────────────────────
            _RiskProgressBar(progress: progress),
          ],
        ),
      ),
    );
  }
}

class _RiskProgressBar extends StatelessWidget {
  final double progress;
  const _RiskProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppColors.success600,
                AppColors.warning600,
                AppColors.danger600,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        // Marcador (ponteiro) na posição do risco
        Positioned(
          left: (progress * 100).clamp(0, 100) * 0.01 *
              (MediaQuery.of(context).size.width - 80),
          top: -3,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (_, v, __) => Transform.scale(
              scale: v,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
