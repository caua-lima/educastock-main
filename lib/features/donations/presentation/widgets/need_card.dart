import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/donation_need.dart';
import 'need_priority_chip.dart';

/// Cartão de uma necessidade da ONG. Usado na Home (D03, compacto) e no
/// catálogo (D04, com barra de progresso e botão "Doar").
class NeedCard extends StatelessWidget {
  final DonationNeed need;
  final VoidCallback? onTap;

  /// Quando informado, exibe o botão "Doar" no cartão (catálogo).
  final VoidCallback? onDonate;
  final bool showProgress;

  const NeedCard({
    super.key,
    required this.need,
    this.onTap,
    this.onDonate,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shelfLife = need.minShelfLifeDays > 0
        ? ' · validade mín. ${need.minShelfLifeDays} d'
        : '';

    return Semantics(
      container: true,
      label: '${need.title}, prioridade ${need.priority.label}, '
          'restam ${need.remainingQty} ${need.unit} a cobrir',
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        need.title,
                        style: AppTypography.productName(
                          size: 16,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    NeedPriorityChip(priority: need.priority),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Restam ${need.remainingQty} ${need.unit} a cobrir$shelfLife',
                  style: AppTypography.bodyMedium
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                if (showProgress) ...[
                  const SizedBox(height: AppSpacing.md),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: need.pledgedProgress,
                      minHeight: 6,
                      color: AppColors.success600,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${need.pledgedQty} de ${need.suggestedQty} ${need.unit} já prometidas',
                    style: AppTypography.labelSmall
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (onDonate != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  CasaButton(
                    label: 'Doar',
                    height: 44,
                    variant: CasaButtonVariant.secondary,
                    icon: Icons.volunteer_activism_rounded,
                    onPressed: onDonate,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
