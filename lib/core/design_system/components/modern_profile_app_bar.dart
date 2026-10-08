import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/router/app_router.dart';
import '../../../features/batches/domain/entities/batch.dart';
import '../../../features/batches/presentation/controllers/batches_provider.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'casa_action_sheet.dart';
import 'casa_dialog.dart';

// Gradiente padrão de todos os headers do app
const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF0F2444), Color(0xFF1A3A6B), Color(0xFF1D5FA8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ModernProfileAppBar extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final String? profileName;
  final VoidCallback? onProfileTap;
  final List<Widget>? actions;
  final bool showBackButton;
  /// Conteúdo opcional renderizado abaixo do título, dentro do mesmo
  /// gradiente do header. Use para KPIs, busca, filtros, etc — estilo
  /// "hero header" do dashboard.
  final Widget? extraContent;
  /// Ícone específico da página, renderizado em container com glow
  /// à esquerda do título. Quando omitido, mostra só a barra branca.
  final IconData? pageIcon;
  /// Cor de acento do ícone (usada no glow). Default = ciano.
  final Color iconColor;

  const ModernProfileAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.profileName,
    this.onProfileTap,
    this.actions,
    // backgroundColor / foregroundColor mantidos para não quebrar chamadas antigas
    // ignore: unused_element
    Color? backgroundColor,
    // ignore: unused_element
    Color? foregroundColor,
    this.showBackButton = false,
    this.extraContent,
    this.pageIcon,
    this.iconColor = const Color(0xFF38BDF8),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedName = profileName?.trim();
    final initial = (normalizedName == null || normalizedName.isEmpty)
        ? 'U'
        : normalizedName.substring(0, 1).toUpperCase();

    final alertCount = ref.watch(allAvailableBatchesProvider).when(
          data: (list) =>
              list.where((b) => !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30)).length,
          loading: () => 0,
          error: (_, __) => 0,
        );

    // Header sempre visível — necessário pro tutorial conseguir spotlight
    // em elementos como search/filtros dentro do extraContent.
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light
            .copyWith(statusBarColor: Colors.transparent),
        child: Container(
          decoration: const BoxDecoration(gradient: _kHeaderGradient),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Linha principal: voltar + título + ações ──────────
                SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: Row(
                      children: [
                        if (showBackButton)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: InkWell(
                              onTap: () => Navigator.of(context).maybePop(),
                              borderRadius: BorderRadius.circular(AppRadius.small),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.arrow_back_ios_new_rounded,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),

                        // ── Ícone da página (se fornecido) ─────────
                        if (pageIcon != null) ...[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  iconColor.withValues(alpha: 0.35),
                                  iconColor.withValues(alpha: 0.10),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: iconColor.withValues(alpha: 0.55),
                                width: 1.3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: iconColor.withValues(alpha: 0.40),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Icon(pageIcon,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // ── Título + subtítulo ─────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3.5,
                                    height: 16,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: iconColor
                                              .withValues(alpha: 0.7),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: AppTypography.headingMedium
                                          .copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        shadows: const [
                                          Shadow(
                                            color: Color(0x66000000),
                                            blurRadius: 6,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 1),
                                Text(
                                  subtitle!,
                                  style: AppTypography.bodySmall.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.70),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // ── Actions extras ─────────────────────────
                        if ((actions ?? []).isNotEmpty)
                          IconTheme(
                            data: const IconThemeData(
                                color: Colors.white, size: 22),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: actions!),
                          ),

                        // ── Sino de alertas ────────────────────────
                        CasaAlertsBellButton(
                          alertCount: alertCount,
                          onDarkBg: true,
                        ),

                        // ── Toggle dark/light ──────────────────────
                        Padding(
                          padding:
                              const EdgeInsets.only(left: AppSpacing.xs),
                          child: CasaThemeToggleButton(),
                        ),

                        // ── Avatar de perfil ───────────────────────
                        if (profileName != null || onProfileTap != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          GestureDetector(
                            onTap: onProfileTap,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.35),
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
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Conteúdo extra (KPIs, busca, filtros) ─────────────
                if (extraContent != null) ...[
                  // Divisor decorativo gradiente
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.sm, AppSpacing.lg,
                        AppSpacing.sm + 2),
                    child: extraContent!,
                  ),
                ],
              ],
            ),
          ),
        ),
    );
  }
}

// ─── Toggle dark/light público ────────────────────────────────────────────

class CasaThemeToggleButton extends ConsumerWidget {
  const CasaThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            size: 18,
            color: Colors.white,
          ),
        ),
        tooltip: isDark ? 'Modo claro' : 'Modo escuro',
        onPressed: () =>
            ref.read(themeModeProvider.notifier).toggleDark(!isDark),
        style: IconButton.styleFrom(
          overlayColor: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

// ─── Sino de alertas público ──────────────────────────────────────────────

class CasaAlertsBellButton extends ConsumerWidget {
  final int alertCount;
  /// Se `true`, força estilo sobre fundo escuro (branco semi-transparente)
  final bool onDarkBg;

  const CasaAlertsBellButton({
    super.key,
    required this.alertCount,
    this.onDarkBg = false,
  });

  void _showBubble(BuildContext context, WidgetRef ref) {
    final allBatches = ref.read(allAvailableBatchesProvider).valueOrNull ?? [];
    final alerts = allBatches
        .where((b) => !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30))
        .toList()
      ..sort((a, b) {
        if (a.isExpired && !b.isExpired) return -1;
        if (!a.isExpired && b.isExpired) return 1;
        return a.daysToExpiry.compareTo(b.daysToExpiry);
      });
    final top5 = alerts.take(5).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleWidth = (screenWidth - 24).clamp(0.0, 320.0);
    final statusBarH = MediaQuery.of(context).padding.top;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'fechar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(),
              child: const SizedBox.expand(),
            ),
            Positioned(
              top: statusBarH + 68,
              right: 8,
              child: ScaleTransition(
                alignment: Alignment.topRight,
                scale: curved,
                child: FadeTransition(
                  opacity: anim,
                  child: Material(
                    color: Colors.transparent,
                    child: _AlertBubble(
                      batches: top5,
                      totalAlerts: alerts.length,
                      width: bubbleWidth,
                      cs: Theme.of(context).colorScheme,
                      isDark:
                          Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = alertCount;

    final bgColor = onDarkBg
        ? (count > 0
            ? AppColors.warning600.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.14))
        : (count > 0
            ? AppColors.warning600.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainer);

    final borderColor = onDarkBg
        ? (count > 0
            ? AppColors.warning600.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.3))
        : (count > 0
            ? AppColors.warning600.withValues(alpha: 0.4)
            : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35));

    final iconColor = onDarkBg
        ? (count > 0 ? AppColors.warning600 : Colors.white)
        : (count > 0
            ? AppColors.warning600
            : Theme.of(context).colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: GestureDetector(
        onTap: () => _showBubble(context, ref),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Icon(
                count > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                size: 18,
                color: iconColor,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger600,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Conteúdo do balão de alertas ─────────────────────────────────────────

class _AlertBubble extends ConsumerWidget {
  final List<dynamic> batches;
  final int totalAlerts;
  final double width;
  final ColorScheme cs;
  final bool isDark;

  const _AlertBubble({
    required this.batches,
    required this.totalAlerts,
    required this.width,
    required this.cs,
    required this.isDark,
  });

  Color _dotColor(dynamic b) {
    if (b.isExpired) return AppColors.danger600;
    final d = b.daysToExpiry as int;
    if (d <= 7) return AppColors.danger600;
    if (d <= 30) return AppColors.warning600;
    return AppColors.success600;
  }

  String _daysLabel(dynamic b) {
    if (b.isExpired) {
      final d = b.daysToExpiry as int;
      return 'Vencido há ${(-d).abs()} dia${(-d).abs() == 1 ? '' : 's'}';
    }
    final d = b.daysToExpiry as int;
    if (d == 0) return 'Vence hoje!';
    return 'Vence em $d dia${d == 1 ? '' : 's'}';
  }

  // ─── Sheet de ações do lote ────────────────────────────────────────────
  Future<void> _showBatchActions(
    BuildContext context,
    WidgetRef ref,
    dynamic b,
  ) async {
    HapticFeedback.selectionClick();
    final batchId = b.id as String;
    final productId = b.productId as String;
    final productName = b.productName as String;
    final isExpired = b.isExpired as bool;
    final dot = _dotColor(b);

    // Fecha a bubble antes de abrir o sheet (caso esteja aberta)
    Navigator.of(context).maybePop();

    await showCasaActionSheet(
      context: context,
      title: productName,
      subtitle: _daysLabel(b),
      headerColor: dot,
      headerIcon:
          isExpired ? Icons.dangerous_rounded : Icons.schedule_rounded,
      actions: [
        // Distribuir / Descartar (com pré-seleção do produto)
        CasaSheetItem(
          icon: Icons.output_rounded,
          label: isExpired ? 'Registrar descarte' : 'Distribuir lote',
          subtitle: isExpired
              ? 'Marcar saída por vencimento'
              : 'Ir para Saída com o lote selecionado',
          color: AppColors.brandPrimary600,
          onTap: () {
            context.push(
              '${AppRoutes.movement}'
              '?batchId=$batchId'
              '&productId=$productId'
              '&reason=${isExpired ? "validade" : "uso"}',
            );
          },
        ),
        // Ver produto
        CasaSheetItem(
          icon: Icons.inventory_2_rounded,
          label: 'Ver produto',
          subtitle: 'Detalhes e todos os lotes',
          color: AppColors.brandPrimary600,
          onTap: () => context.push('/products/$productId'),
        ),
        // Marcar como descartado (só quando vencido)
        if (isExpired)
          CasaSheetItem(
            icon: Icons.delete_sweep_rounded,
            label: 'Marcar lote descartado',
            subtitle: 'Removerá o lote do estoque ativo',
            destructive: true,
            onTap: () => _confirmDiscard(context, ref, b),
          ),
      ],
    );
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    WidgetRef ref,
    dynamic b,
  ) async {
    final ok = await CasaDialogConfirmacao.show(
      context: context,
      title: 'Marcar lote como descartado?',
      message:
          'O lote de "${b.productName}" será marcado como descartado e removido do estoque ativo. Use isto para vencidos sem registro de saída.',
      confirmLabel: 'Descartar',
      isDanger: true,
    );
    if (ok != true || !context.mounted) return;
    try {
      HapticFeedback.mediumImpact();
      await ref.read(batchesDatasourceProvider).updateBatchQuantity(
            b.id as String,
            0,
            BatchStatus.descartado,
          );
      if (!context.mounted) return;
      Navigator.of(context).maybePop(); // fecha a bubble
      showCasaSnackbar(context,
          message: 'Lote marcado como descartado.', isSuccess: true);
    } catch (_) {
      if (!context.mounted) return;
      showCasaSnackbar(context,
          message: 'Erro ao descartar lote.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cor "dominante" do header: vermelho se há vencidos/críticos, senão amarelo
    final hasCritical = batches.any((b) =>
        (b.isExpired as bool) || (b.daysToExpiry as int) <= 7);
    final headerColor = hasCritical ? AppColors.danger600 : AppColors.warning600;
    final headerColorSoft = hasCritical
        ? const Color(0xFFEF4444)
        : const Color(0xFFF59E0B);

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.modal + 2),
        border: Border.all(
          color: headerColor.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: isDark ? 0.25 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER moderno com gradiente ─────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  headerColor.withValues(alpha: isDark ? 0.28 : 0.16),
                  headerColorSoft.withValues(alpha: isDark ? 0.10 : 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.modal + 1)),
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ),
            child: Row(
              children: [
                // Ícone com gradiente
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        headerColor.withValues(alpha: 0.95),
                        headerColorSoft.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: headerColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      size: 19, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Notificações',
                              style: AppTypography.labelMedium.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: headerColor.withValues(alpha: 0.18),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: headerColor.withValues(alpha: 0.45),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '$totalAlerts',
                              style: TextStyle(
                                fontSize: 10,
                                color: headerColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalAlerts == 0
                            ? 'Tudo em dia ✓'
                            : '$totalAlerts ${totalAlerts == 1 ? "item precisa" : "itens precisam"} de atenção',
                        style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (batches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success600, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Tudo em dia!',
                      style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.success600,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else
            ...List.generate(batches.length, (i) {
              final b = batches[i];
              final dot = _dotColor(b);
              final isExp = b.isExpired as bool;
              final days = b.daysToExpiry as int;
              final level = isExp || days <= 7
                  ? 'CRÍTICO'
                  : days <= 30
                      ? 'ATENÇÃO'
                      : 'OK';
              final icon = isExp
                  ? Icons.dangerous_rounded
                  : days <= 7
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md),
                      child: Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/products/${b.productId}');
                      },
                      onLongPress: () => _showBatchActions(context, ref, b),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.sm + 2, AppSpacing.sm, AppSpacing.sm + 2),
                        child: Row(
                          children: [
                            // Badge ícone em gradiente
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    dot.withValues(alpha: 0.95),
                                    dot.withValues(alpha: 0.55),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.small),
                                boxShadow: [
                                  BoxShadow(
                                    color: dot.withValues(alpha: 0.32),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child:
                                  Icon(icon, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          b.productName as String,
                                          style:
                                              AppTypography.labelSmall.copyWith(
                                            color: cs.onSurface,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Severity pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color:
                                              dot.withValues(alpha: 0.13),
                                          borderRadius:
                                              BorderRadius.circular(AppRadius.pill),
                                          border: Border.all(
                                            color: dot.withValues(alpha: 0.4),
                                            width: 0.6,
                                          ),
                                        ),
                                        child: Text(
                                          level,
                                          style: TextStyle(
                                            fontSize: 8,
                                            color: dot,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.access_time_rounded,
                                          size: 10,
                                          color: dot.withValues(alpha: 0.85)),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          _daysLabel(b),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: dot,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Botão de ações (kebab)
                            InkWell(
                              onTap: () => _showBatchActions(context, ref, b),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cs.outlineVariant
                                        .withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Icon(Icons.more_horiz_rounded,
                                    size: 16, color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          if (batches.isNotEmpty)
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.alerts);
              },
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.modal + 1)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md, horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brandPrimary600.withValues(alpha: isDark ? 0.20 : 0.08),
                      AppColors.brandPrimary500.withValues(alpha: isDark ? 0.08 : 0.02),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(AppRadius.modal + 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.list_alt_rounded,
                        size: 16, color: AppColors.brandPrimary600),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Ver todas as notificações',
                        style: AppTypography.labelSmall.copyWith(
                            color: AppColors.brandPrimary600,
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.brandPrimary600),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

