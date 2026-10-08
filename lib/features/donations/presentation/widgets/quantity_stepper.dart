import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';

/// Controle de quantidade com botões − / + (alvos de toque de 48 dp).
/// Controlado: quem usa guarda o valor (no `donationDraftNotifier`).
class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 100000,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canDecrease = value > min;
    final canIncrease = value < max;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            semanticLabel: 'Diminuir quantidade',
            onTap: canDecrease ? () => onChanged(value - 1) : null,
          ),
          Semantics(
            label: 'Quantidade: $value',
            child: Text(
              '$value',
              style: AppTypography.numberMedium.copyWith(color: cs.onSurface),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            semanticLabel: 'Aumentar quantidade',
            onTap: canIncrease ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.small + 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.small + 2),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              color: onTap == null
                  ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                  : AppColors.brandPrimary600,
            ),
          ),
        ),
      ),
    );
  }
}
