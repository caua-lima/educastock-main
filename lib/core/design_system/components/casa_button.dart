import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

enum CasaButtonVariant { primary, secondary, ghost, danger }

class CasaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CasaButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;
  final double? height;

  const CasaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CasaButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height ?? 52,
      child: _buildButton(context),
    );
  }

  Widget _buildButton(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabledBg = cs.surfaceContainerHighest;
    final disabledFg = cs.onSurfaceVariant.withValues(alpha: 0.5);
    final isDisabled = onPressed == null || isLoading;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == CasaButtonVariant.primary
                  ? Colors.white
                  : cs.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: AppTypography.buttonLarge),
            ],
          );

    switch (variant) {
      case CasaButtonVariant.primary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            disabledBackgroundColor: disabledBg,
            disabledForegroundColor: disabledFg,
          ),
          child: child,
        );

      case CasaButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          child: child,
        );

      case CasaButtonVariant.ghost:
        return TextButton(
          onPressed: isDisabled ? null : onPressed,
          child: child,
        );

      case CasaButtonVariant.danger:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger600,
            foregroundColor: AppColors.surface,
            disabledBackgroundColor: disabledBg,
            disabledForegroundColor: disabledFg,
          ),
          child: child,
        );
    }
  }
}
