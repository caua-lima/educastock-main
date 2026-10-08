import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

enum StockStatus { critico, atencao, ok, vencido, semValidade }

class CasaStatusChip extends StatelessWidget {
  final StockStatus status;
  final String? customLabel;

  const CasaStatusChip({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _fgColor),
          const SizedBox(width: 4),
          Text(
            customLabel ?? _label,
            style: AppTypography.labelSmall.copyWith(
              color: _fgColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String get _label => switch (status) {
        StockStatus.critico => 'Crítico',
        StockStatus.atencao => 'Atenção',
        StockStatus.ok => 'OK',
        StockStatus.vencido => 'Vencido',
        StockStatus.semValidade => 'Sem Validade',
      };

  Color get _bgColor => switch (status) {
        StockStatus.critico => AppColors.danger600.withValues(alpha: 0.12),
        StockStatus.atencao => AppColors.warning600.withValues(alpha: 0.12),
        StockStatus.ok => AppColors.success600.withValues(alpha: 0.12),
        StockStatus.vencido => AppColors.neutral500.withValues(alpha: 0.12),
        StockStatus.semValidade => AppColors.neutral700.withValues(alpha: 0.10),
      };

  Color get _fgColor => switch (status) {
        StockStatus.critico => AppColors.danger600,
        StockStatus.atencao => AppColors.warning600,
        StockStatus.ok => AppColors.success600,
        StockStatus.vencido => AppColors.neutral500,
        StockStatus.semValidade => AppColors.neutral700,
      };

  IconData get _icon => switch (status) {
        StockStatus.critico => Icons.warning_rounded,
        StockStatus.atencao => Icons.schedule_rounded,
        StockStatus.ok => Icons.check_circle_rounded,
        StockStatus.vencido => Icons.block_rounded,
        StockStatus.semValidade => Icons.all_inclusive_rounded,
      };
}
