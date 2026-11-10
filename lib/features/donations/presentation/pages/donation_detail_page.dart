import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/utils/auth_error_mapper.dart';
// Gerador de PDF carregado só quando o recibo é pedido (deixa o app mais leve na web).
import '../../data/donation_receipt_pdf.dart' deferred as receipt;
import '../../domain/entities/donation.dart';
import '../controllers/donations_provider.dart';
import '../widgets/donation_status_chip.dart';
import '../widgets/donation_timeline.dart';
import '../widgets/donor_header.dart';

/// D09 — Acompanhar doação: protocolo, status, linha do tempo, itens, onde e
/// quando entregar, e cancelamento (enquanto pendente ou aprovada).
class DonationDetailPage extends ConsumerWidget {
  final String donationId;

  const DonationDetailPage({super.key, required this.donationId});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.donorDonations);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar doação?'),
        content: const Text(
          'A reserva dos itens será liberada e a equipe será avisada. '
          'Você pode fazer uma nova doação quando quiser.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Manter doação'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger600),
            child: const Text('Cancelar doação'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(cancelDonationProvider.notifier).cancel(donationId);
    if (!context.mounted) return;
    final state = ref.read(cancelDonationProvider);
    state.whenOrNull(
      data: (_) => showCasaSnackbar(context,
          message: 'Doação cancelada.', isSuccess: true),
      error: (error, _) => showCasaSnackbar(
        context,
        message: mapAuthError(error,
            fallback: 'Não foi possível cancelar agora. Tente novamente.'),
        isError: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final donation = ref.watch(donationByIdProvider(donationId));
    final cancelling = ref.watch(cancelDonationProvider).isLoading;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          DonorHeader(
            title: donation.valueOrNull?.displayProtocol ?? 'Doação',
            subtitle: 'Acompanhamento',
            onBack: () => _back(context),
          ),
          Expanded(
            child: donation.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  CasaLoadingSkeleton(height: 24, width: 160),
                  SizedBox(height: AppSpacing.lg),
                  CasaCardSkeleton(),
                  SizedBox(height: AppSpacing.md),
                  CasaCardSkeleton(),
                ],
              ),
              error: (_, __) => CasaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Não foi possível carregar esta doação',
                ctaLabel: 'Tentar de novo',
                onCta: () => ref.invalidate(donationByIdProvider(donationId)),
              ),
              data: (value) {
                if (value == null) {
                  return CasaEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Doação não encontrada',
                    ctaLabel: 'Ver minhas doações',
                    onCta: () => context.go(AppRoutes.donorDonations),
                  );
                }
                return _DetailBody(
                  donation: value,
                  cancelling: cancelling,
                  onCancel: () => _cancel(context, ref),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Donation donation;
  final bool cancelling;
  final VoidCallback onCancel;

  const _DetailBody({
    required this.donation,
    required this.cancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final point = donation.pointId.isEmpty
        ? null
        : ref.watch(donationPointByIdProvider(donation.pointId));
    final window = donation.window;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Status',
                  style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
            ),
            DonationStatusChip(status: donation.status),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        DonationTimeline(status: donation.status),
        if (donation.protocol.isNotEmpty && donation.status.isOpen) ...[
          const SizedBox(height: AppSpacing.lg),
          _ProtocolQr(protocol: donation.protocol),
        ],
        if ((donation.refusalReason ?? '').isNotEmpty ||
            (donation.cancelReason ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Motivo: ${donation.refusalReason ?? donation.cancelReason}',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
        if ((donation.approvalMessage ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoPanel(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Mensagem da equipe',
            text: donation.approvalMessage!.trim(),
            color: AppColors.brandPrimary600,
          ),
        ],
        if (donation.impact != null) ...[
          const SizedBox(height: AppSpacing.md),
          _InfoPanel(
            icon: Icons.favorite_rounded,
            title: 'Relatório de impacto · ${donation.impact!.sector}',
            text: donation.impact!.message,
            color: AppColors.success600,
          ),
        ],
        if (donation.status.isConcluded) ...[
          const SizedBox(height: AppSpacing.md),
          CasaButton(
            label: 'Baixar recibo (PDF)',
            icon: Icons.picture_as_pdf_rounded,
            variant: CasaButtonVariant.secondary,
            onPressed: () async {
              try {
                await receipt.loadLibrary();
                await receipt.DonationReceiptPdf.share(donation, point: point);
              } catch (_) {
                if (context.mounted) {
                  showCasaSnackbar(context,
                      message: 'Não foi possível gerar o recibo agora.', isError: true);
                }
              }
            },
          ),
        ],
        const SizedBox(height: AppSpacing.lg),

        // ── Onde e quando entregar ─────────────────────────────────────
        const CasaSectionHeader(title: 'Onde e quando entregar'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary100.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(point?.name ?? 'Ponto de recebimento',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.neutral900)),
              if (point != null)
                Text(point.address,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.neutral700)),
              if (window != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '${dateFormat.format(window.from)} · '
                    '${timeFormat.format(window.from)} às ${timeFormat.format(window.to)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.neutral900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (point?.instructions != null &&
                  point!.instructions!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(point.instructions!,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.neutral700)),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Itens ──────────────────────────────────────────────────────
        CasaSectionHeader(title: 'Itens da doação', count: donation.items.length),
        const SizedBox(height: AppSpacing.sm),
        for (final item in donation.items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.description,
                            style: AppTypography.labelLarge
                                .copyWith(color: cs.onSurface)),
                        Text(
                          [
                            '${item.quantity} ${item.unit}',
                            if (item.hasExpiry && item.expiryDate != null)
                              'validade ${dateFormat.format(item.expiryDate!)}',
                          ].join(' · '),
                          style: AppTypography.bodySmall
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (item.subjectToReview)
                          Text('Sujeito a avaliação da equipe',
                              style: AppTypography.labelSmall
                                  .copyWith(color: AppColors.warning600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (donation.status.donorCanCancel) ...[
          const SizedBox(height: AppSpacing.lg),
          CasaButton(
            label: 'Cancelar doação',
            variant: CasaButtonVariant.secondary,
            icon: Icons.cancel_outlined,
            isLoading: cancelling,
            onPressed: onCancel,
          ),
        ],
      ],
    );
  }
}

/// QR Code do protocolo (RF22): o doador mostra na entrega e a equipe lê no Escanear,
/// que abre esta doação direto para conferir e receber.
class _ProtocolQr extends StatelessWidget {
  final String protocol;

  const _ProtocolQr({required this.protocol});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text('Mostre este QR Code na entrega',
              textAlign: TextAlign.center,
              style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
          const SizedBox(height: AppSpacing.md),
          // Fundo branco sempre: leitores de QR falham com módulos claros em fundo escuro.
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: Colors.white,
            child: Semantics(
              label: 'QR Code do protocolo $protocol',
              child: QrImageView(
                data: protocol,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(protocol,
              style: AppTypography.headingSmall.copyWith(
                  color: cs.onSurface, letterSpacing: 1.2)),
          Text('A equipe lê o código no Escanear ou digita o protocolo.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Quadro de destaque (mensagem da equipe, relatório de impacto).
class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelLarge.copyWith(color: color)),
                const SizedBox(height: AppSpacing.xs),
                Text(text, style: AppTypography.bodyMedium.copyWith(color: cs.onSurface, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
