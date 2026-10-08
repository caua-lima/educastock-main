import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/system_settings_provider.dart';

final _keyCategorySummary = GlobalKey();
final _keyCategoryList = GlobalKey();
final _keyCategorySwitch = GlobalKey();

class CategoriesSettingsPage extends ConsumerWidget {
  const CategoriesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    ref.watch(categorySettingsNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final categories = ref.watch(categorySettingsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Categorias',
        subtitle: 'Controle de categorias de produtos',
        pageIcon: Icons.category_rounded,
        iconColor: const Color(0xFFFBBF24),
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyCategorySummary,
                  title: 'Resumo de Categorias',
                  description: 'Este banner gradiente mostra "X de Y ativas" — quantas categorias estão sendo exibidas no cadastro de produtos em relação ao total disponível no sistema. Use este indicador para acompanhar a organização do catálogo.',
                  icon: Icons.donut_small_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'O número grande = categorias ATIVAS',
                    'Categorias inativas não aparecem na criação de produtos',
                    'Mantenha só o que faz sentido para sua ONG',
                    'Use categorias inativas para "arquivar" sem perder histórico',
                  ],
                ),
                TutorialStep(
                  key: _keyCategoryList,
                  title: 'Lista de Categorias',
                  description: 'Cada linha representa uma categoria do sistema. A borda lateral azul indica que está ativa; cinza indica oculta. Toque no switch à direita para alternar a visibilidade no cadastro de produtos.',
                  icon: Icons.category_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Categorias padrão: Alimento, Bebida, Limpeza, Higiene, Escolar, Roupas, Outro',
                    'A ordem é alfabética e fixa',
                    'Subtítulo "Visível no cadastro" = aparece nas listas',
                    'Subtítulo "Oculta" = não aparece em novos produtos',
                  ],
                ),
                TutorialStep(
                  key: _keyCategorySwitch,
                  title: 'Ativar / Ocultar Categoria',
                  description: 'O switch alterna a visibilidade da categoria. Ocultar não exclui — produtos existentes daquela categoria continuam funcionando normalmente. Só desativa para novos cadastros.',
                  icon: Icons.toggle_on_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Mudança aplica imediatamente para toda a equipe',
                    'Produtos com categoria oculta continuam aparecendo nos relatórios',
                    'Reative a qualquer momento sem perda de dados',
                    'Útil para temporadas (ex: ocultar "Roupas" no verão)',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: categories.when(
          data: (items) {
            final active = items.where((i) => i.isActive).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                // ─── Resumo
                Container(
                  key: _keyCategorySummary,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.brandPrimary600,
                        AppColors.secondaryBlue600
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.brandPrimary600.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: const Icon(Icons.category_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$active de ${items.length} ativas',
                            style: AppTypography.headingSmall
                                .copyWith(color: Colors.white),
                          ),
                          Text(
                            'Categorias disponíveis no cadastro',
                            style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ─── Lista
                ...items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final idx = entry.key;
                  return Padding(
                    key: idx == 0 ? _keyCategoryList : null,
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border(
                          left: BorderSide(
                            color: item.isActive
                                ? AppColors.brandPrimary600
                                : cs.outlineVariant,
                            width: 3,
                          ),
                          top: BorderSide(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.35)),
                          right: BorderSide(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.35)),
                          bottom: BorderSide(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.35)),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.isActive
                                  ? AppColors.brandPrimary600
                                      .withValues(alpha: 0.1)
                                  : cs.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.small),
                            ),
                            child: Icon(
                              Icons.category_outlined,
                              color: item.isActive
                                  ? AppColors.brandPrimary600
                                  : cs.onSurfaceVariant,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  item.isActive ? 'Visível no cadastro' : 'Oculta',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: item.isActive
                                        ? AppColors.success600
                                        : cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          KeyedSubtree(
                            key: idx == 0 ? _keyCategorySwitch : null,
                            child: Switch(
                              value: item.isActive,
                              onChanged: (v) async {
                                await ref
                                    .read(categorySettingsNotifierProvider
                                        .notifier)
                                    .setCategoryActive(
                                        key: item.key, isActive: v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar categorias',
            description: e.toString(),
          ),
        ),
      ),
      ]),
    );
  }
}


