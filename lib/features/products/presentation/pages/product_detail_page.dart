// product_detail_page.dart — modernizado, adaptativo (dark/light) e com ações para lotes vencidos
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../ml/presentation/controllers/consumption_forecast_provider.dart';
import '../../../ml/presentation/widgets/forecast_widgets.dart';
import '../../domain/entities/product.dart';
import '../controllers/products_provider.dart';

final _keyDetailInfo = GlobalKey();
final _keyDetailBatches = GlobalKey();
final _keyDetailFAB = GlobalKey();

class ProductDetailPage extends ConsumerWidget {
  final String productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productAsync = ref.watch(productByIdProvider(productId));
    final batchesAsync = ref.watch(batchesByProductProvider(productId));

    // A página de detalhe não bloqueia mais com fullscreen spinner: o
    // productByIdProvider tenta servir o produto pelo cache do StreamProvider
    // imediatamente, e a lista de lotes mostra apenas skeleton local.
    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: FloatingActionButton.extended(
        key: _keyDetailFAB,
        onPressed: () =>
            context.push('${AppRoutes.batchForm}?productId=$productId'),
        backgroundColor: AppColors.brandPrimary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Lote'),
        elevation: 6,
      ),
      body: productAsync.when(
        loading: () => _LoadingScaffold(cs: cs, isDark: isDark),
        error: (e, _) => _ErrorScaffold(message: e.toString(), cs: cs),
        data: (p) {
          if (p == null) {
            return _ErrorScaffold(message: 'Produto não encontrado', cs: cs);
          }
          return _DetailBody(
            product: p,
            productId: productId,
            batchesAsync: batchesAsync,
            cs: cs,
            isDark: isDark,
          );
        },
      ),
    );
  }
}

// ─── Body principal ────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  final Product product;
  final String productId;
  final AsyncValue<List<Batch>> batchesAsync;
  final ColorScheme cs;
  final bool isDark;
  const _DetailBody({
    required this.product,
    required this.productId,
    required this.batchesAsync,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = batchesAsync.valueOrNull ?? const [];
    final loading = batchesAsync.isLoading && batches.isEmpty;
    final totalQty = batches.fold<int>(0, (s, b) => s + b.quantity);
    final totalValue = batches.fold<double>(
        0, (s, b) => s + ((b.unitPrice ?? 0) * b.quantity));
    final expired = batches.where((b) => b.isExpired).toList();
    final critical = batches
        .where((b) => !b.noExpiry && !b.isExpired && b.daysToExpiry <= 7)
        .length;

    return CustomScrollView(
      slivers: [
        _ProductSliverAppBar(product: product, productId: productId),

        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              expired.isNotEmpty ? AppSpacing.md : AppSpacing.md,
              AppSpacing.lg,
              120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              KeyedSubtree(
                key: _keyDetailInfo,
                child: _StatsRow(
                  totalBatches: batches.length,
                  totalQty: totalQty,
                  totalValue: totalValue,
                  critical: critical,
                  expired: expired.length,
                  isDark: isDark,
                  cs: cs,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ForecastCard(
                  productId: productId, isDark: isDark, cs: cs),
              const SizedBox(height: AppSpacing.lg),
              KeyedSubtree(
                key: _keyDetailBatches,
                child: CasaSectionHeader(
                  title: 'Lotes',
                  count: batches.length,
                  action: 'Novo Lote',
                  onAction: () => context
                      .push('${AppRoutes.batchForm}?productId=$productId'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (loading)
                ...List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: CasaCardSkeleton(),
                  ),
                )
              else if (batches.isEmpty)
                _EmptyBatchesCallout(
                  isDark: isDark,
                  cs: cs,
                  onAdd: () => context
                      .push('${AppRoutes.batchForm}?productId=$productId'),
                )
              else
                ...batches.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _BatchCard(
                      batch: b,
                      isDark: isDark,
                      cs: cs,
                      onEdit: () => context.push(
                          '${AppRoutes.batchForm}?id=${b.id}&productId=$productId'),
                      onDelete: () => _confirmDelete(context, ref, b),
                      onActions: () => _showBatchActionsSheet(
                          context, ref, product, b),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Batch b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _DeleteConfirmDialog(batch: b),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(deleteBatchProvider.notifier).deleteBatch(b.id);
    }
  }

  /// Sheet moderno de ações para um lote — focado em lotes com notificação
  /// de validade (crítico/atenção/vencido). Aparece sempre acima da TabBar.
  Future<void> _showBatchActionsSheet(
      BuildContext context, WidgetRef ref, Product product, Batch b) async {
    final isExpired = b.isExpired;
    final isCritical = !b.noExpiry && !isExpired && b.daysToExpiry <= 7;
    final isWarning = !b.noExpiry && !isExpired && b.daysToExpiry > 7 &&
        b.daysToExpiry <= 30;

    final accent = isExpired || isCritical
        ? AppColors.danger600
        : isWarning
            ? AppColors.warning600
            : AppColors.brandPrimary600;
    final headerIcon = isExpired
        ? Icons.dangerous_rounded
        : isCritical
            ? Icons.warning_amber_rounded
            : isWarning
                ? Icons.schedule_rounded
                : Icons.inventory_2_rounded;
    final subtitle = isExpired
        ? 'Lote vencido — ação imediata'
        : isCritical
            ? 'Vence em ${b.daysToExpiry} ${b.daysToExpiry == 1 ? "dia" : "dias"}'
            : isWarning
                ? 'Vence em ${b.daysToExpiry} dias'
                : 'Lote · ${b.quantity} un';

    await showCasaActionSheet(
      context: context,
      title: product.name,
      subtitle: subtitle,
      headerColor: accent,
      headerIcon: headerIcon,
      actions: [
        // Ação principal: distribuir/descartar (já pré-seleciona o produto)
        CasaSheetItem(
          icon: Icons.output_rounded,
          label: isExpired ? 'Registrar descarte' : 'Distribuir lote',
          subtitle: isExpired
              ? 'Marcar saída por vencimento'
              : 'Saída com o lote selecionado',
          color: AppColors.brandPrimary600,
          onTap: () => context.push(
            '${AppRoutes.movement}'
            '?batchId=${b.id}'
            '&productId=${product.id}'
            '&reason=${isExpired ? "validade" : "uso"}',
          ),
        ),
        // Editar lote
        CasaSheetItem(
          icon: Icons.edit_outlined,
          label: 'Editar lote',
          subtitle: 'Quantidade, data, observações',
          onTap: () => context.push(
              '${AppRoutes.batchForm}?id=${b.id}&productId=${product.id}'),
        ),
        // Excluir lote (destrutivo)
        CasaSheetItem(
          icon: Icons.delete_outline_rounded,
          label: 'Excluir lote',
          subtitle: 'Remove permanentemente do estoque',
          destructive: true,
          onTap: () => _confirmDelete(context, ref, b),
        ),
      ],
    );
  }

}

// ─── SliverAppBar moderno ──────────────────────────────────────────────────

class _ProductSliverAppBar extends ConsumerWidget {
  final Product product;
  final String productId;
  const _ProductSliverAppBar(
      {required this.product, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final alertCount = ref.watch(allAvailableBatchesProvider).when(
          data: (list) => list
              .where((b) =>
                  !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30))
              .length,
          loading: () => 0,
          error: (_, __) => 0,
        );
    final initial = (user?.name ?? '').trim().isEmpty
        ? 'U'
        : user!.name.trim().substring(0, 1).toUpperCase();

    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: AppColors.brandPrimary600,
      foregroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      actions: [
        buildHelpButton(
          context: context,
          onPressed: () => showCasaTutorial(
            context: context,
            steps: [
              TutorialStep(
                key: _keyDetailInfo,
                title: 'Estatísticas do Produto',
                description: 'Os 4 cards coloridos na linha superior mostram os números mais importantes do produto: total de lotes ativos, quantidade total em estoque (somando todos os lotes), valor financeiro estimado e alertas (vencidos ou críticos).',
                icon: Icons.info_rounded,
                align: ContentAlign.bottom,
                hints: const [
                  '📦 Lotes: quantos lotes ativos existem',
                  '🔢 Itens: total de unidades somadas',
                  '💰 Valor: estimativa em reais (R\$) do estoque',
                  '⚠️ Alertas: vencidos primeiro, depois críticos',
                  '✏️ Botão lápis no topo edita os dados do produto',
                ],
              ),
              TutorialStep(
                key: _keyDetailBatches,
                title: 'Lotes Ativos',
                description:
                    'Lista todos os lotes registrados para este produto. Cada cartão mostra: status colorido, número do lote, quantidade, data de validade com contagem de dias, origem (doação/compra), localização física e preço unitário. Lotes em alerta mostram o menu ⋮ com ações rápidas (distribuir, editar, excluir).',
                icon: Icons.inventory_rounded,
                align: ContentAlign.bottom,
                hints: const [
                  '🔴 Borda vermelha = vencido ou crítico (≤ 7 dias)',
                  '🟡 Borda amarela = vence em até 30 dias',
                  '🟢 Borda verde = validade segura (>30 dias)',
                  '⋮ Menu (críticos/vencidos) → distribuir, editar, excluir',
                  '👆 Toque longo no card abre o menu de ações',
                ],
              ),
              TutorialStep(
                key: _keyDetailFAB,
                title: 'Adicionar Novo Lote',
                description: 'Toque no botão azul "Novo Lote" para registrar uma nova entrada deste produto. Você informa número do lote, quantidade, validade, origem, localização e preço unitário. Cada nova compra/doação deve virar um lote separado para rastreabilidade.',
                icon: Icons.add_box_rounded,
                align: ContentAlign.top,
                hints: const [
                  '📦 Cada entrada = 1 lote separado',
                  '📅 Validades diferentes SEMPRE em lotes separados',
                  '⚡ Atalho: escaneie código de barras na tela inicial',
                  '🏷️ Use o número LOT impresso na embalagem',
                ],
              ),
            ],
          ),
        ),
        CasaAlertsBellButton(alertCount: alertCount, onDarkBg: true),
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xs),
          child: CasaThemeToggleButton(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: GestureDetector(
            onTap: () => context.push(AppRoutes.settings),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            _NavButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => context.pop(),
            ),
            const Spacer(),
            _NavButton(
              icon: Icons.edit_rounded,
              onTap: () =>
                  context.push('${AppRoutes.productForm}?id=$productId'),
            ),
          ],
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        titlePadding: EdgeInsets.zero,
        background: Stack(
          children: [
            // ── Gradient base com 4 paradas (estilo dashboard) ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F2444),
                    Color(0xFF1A3A6B),
                    Color(0xFF1D5FA8),
                    Color(0xFF2563EB),
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // ── Glow radial principal (canto superior direito) ──
            Positioned(
              right: -60,
              top: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF38BDF8).withValues(alpha: 0.20),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // ── Glow secundário (canto inferior esquerdo) ──
            Positioned(
              left: -40,
              bottom: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // ── Esfera flutuante decorativa ──
            Positioned(
              right: 50,
              bottom: 16,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.02),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
            // Conteúdo
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 58, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0.10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.40),
                                width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: product.imageUrl != null &&
                                  product.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16.5),
                                  child: Image.network(product.imageUrl!,
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.inventory_2_rounded,
                                  color: Colors.white, size: 40),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if ((product.brand ?? '').isNotEmpty)
                                Text(
                                  product.brand!.toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.78),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.productName(
                                  size: 18,
                                  weight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                  height: 1.15,
                                ),
                              ),
                              if ((product.barcode ?? '').isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Row(children: [
                                  Icon(Icons.qr_code_rounded,
                                      size: 12,
                                      color: Colors.white
                                          .withValues(alpha: 0.65)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      product.barcode!,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.65),
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _HChip(product.unit),
                        _HChip(product.category.name,
                            icon: Icons.category_outlined,
                            color: const Color(0xFFBAD4FF)),
                        if (product.isPerishable)
                          _HChip('Perecível',
                              icon: Icons.schedule_rounded,
                              color: const Color(0xFFFFE0A0))
                        else
                          _HChip('Não perecível',
                              icon: Icons.shield_outlined,
                              color: const Color(0xFFA7F3D0)),
                        if (product.minimumStock > 0)
                          _HChip('Mín: ${product.minimumStock}',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFFFE0A0)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading / Error scaffolds ─────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  const _LoadingScaffold({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 165,
          pinned: true,
          backgroundColor: AppColors.brandPrimary600,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F3B82),
                  Color(0xFF1D5FA8),
                  Color(0xFF2563EB),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: CasaCardSkeleton(),
              ),
              childCount: 4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final ColorScheme cs;
  const _ErrorScaffold({required this.message, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: cs.error),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ─── Botão de navegação (no AppBar) ────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}

// ─── Chip do header ────────────────────────────────────────────────────────

class _HChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  const _HChip(this.label, {this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white.withValues(alpha: 0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.20), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9.5, color: c),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 9.5, color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Stats row ─────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int totalBatches;
  final int totalQty;
  final double totalValue;
  final int critical;
  final int expired;
  final bool isDark;
  final ColorScheme cs;
  const _StatsRow({
    required this.totalBatches,
    required this.totalQty,
    required this.totalValue,
    required this.critical,
    required this.expired,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final alertCount = expired > 0 ? expired : critical;
    final alertLabel = expired > 0 ? 'Vencidos' : 'Críticos';
    final alertColor = expired > 0
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);
    final alertIcon =
        expired > 0 ? Icons.cancel_rounded : Icons.warning_amber_rounded;

    return Row(
      children: [
        _StatCard(
          label: 'Lotes',
          value: '$totalBatches',
          icon: Icons.layers_rounded,
          color: const Color(0xFF60A5FA),
          isDark: isDark,
          cs: cs,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Itens',
          value: '$totalQty',
          icon: Icons.widgets_outlined,
          color: const Color(0xFF818CF8),
          isDark: isDark,
          cs: cs,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: 'Valor',
          value: currFmt.format(totalValue),
          icon: Icons.attach_money_rounded,
          color: const Color(0xFF22C55E),
          isDark: isDark,
          cs: cs,
          flex: 2,
        ),
        const SizedBox(width: 8),
        _StatCard(
          label: alertLabel,
          value: '$alertCount',
          icon: alertIcon,
          color: alertColor,
          isDark: isDark,
          cs: cs,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  final int flex;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.cs,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: color.withValues(alpha: isDark ? 0.28 : 0.18),
              width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isDark ? 0.10 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.11),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modal de confirmação de exclusão ──────────────────────────────────────

class _DeleteConfirmDialog extends StatelessWidget {
  final Batch batch;
  const _DeleteConfirmDialog({required this.batch});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFEF4444), size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              'Excluir Lote',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Esta ação remove o lote sem registrar baixa em estoque.\nPara lotes vencidos, prefira "Registrar descarte" no menu ⋮ para manter auditoria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.4),
            ),
            if ((batch.batchNumber ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          const Color(0xFFEF4444).withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Lote ${batch.batchNumber!}  ·  ${batch.quantity} unidades',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFFB91C1C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        'Cancelar',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Excluir',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card de lote ──────────────────────────────────────────────────────────

class _BatchCard extends StatelessWidget {
  final Batch batch;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onActions;
  const _BatchCard({
    required this.batch,
    required this.isDark,
    required this.cs,
    required this.onEdit,
    required this.onDelete,
    this.onActions,
  });

  Color _statusColor() {
    if (batch.noExpiry) return const Color(0xFF22C55E);
    if (batch.isExpired) return const Color(0xFFEF4444);
    final u = batch.daysToExpiry;
    if (u <= 7) return const Color(0xFFEF4444);
    if (u <= 30) return const Color(0xFFF59E0B);
    return const Color(0xFF22C55E);
  }

  String _statusLabel() {
    if (batch.noExpiry) return 'Sem validade';
    if (batch.isExpired) return 'Vencido';
    final u = batch.daysToExpiry;
    if (u <= 7) return 'Crítico';
    if (u <= 30) return 'Atenção';
    return 'OK';
  }

  IconData _statusIcon() {
    if (batch.noExpiry) return Icons.all_inclusive_rounded;
    if (batch.isExpired) return Icons.cancel_rounded;
    final u = batch.daysToExpiry;
    if (u <= 7) return Icons.warning_amber_rounded;
    if (u <= 30) return Icons.schedule_rounded;
    return Icons.check_circle_rounded;
  }

  String _originLabel() => switch (batch.origin) {
        'doacao' => 'Doação',
        'compra' => 'Compra',
        'parceiro' => 'Parceiro',
        'transferencia' => 'Transf.',
        _ => batch.origin,
      };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final currFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final sc = _statusColor();
    final days = batch.daysToExpiry;

    final cardBg = cs.surfaceContainerLow;
    final headerBg = sc.withValues(alpha: isDark ? 0.12 : 0.07);
    final borderColor = sc.withValues(alpha: isDark ? 0.28 : 0.20);
    final onCardSub = cs.onSurfaceVariant;

    return GestureDetector(
      onLongPress: onActions == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onActions!();
            },
      child: Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: sc.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── HEADER ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                bottom: BorderSide(
                    color: sc.withValues(alpha: isDark ? 0.18 : 0.12)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: sc,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: sc.withValues(alpha: 0.55),
                          blurRadius: 5,
                          spreadRadius: 1)
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Icon(_statusIcon(), size: 15, color: sc),
                const SizedBox(width: 5),
                Text(
                  _statusLabel(),
                  style: TextStyle(
                    color: sc,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                if (!batch.noExpiry) ...[
                  Text('  ·  ',
                      style: TextStyle(color: onCardSub, fontSize: 12.5)),
                  Expanded(
                    child: Text(
                      batch.isExpired
                          ? 'Vencido ${batch.expiryDate != null ? fmt.format(batch.expiryDate!) : ''}'
                          : batch.expiryDate != null
                              ? '${fmt.format(batch.expiryDate!)} ($days d)'
                              : 'Sem data',
                      style: TextStyle(
                          color: onCardSub,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: sc.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '${batch.quantity} un.',
                    style: TextStyle(
                        color: sc,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                // Botão kebab SEMPRE disponível — abre sheet com todas as
                // ações (distribuir, editar, excluir).
                if (onActions != null)
                  _ActionBtn(
                    icon: Icons.more_vert_rounded,
                    color: sc,
                    isDark: isDark,
                    onTap: onActions!,
                    tooltip: 'Ações do lote',
                  )
                else ...[
                  _ActionBtn(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF60A5FA),
                    isDark: isDark,
                    onTap: onEdit,
                    tooltip: 'Editar',
                  ),
                  const SizedBox(width: 4),
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                    onTap: onDelete,
                    tooltip: 'Excluir',
                  ),
                ],
              ],
            ),
          ),

          // ── CORPO ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (batch.origin.isNotEmpty)
                      _InfoChip(
                          icon: Icons.local_shipping_outlined,
                          label: _originLabel(),
                          color: const Color(0xFF818CF8),
                          isDark: isDark,
                          cs: cs),
                    if ((batch.batchNumber ?? '').isNotEmpty)
                      _InfoChip(
                          icon: Icons.tag_rounded,
                          label: batch.batchNumber!,
                          color: const Color(0xFFA78BFA),
                          isDark: isDark,
                          cs: cs),
                    if ((batch.shelfLocation ?? '').isNotEmpty)
                      _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: batch.shelfLocation!,
                          color: const Color(0xFF38BDF8),
                          isDark: isDark,
                          cs: cs),
                    if (batch.unitPrice != null)
                      _InfoChip(
                          icon: Icons.attach_money_rounded,
                          label: currFmt.format(batch.unitPrice!),
                          color: const Color(0xFF22C55E),
                          isDark: isDark,
                          cs: cs),
                  ],
                ),
                if ((batch.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.notes_rounded,
                          size: 12, color: onCardSub),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          batch.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            color: onCardSub,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (onActions != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _InlineActionBtn(
                          icon: batch.isExpired
                              ? Icons.delete_sweep_rounded
                              : Icons.outbound_rounded,
                          label: batch.isExpired
                              ? 'Descartar'
                              : 'Registrar saída',
                          color: batch.isExpired
                              ? AppColors.danger600
                              : AppColors.brandPrimary600,
                          onTap: onActions!,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ActionBtn(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF60A5FA),
                        isDark: isDark,
                        onTap: onEdit,
                        tooltip: 'Editar',
                      ),
                      const SizedBox(width: 4),
                      _ActionBtn(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        isDark: isDark,
                        onTap: onDelete,
                        tooltip: 'Excluir',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

}

// ─── Inline action button (primário, no rodapé do card de lote) ──────────────
class _InlineActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _InlineActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: color.withValues(alpha: isDark ? 0.20 : 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Action button ─────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final String? tooltip;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
              color: color.withValues(alpha: isDark ? 0.30 : 0.22)),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip!, child: btn);
  }
}

// ─── Info chip ─────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: color.withValues(alpha: isDark ? 0.24 : 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: color.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: cs.onSurface.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Forecast Card (Prophet) ───────────────────────────────────────────────

class _ForecastCard extends ConsumerWidget {
  final String productId;
  final bool isDark;
  final ColorScheme cs;

  const _ForecastCard({
    required this.productId,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(forecastForProductProvider(productId));

    return forecastAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (forecast) {
        if (forecast == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.brandPrimary600.withValues(alpha: isDark ? 0.18 : 0.08),
                AppColors.secondaryBlue600.withValues(alpha: isDark ? 0.12 : 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppColors.brandPrimary600
                  .withValues(alpha: isDark ? 0.35 : 0.20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.brandPrimary600,
                          AppColors.secondaryBlue600,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.trending_up_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Previsão de Consumo',
                          style: AppTypography.labelLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Modelo Prophet · ${forecast.dataPoints} pontos',
                          style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TrendChip(
                    trend: forecast.trend,
                    trendPercent: forecast.trendPercent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _ForecastStat(
                      label: '7 dias',
                      value: forecast.forecastWeekly.toStringAsFixed(1),
                      unit: 'un.',
                      color: AppColors.brandPrimary600,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _ForecastStat(
                      label: '30 dias',
                      value: forecast.forecastMonthly.toStringAsFixed(1),
                      unit: 'un.',
                      color: AppColors.secondaryBlue600,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _ForecastStat(
                      label: 'Estoque',
                      value: '${forecast.currentStock}',
                      unit: 'un.',
                      color: forecast.isCriticalStock
                          ? AppColors.danger600
                          : forecast.isLowStock
                              ? AppColors.warning600
                              : AppColors.success600,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              if (forecast.needsReplenishment) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warning600
                        .withValues(alpha: isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    border: Border.all(
                      color: AppColors.warning600.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_shopping_cart_rounded,
                          size: 16, color: AppColors.warning600),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Sugestão de reposição: ${forecast.suggestedReplenishment} un.',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.warning600,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ForecastStat extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isDark;

  const _ForecastStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: AppTypography.bodySmall.copyWith(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty state moderno para lotes ──────────────────────────────────────────

class _EmptyBatchesCallout extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onAdd;

  const _EmptyBatchesCallout({
    required this.isDark,
    required this.cs,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary600.withValues(alpha: isDark ? 0.18 : 0.08),
            AppColors.secondaryBlue600
                .withValues(alpha: isDark ? 0.10 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brandPrimary600
              .withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.brandPrimary600,
                  AppColors.secondaryBlue600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary600.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Nenhum lote cadastrado',
            textAlign: TextAlign.center,
            style: AppTypography.productName(
              size: 17,
              weight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Cadastre o primeiro lote para começar a controlar '
            'validade, quantidade e localização deste produto.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_box_rounded, size: 20),
              label: Text(
                'Cadastrar primeiro lote',
                style: AppTypography.productName(
                  size: 14,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
