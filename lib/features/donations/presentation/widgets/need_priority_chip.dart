import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/donation_need.dart';

/// Chip semântico da prioridade da necessidade (Crítica, Alta, Normal).
/// Mesma estrutura visual do `CasaStatusChip`: pílula, ícone de 12px, `labelSmall`.
class NeedPriorityChip extends StatelessWidget {
  final NeedPriority priority;

  const NeedPriorityChip({super.key, required this.priority});

  Color get _color => switch (priority) {
        NeedPriority.critica => AppColors.danger600,
        NeedPriority.alta => AppColors.warning600,
        NeedPriority.normal => AppColors.success600,
      };

  IconData get _icon => switch (priority) {
        NeedPriority.critica => Icons.warning_rounded,
        NeedPriority.alta => Icons.schedule_rounded,
        NeedPriority.normal => Icons.check_circle_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Prioridade ${priority.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 12, color: _color),
            const SizedBox(width: 4),
            Text(
              priority.label.toUpperCase(),
              style: AppTypography.labelSmall.copyWith(
                color: _color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
