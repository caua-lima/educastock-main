import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/donation_needs_provider.dart';
import '../controllers/donations_provider.dart';
import '../controllers/donor_profile_provider.dart';
import '../widgets/donation_status_chip.dart';
import '../widgets/donor_header.dart';
import '../widgets/email_verification_banner.dart';
import '../widgets/need_card.dart';

/// D03 — Home do doador: saudação, última doação, CTA "Quero doar" e as duas
/// prioridades mais urgentes da semana.
class DonorHomePage extends ConsumerWidget {
  const DonorHomePage({super.key});

  String _firstName(String? profileName, String? userName) {
    final full = (profileName != null && profileName.trim().isNotEmpty)
        ? profileName
        : (userName ?? '');
    final first = full.trim().split(' ').first;
    return first.isEmpty ? 'doador' : first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(donorProfileProvider).valueOrNull;
    final donations = ref.watch(myDonationsProvider);
    final topNeeds = ref.watch(topNeedsProvider(2));

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          DonorHeader(
            title: 'Olá, ${_firstName(profile?.displayName, user?.name)}',
            subtitle: 'Portal do Doador · Casa da Criança',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myDonationsProvider);
                ref.invalidate(donationNeedsProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  const EmailVerificationBanner(),
                  const SizedBox(height: AppSpacing.md),

                  // ── Última doação ──────────────────────────────────────
                  donations.when(
                    loading: () => const CasaLoadingSkeleton(height: 72),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) {
                      if (list.isEmpty) return const SizedBox.shrink();
                      final last = list.first;
                      return _LastDonationTile(
                        label: 'Sua última doação',
                        title: last.displayProtocol,
                        trailing: DonationStatusChip(status: last.status),
                        onTap: () => context.push(
                          AppRoutes.donorDonationDetailPath(last.id),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── CTA principal ──────────────────────────────────────
                  CasaButton(
                    label: 'Quero doar',
                    icon: Icons.volunteer_activism_rounded,
                    onPressed: () => context.push(AppRoutes.donorDonate),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Prioridades da semana ──────────────────────────────
                  CasaSectionHeader(
                    title: 'Prioridades da semana',
                    action: 'Ver todas',
                    onAction: () => context.go(AppRoutes.donorNeeds),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  topNeeds.when(
                    loading: () => const Column(
                      children: [
                        CasaCardSkeleton(),
                        SizedBox(height: AppSpacing.md),
                        CasaCardSkeleton(),
                      ],
                    ),
                    error: (_, __) => CasaEmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Não foi possível carregar as necessidades',
                      description: 'Verifique sua conexão e tente novamente.',
                      ctaLabel: 'Tentar de novo',
                      onCta: () => ref.invalidate(donationNeedsProvider),
                    ),
                    data: (needs) {
                      if (needs.isEmpty) {
                        return CasaEmptyState(
                          icon: Icons.favorite_rounded,
                          title: 'Nenhuma necessidade prioritária agora',
                          description:
                              'Quer oferecer algo mesmo assim? A equipe avalia cada oferta.',
                          ctaLabel: 'Oferecer um item',
                          onCta: () => context.push(AppRoutes.donorDonate),
                        );
                      }
                      return Column(
                        children: [
                          for (final need in needs) ...[
                            NeedCard(
                              need: need,
                              onTap: () => context.push(
                                AppRoutes.donorNeedDetailPath(need.id),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão simples "rótulo + título + chip", usado para a última doação.
class _LastDonationTile extends StatelessWidget {
  final String label;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  const _LastDonationTile({
    super.key,
    required this.label,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.labelMedium
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      title,
                      style: AppTypography.headingSmall
                          .copyWith(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
