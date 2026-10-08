import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';

/// Indicador de passos do formulário de doação (D06–D07): ● — ○ — ○ — ○.
/// [current] é o índice (0-based) do passo ativo.
class StepProgressBar extends StatelessWidget {
  final int total;
  final int current;

  const StepProgressBar({super.key, this.total = 4, required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < total; i++) {
      final isActive = i == current;
      final isDone = i < current;
      children.add(
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isActive ? 14 : 10,
          height: isActive ? 14 : 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isDone
                ? AppColors.brandPrimary600
                : cs.outlineVariant,
            border: isActive
                ? Border.all(color: AppColors.brandPrimary100, width: 3)
                : null,
          ),
        ),
      );
      if (i < total - 1) {
        children.add(
          Container(
            width: 30,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            color: isDone ? AppColors.brandPrimary600 : cs.outlineVariant,
          ),
        );
      }
    }
    return Semantics(
      label: 'Passo ${current + 1} de $total',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }
}
