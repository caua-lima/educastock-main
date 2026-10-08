import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../products/domain/entities/product.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../domain/entities/donation_need.dart';
import '../controllers/donation_needs_provider.dart';
import '../widgets/donor_header.dart';
import '../widgets/need_priority_chip.dart';

/// D05 — Detalhe da necessidade: por que é prioritária, validade mínima e o
/// quanto já foi prometido. CTA "Quero doar isso" leva ao formulário (D06).
class DonationNeedDetailPage extends ConsumerWidget {
  final String needId;

  const DonationNeedDetailPage({super.key, required this.needId});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.donorNeeds);
    }
  }

  String _categoryLabel(String categoryId) {
    final category = ProductCategory.values.firstWhere(
      (c) => c.name == categoryId,
      orElse: () => ProductCategory.outro,
    );
    return defaultCategoryLabel(category);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final need = ref.watch(needByIdProvider(needId));

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          DonorHeader(
            title: 'Detalhe da necessidade',
            onBack: () => _back(context),
          ),
          Expanded(
            child: need.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  CasaLoadingSkeleton(height: 28, width: 220),
                  SizedBox(height: AppSpacing.lg),
                  CasaCardSkeleton(),
                ],
              ),
              error: (_, __) => CasaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Não foi possível carregar este item',
                ctaLabel: 'Voltar às necessidades',
                onCta: () => context.go(AppRoutes.donorNeeds),
              ),
              data: (value) {
                if (value == null || !value.isActive) {
                  return CasaEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Esta necessidade foi encerrada',
                    description: 'Veja o que mais a ONG precisa agora.',
                    ctaLabel: 'Voltar às necessidades',
                    onCta: () => context.go(AppRoutes.donorNeeds),
                  );
                }
                return _NeedDetail(
                  need: value,
                  categoryLabel: _categoryLabel(value.categoryId),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NeedDetail extends StatelessWidget {
  final DonationNeed need;
  final String categoryLabel;

  const _NeedDetail({required this.need, required this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = AppTypography.labelMedium.copyWith(color: cs.onSurfaceVariant);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      need.title,
                      style: AppTypography.headingMedium
                          .copyWith(color: cs.onSurface),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  NeedPriorityChip(priority: need.priority),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(categoryLabel, style: label),
              const SizedBox(height: AppSpacing.xl),

              Text('Restam a cobrir', style: label),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${need.remainingQty} ${need.unit}',
                style: AppTypography.numberLarge.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: need.pledgedProgress,
                  minHeight: 8,
                  color: AppColors.success600,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${need.pledgedQty} de ${need.suggestedQty} ${need.unit} já prometidas',
                style: label,
              ),
              const SizedBox(height: AppSpacing.xl),

              if (need.minShelfLifeDays > 0)
                _InfoRow(
                  icon: Icons.event_available_rounded,
                  title: 'Validade mínima',
                  text:
                      '${need.minShelfLifeDays} dias contados a partir da entrega. '
                      'Itens com validade menor seguem sujeitos à avaliação da equipe.',
                ),
              if (need.note != null && need.note!.trim().isNotEmpty)
                _InfoRow(
                  icon: Icons.sticky_note_2_rounded,
                  title: 'Observação da ONG',
                  text: need.note!,
                ),
              const _InfoRow(
                icon: Icons.volunteer_activism_rounded,
                title: 'Por que isso importa',
                text:
                    'Doar o que a ONG precisa evita excesso e desperdício: '
                    'cada item vira utilidade real para as crianças atendidas.',
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: CasaButton(
              label: 'Quero doar isso',
              icon: Icons.volunteer_activism_rounded,
              onPressed: () =>
                  context.push(AppRoutes.donorDonatePath(needId: need.id)),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoRow({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.brandPrimary600),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(text,
                    style: AppTypography.bodyMedium
                        .copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
