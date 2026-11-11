import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../donations/domain/entities/donation.dart';
import '../../../donations/domain/entities/donation_item.dart';
import '../../../donations/domain/entities/donation_status.dart';
import '../../../donations/presentation/controllers/donations_provider.dart';
import '../../../donations/presentation/widgets/donation_status_chip.dart';
import '../../../donations/presentation/widgets/donor_header.dart';
import '../../data/donation_ops_repository.dart';
import '../controllers/donation_ops_provider.dart';

/// S02 — Avaliação e decisão: mostra o doador, os itens ofertados e a validade
/// informada; a equipe pode enviar uma mensagem opcional e aprovar ou recusar.
class DonationReviewPage extends ConsumerStatefulWidget {
  final String donationId;
  const DonationReviewPage({super.key, required this.donationId});

  @override
  ConsumerState<DonationReviewPage> createState() => _DonationReviewPageState();
}

class _DonationReviewPageState extends ConsumerState<DonationReviewPage> {
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.opsDonations);
    }
  }

  String _errorText(Object e) => e is DonationOpsException
      ? e.message
      : 'Não foi possível concluir. Verifique a conexão e tente de novo.';

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ref.read(donationOpsActionsProvider.notifier).decide(
            donationId: widget.donationId,
            approve: true,
            message: _message.text,
          );
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Doação aprovada. O doador foi avisado.', isSuccess: true);
      _back();
    } catch (e) {
      if (mounted) showCasaSnackbar(context, message: _errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refuse() async {
    final reasonController = TextEditingController(text: _message.text);
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recusar doação?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('O doador verá o motivo no aplicativo. Explique de forma gentil.'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Ex.: no momento já temos estoque suficiente deste item.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger600),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;
    if (reason.isEmpty) {
      if (mounted) {
        showCasaSnackbar(context, message: 'Informe o motivo da recusa.', isError: true);
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(donationOpsActionsProvider.notifier).decide(
            donationId: widget.donationId,
            approve: false,
            refusalReason: reason,
          );
      if (!mounted) return;
      showCasaSnackbar(context, message: 'Doação recusada. O doador foi avisado.', isSuccess: true);
      _back();
    } catch (e) {
      if (mounted) showCasaSnackbar(context, message: _errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final donation = ref.watch(donationByIdProvider(widget.donationId));

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          DonorHeader(
            title: 'Avaliar doação',
            subtitle: donation.valueOrNull?.displayProtocol,
            onBack: _back,
          ),
          Expanded(
            child: donation.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [CasaCardSkeleton(), SizedBox(height: AppSpacing.md), CasaCardSkeleton()],
              ),
              error: (_, __) => CasaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Não foi possível carregar a doação',
                ctaLabel: 'Tentar de novo',
                onCta: () => ref.invalidate(donationByIdProvider(widget.donationId)),
              ),
              data: (d) {
                if (d == null) {
                  return const CasaEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Doação não encontrada',
                  );
                }
                return _Body(
                  donation: d,
                  message: _message,
                  busy: _busy,
                  onApprove: _approve,
                  onRefuse: _refuse,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final Donation donation;
  final TextEditingController message;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onRefuse;

  const _Body({
    required this.donation,
    required this.message,
    required this.busy,
    required this.onApprove,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final point = ref.watch(donationPointByIdProvider(donation.pointId));
    final window = donation.window;
    final fmt = DateFormat('dd/MM/yyyy');
    final decidable = donation.status == DonationStatus.pendente;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _DonorBadge(donation: donation),
              const SizedBox(height: AppSpacing.lg),
              Text('Itens ofertados',
                  style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.sm),
              for (final item in donation.items) _ItemCard(item: item),
              if (point != null || window != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Entrega prevista',
                          style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
                      const SizedBox(height: AppSpacing.xs),
                      if (point != null)
                        Text('${point.name} — ${point.address}',
                            style: AppTypography.bodyMedium.copyWith(color: cs.onSurface)),
                      if (window != null)
                        Text(
                          '${fmt.format(window.from)} a ${fmt.format(window.to)}',
                          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      // Doação ainda aberta com a janela de entrega vencida: a expiração
                      // automática depende das Cloud Functions; aqui a equipe é avisada.
                      if (window != null &&
                          donation.status.isOpen &&
                          DateUtils.dateOnly(window.to).isBefore(DateUtils.dateOnly(DateTime.now())))
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Row(
                            children: [
                              const Icon(Icons.event_busy_rounded,
                                  size: 16, color: AppColors.warning600),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'A janela de entrega já passou. Combine uma nova data com o doador.',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.warning600, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (decidable) ...[
                Text('Mensagem para o doador (opcional)',
                    style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: message,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: 'Ex.: Pode entregar de segunda a sexta, das 8h às 17h.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
                  ),
                ),
              ] else
                _AlreadyDecided(donation: donation),
            ],
          ),
        ),
        if (decidable)
          Container(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CasaButton(
                    label: 'Recusar',
                    variant: CasaButtonVariant.danger,
                    onPressed: busy ? null : onRefuse,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: CasaButton(
                    label: 'Aprovar doação',
                    icon: Icons.check_rounded,
                    isLoading: busy,
                    onPressed: busy ? null : onApprove,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonorBadge extends StatelessWidget {
  final Donation donation;
  const _DonorBadge({required this.donation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = donation.donorSnapshot.displayName;
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.brandPrimary600,
            child: Text(initials.isEmpty ? '?' : initials,
                style: AppTypography.labelLarge.copyWith(color: Colors.white)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
                if (donation.donorSnapshot.phone != null &&
                    donation.donorSnapshot.phone!.isNotEmpty)
                  Text(donation.donorSnapshot.phone!,
                      style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          DonationStatusChip(status: donation.status),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final DonationItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expiry = item.expiryDate;
    final days = expiry?.difference(DateTime.now()).inDays;
    final expiryColor = item.subjectToReview
        ? AppColors.warning600
        : (days != null && days < 30 ? AppColors.warning600 : AppColors.success600);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${item.quantity} ${item.unit} · ${item.description}',
              style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _Field('Categoria', item.category),
              _Field('Condição', item.condition.label),
              _Field(
                'Validade informada',
                !item.hasExpiry
                    ? 'Sem validade'
                    : (expiry == null ? 'Não informada' : DateFormat('dd/MM/yyyy').format(expiry)),
                color: item.hasExpiry ? expiryColor : null,
              ),
            ],
          ),
          if (item.subjectToReview) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Validade abaixo do mínimo recomendado: avalie antes de aprovar.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.warning600),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Field(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
        Text(value,
            style: AppTypography.bodyMedium
                .copyWith(color: color ?? cs.onSurface, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _AlreadyDecided extends StatelessWidget {
  final Donation donation;
  const _AlreadyDecided({required this.donation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canReceive = donation.status == DonationStatus.aprovada || donation.needsDestination;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Esta doação já foi decidida (${donation.status.label}).',
              style: AppTypography.bodyMedium.copyWith(color: cs.onSurface)),
          if (donation.approvalMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Mensagem enviada: ${donation.approvalMessage}',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
          ],
          if (donation.refusalReason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Motivo: ${donation.refusalReason}',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
          ],
          if (canReceive) ...[
            const SizedBox(height: AppSpacing.md),
            CasaButton(
              label: donation.status == DonationStatus.aprovada
                  ? 'Receber doação'
                  : 'Registrar destino',
              icon: Icons.move_to_inbox_rounded,
              onPressed: () => context.push(AppRoutes.opsDonationReceivePath(donation.id)),
            ),
          ],
        ],
      ),
    );
  }
}
