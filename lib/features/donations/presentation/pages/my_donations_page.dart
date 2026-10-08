import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/donation.dart';
import '../controllers/donations_provider.dart';
import '../widgets/donation_status_chip.dart';
import '../widgets/donor_header.dart';

/// D08 — Minhas doações: histórico do doador (`donorId == auth.uid`) com
/// abas de filtro por status.
class MyDonationsPage extends ConsumerWidget {
  const MyDonationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final selected = ref.watch(donationStatusFilterProvider);
    final donations = ref.watch(filteredDonationsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          const DonorHeader(
            title: 'Minhas doações',
            subtitle: 'Acompanhe o status de cada doação',
          ),
          Container(
            color: cs.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final filter in DonationStatusFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: selected == filter,
                        showCheckmark: false,
                        selectedColor: AppColors.brandPrimary600,
                        labelStyle: AppTypography.labelLarge.copyWith(
                          color: selected == filter
                              ? Colors.white
                              : AppColors.neutral700,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => ref
                            .read(donationStatusFilterProvider.notifier)
                            .state = filter,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: donations.when(
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
                title: 'Não foi possível carregar suas doações',
                description: 'Verifique sua conexão e tente novamente.',
                ctaLabel: 'Tentar de novo',
                onCta: () => ref.invalidate(myDonationsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  final isAll = selected == DonationStatusFilter.todas;
                  return CasaEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: isAll
                        ? 'Você ainda não fez nenhuma doação'
                        : 'Nenhuma doação nesta aba',
                    description: isAll
                        ? 'Veja o que a ONG mais precisa e faça sua primeira doação.'
                        : null,
                    ctaLabel: isAll ? 'Ver necessidades' : null,
                    onCta: isAll ? () => context.go(AppRoutes.donorNeeds) : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => _DonationTile(
                    donation: list[index],
                    onTap: () => context.push(
                      AppRoutes.donorDonationDetailPath(list[index].id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationTile extends StatelessWidget {
  final Donation donation;
  final VoidCallback onTap;

  const _DonationTile({required this.donation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final created = donation.createdAt;
    final first = donation.items.isEmpty ? null : donation.items.first;
    final extra = donation.items.length > 1 ? ' +${donation.items.length - 1}' : '';

    return Semantics(
      button: true,
      label: 'Doação ${donation.displayProtocol}, ${donation.status.label}',
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
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
                        style: AppTypography.headingSmall
                            .copyWith(color: cs.onSurface),
                      ),
                    ),
                    DonationStatusChip(status: donation.status),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (first != null)
                  Text(
                    '${first.description}$extra',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(color: cs.onSurface),
                  ),
                Text(
                  [
                    '${donation.totalUnits} unidades',
                    if (created != null) DateFormat('dd/MM/yyyy').format(created),
                  ].join(' · '),
                  style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
