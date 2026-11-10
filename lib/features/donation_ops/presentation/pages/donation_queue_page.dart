import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../donations/domain/entities/donation.dart';
import '../../../donations/domain/entities/donation_status.dart';
import '../../../donations/presentation/widgets/donation_status_chip.dart';
import '../../../donations/presentation/widgets/donor_header.dart';
import '../controllers/donation_ops_provider.dart';

/// S01 — Fila de triagem das doações.
///
/// Aba "Triagem": intenções pendentes que aguardam aprovação.
/// Aba "Para destinar": doações aprovadas (esperando a entrega física) e doações já
/// recebidas que ainda não têm destino registrado.
class DonationQueuePage extends ConsumerWidget {
  const DonationQueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final triage = ref.watch(triageDonationsProvider);
    final allocate = ref.watch(toAllocateDonationsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Column(
          children: [
            const DonorHeader(
              title: 'Doações recebidas',
              subtitle: 'Gestão Casa da Criança',
            ),
            Material(
              color: cs.surfaceContainerLow,
              child: TabBar(
                labelColor: AppColors.brandPrimary600,
                unselectedLabelColor: cs.onSurfaceVariant,
                indicatorColor: AppColors.brandPrimary600,
                labelStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'Triagem (${triage.valueOrNull?.length ?? 0})'),
                  Tab(text: 'Para destinar (${allocate.valueOrNull?.length ?? 0})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _QueueList(
                    donations: triage,
                    emptyTitle: 'Nenhuma doação aguardando aprovação',
                    emptyDescription: 'Quando um doador registrar uma intenção, ela aparece aqui.',
                  ),
                  _QueueList(
                    donations: allocate,
                    emptyTitle: 'Nada para destinar agora',
                    emptyDescription:
                        'Doações aprovadas e recebidas aguardando destino aparecem nesta aba.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueList extends ConsumerWidget {
  final AsyncValue<List<Donation>> donations;
  final String emptyTitle;
  final String emptyDescription;

  const _QueueList({
    required this.donations,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return donations.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          CasaCardSkeleton(),
          SizedBox(height: AppSpacing.md),
          CasaCardSkeleton(),
          SizedBox(height: AppSpacing.md),
          CasaCardSkeleton(),
        ],
      ),
      error: (_, __) => CasaEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não foi possível carregar a fila',
        description: 'Verifique sua conexão e tente novamente.',
        ctaLabel: 'Tentar de novo',
        onCta: () => ref.invalidate(donationQueueProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return CasaEmptyState(
            icon: Icons.inbox_outlined,
            title: emptyTitle,
            description: emptyDescription,
          );
        }
        final awaitingDelivery =
            list.where((d) => d.status == DonationStatus.aprovada).toList();
        final awaitingDestination = list.where((d) => d.needsDestination).toList();
        final pending = list.where((d) => d.status == DonationStatus.pendente).toList();

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (pending.isNotEmpty) ...[
              const _SectionTitle('Aguardam aprovação'),
              for (final d in pending) _DonationCard(donation: d),
            ],
            if (awaitingDelivery.isNotEmpty) ...[
              const _SectionTitle('Aprovadas · aguardam a entrega'),
              for (final d in awaitingDelivery) _DonationCard(donation: d),
            ],
            if (awaitingDestination.isNotEmpty) ...[
              const _SectionTitle('Recebidas · falta registrar o destino'),
              for (final d in awaitingDestination) _DonationCard(donation: d),
            ],
          ],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: Text(
        text,
        style: AppTypography.headingSmall
            .copyWith(color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

class _DonationCard extends StatelessWidget {
  final Donation donation;
  const _DonationCard({required this.donation});

  ({String label, IconData icon, String route}) get _action {
    if (donation.status == DonationStatus.pendente) {
      return (
        label: 'Avaliar doação',
        icon: Icons.fact_check_outlined,
        route: AppRoutes.opsDonationPath(donation.id),
      );
    }
    if (donation.status == DonationStatus.aprovada) {
      return (
        label: 'Receber doação',
        icon: Icons.move_to_inbox_rounded,
        route: AppRoutes.opsDonationReceivePath(donation.id),
      );
    }
    return (
      label: 'Registrar destino',
      icon: Icons.volunteer_activism_rounded,
      route: AppRoutes.opsDonationReceivePath(donation.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final action = _action;
    final first = donation.items.isEmpty ? null : donation.items.first;
    final extra = donation.items.length > 1 ? ' +${donation.items.length - 1}' : '';
    final created = donation.createdAt;
    final review = donation.items.any((i) => i.subjectToReview);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: () => context.push(action.route),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        donation.displayProtocol,
                        style: AppTypography.headingSmall.copyWith(color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: DonationStatusChip(status: donation.status)),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (first != null)
                  Text(
                    '${first.quantity}× ${first.description}$extra',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(color: cs.onSurface),
                  ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: 2,
                  children: [
                    _Meta(Icons.person_outline_rounded, donation.donorSnapshot.displayName),
                    if (created != null)
                      _Meta(Icons.schedule_rounded, DateFormat('dd/MM, HH:mm').format(created)),
                    _Meta(Icons.inventory_2_outlined, '${donation.totalUnits} un.'),
                  ],
                ),
                if (review) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning600.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      'Validade abaixo do mínimo recomendado',
                      style: AppTypography.labelSmall.copyWith(color: AppColors.warning600),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(builder: (context, box) {
                  final button = CasaButton(
                    label: action.label,
                    icon: action.icon,
                    height: 44,
                    variant: donation.status == DonationStatus.pendente
                        ? CasaButtonVariant.primary
                        : CasaButtonVariant.secondary,
                    onPressed: () => context.push(action.route),
                  );
                  // No celular o botão ocupa a largura toda; no PC fica compacto à direita.
                  if (box.maxWidth < 600) return button;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(width: 240, child: button),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: AppTypography.bodySmall.copyWith(color: color))),
      ],
    );
  }
}
