import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';

/// Aviso de e-mail não verificado (RN-D02: exigido para registrar a doação).
/// Some sozinho quando o e-mail é confirmado.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  // Estado apenas de UI (indicador de carregamento do botão).
  bool _busy = false;

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await ref.read(authDatasourceProvider).sendEmailVerification();
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Enviamos um novo link para o seu e-mail.',
        isSuccess: true,
      );
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Não foi possível enviar agora. Tente em instantes.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final verified =
          await ref.read(authDatasourceProvider).refreshEmailVerified();
      if (!mounted) return;
      if (!verified) {
        showCasaSnackbar(
          context,
          message: 'Ainda não confirmado. Abra o link enviado ao seu e-mail.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Não foi possível verificar agora.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.read(authDatasourceProvider).isEmailVerified) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning600.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.warning600.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_unread_rounded,
                  color: AppColors.warning600, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Confirme seu e-mail para registrar doações',
                  style: AppTypography.labelLarge.copyWith(color: cs.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enviamos um link de confirmação quando você criou a conta.',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton(
                onPressed: _busy ? null : _resend,
                child: const Text('Reenviar e-mail'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: _busy ? null : _check,
                child: const Text('Já confirmei'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
