import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/donation_status.dart';

/// Chip de status da doação (Pendente, Aprovada, Recebida…).
class DonationStatusChip extends StatelessWidget {
  final DonationStatus status;

  const DonationStatusChip({super.key, required this.status});

  Color get _color => switch (status) {
        DonationStatus.pendente => AppColors.warning600,
        DonationStatus.aprovada => AppColors.brandPrimary600,
        DonationStatus.recebida => AppColors.success600,
        DonationStatus.recebidaParcial => AppColors.success600,
        DonationStatus.recusada => AppColors.danger600,
        DonationStatus.cancelada => AppColors.neutral500,
        DonationStatus.expirada => AppColors.neutral500,
      };

  IconData get _icon => switch (status) {
        DonationStatus.pendente => Icons.hourglass_top_rounded,
        DonationStatus.aprovada => Icons.thumb_up_alt_rounded,
        DonationStatus.recebida => Icons.check_circle_rounded,
        DonationStatus.recebidaParcial => Icons.rule_rounded,
        DonationStatus.recusada => Icons.block_rounded,
        DonationStatus.cancelada => Icons.cancel_rounded,
        DonationStatus.expirada => Icons.timer_off_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status ${status.label}',
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
              status.label,
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
