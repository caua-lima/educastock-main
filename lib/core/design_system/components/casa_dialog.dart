import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

class CasaDialogConfirmacao extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDanger;

  const CasaDialogConfirmacao({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.isDanger = false,
  });
  
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirmar',
    String cancelLabel = 'Cancelar',
    bool isDanger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CasaDialogConfirmacao(
        title: title,
        message: message,
        onConfirm: () => Navigator.pop(context, true),
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDanger: isDanger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDanger ? AppColors.danger600 : AppColors.brandPrimary600,
          ),
          child: Text(confirmLabel),
        ),
      ],
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
    );
  }
}

void showCasaSnackbar(
  BuildContext context, {
  required String message,
  bool isError = false,
  bool isSuccess = false,
  Duration duration = const Duration(seconds: 3),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError
                ? Icons.error_rounded
                : isSuccess
                    ? Icons.check_circle_rounded
                    : Icons.info_rounded,
            color: AppColors.surface,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.surface),
            ),
          ),
        ],
      ),
      backgroundColor: isError
          ? AppColors.danger600
          : isSuccess
              ? AppColors.success600
              : AppColors.neutral900,
      duration: duration,
    ),
  );
}
