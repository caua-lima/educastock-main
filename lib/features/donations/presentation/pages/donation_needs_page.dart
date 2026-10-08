import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../products/domain/entities/product.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../controllers/donation_needs_provider.dart';
import '../widgets/donor_header.dart';
import '../widgets/need_card.dart';

/// D04 — Catálogo de necessidades: busca, filtro por categoria em chips
/// horizontais e cartões com o "restante a cobrir" (`remainingQty`).
class DonationNeedsPage extends ConsumerWidget {
  const DonationNeedsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final filter = ref.watch(needsFilterProvider);
    final needs = ref.watch(filteredNeedsProvider);
    final notifier = ref.read(needsFilterProvider.notifier);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          const DonorHeader(
            title: 'Necessidades da ONG',
            subtitle: 'O que a Casa da Criança mais precisa agora',
          ),
          Container(
            color: cs.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                CasaSearchBar(
                  hint: 'Buscar item...',
                  onChanged: notifier.setQuery,
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryChip(
                        label: 'Todas',
                        selected: filter.categoryId == null,
                        onTap: () => notifier.setCategory(null),
                      ),
                      for (final category in ProductCategory.values)
                        _CategoryChip(
                          label: defaultCategoryLabel(category),
                          selected: filter.categoryId == category.name,
                          onTap: () => notifier.setCategory(category.name),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: needs.when(
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
                title: 'Não foi possível carregar as necessidades',
                description: 'Verifique sua conexão e tente novamente.',
                ctaLabel: 'Tentar de novo',
                onCta: () => ref.invalidate(donationNeedsProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  final hasFilter =
                      filter.query.trim().isNotEmpty || filter.categoryId != null;
                  return CasaEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: hasFilter
                        ? 'Nenhum item encontrado'
                        : 'Nenhuma necessidade no momento',
                    description: hasFilter
                        ? 'Tente outra busca ou categoria.'
                        : 'Quer oferecer algo mesmo assim? A equipe avalia cada oferta.',
                    ctaLabel: 'Oferecer outro item',
                    onCta: () => context.push(AppRoutes.donorDonate),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: list.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == list.length) {
                      return Center(
                        child: TextButton(
                          onPressed: () => context.push(AppRoutes.donorDonate),
                          child: const Text(
                            'Não achou o que quer doar? Oferecer outro item',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    final need = list[index];
                    return NeedCard(
                      need: need,
                      showProgress: true,
                      onTap: () =>
                          context.push(AppRoutes.donorNeedDetailPath(need.id)),
                      onDonate: () => context
                          .push(AppRoutes.donorDonatePath(needId: need.id)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.brandPrimary600,
        labelStyle: AppTypography.labelLarge.copyWith(
          color: selected ? Colors.white : AppColors.neutral700,
          fontWeight: FontWeight.w600,
        ),
        showCheckmark: false,
      ),
    );
  }
}
