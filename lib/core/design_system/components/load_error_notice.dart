import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Aviso de falha ao carregar dados, com "Tentar de novo".
///
/// Use no lugar de esconder o erro (`SizedBox.shrink`) ou de mostrar zero/"sem estoque":
/// a pessoa precisa saber que o número não foi consultado. A mensagem é em português e
/// não mostra detalhes técnicos.
class LoadErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const LoadErrorNotice({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.warning600.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.warning600.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.warning600, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodySmall.copyWith(color: cs.onSurface, height: 1.35),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
                child: const Text('Tentar de novo'),
              ),
          ],
        ),
      ),
    );
  }
}
