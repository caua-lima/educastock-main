import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../ml/domain/entities/risk_prediction.dart';
import '../../../ml/presentation/controllers/risk_classifier_provider.dart';
import '../../../ml/presentation/widgets/risk_widgets.dart';
import '../../../ml/presentation/controllers/consumption_forecast_provider.dart';
import '../../../ml/presentation/widgets/forecast_widgets.dart';
import '../../../reports/presentation/controllers/reports_provider.dart';

final _keyDashQuickActions = GlobalKey();
final _keyDashExpiring = GlobalKey();
final _keyDashHeader = GlobalKey();
final _keyDashMlRisk = GlobalKey();
final _keyDashMlForecast = GlobalKey();
final _keyDashKpis = GlobalKey();

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final expiringCritical = ref.watch(expiringBatchesProvider(7));
    final expiringWarning = ref.watch(expiringBatchesProvider(30));
    final allBatches = ref.watch(allAvailableBatchesProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ─── Header completo ─────────────────────────────────────────
            KeyedSubtree(
              key: _keyDashHeader,
              child: _DashboardHeader(
              user: user,
              allBatches: allBatches,
              expiringCritical: expiringCritical,
              expiringWarning: expiringWarning,
              kpiKey: _keyDashKpis,
              onSettingsTap: () => context.push(AppRoutes.settings),
              onLotesTap: () => context.go(AppRoutes.productList),
              onAlertsTap: () => context.go(AppRoutes.alerts),
              onHelpTap: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyDashKpis,
                    title: 'Indicadores Principais (KPIs)',
                    description: 'Os 3 cards coloridos no topo são o "painel de controle" do seu estoque. Mostram em tempo real: total de lotes ativos (azul), itens críticos que vencem em 7 dias (vermelho com badge) e itens em atenção que vencem em 30 dias (amarelo). Toque em qualquer um para ir direto à seção relacionada.',
                    icon: Icons.dashboard_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      '👆 Toque no card AZUL → ir para Estoque',
                      '👆 Toque no card VERMELHO/AMARELO → ir para Alertas',
                      '🔴 Vermelho = AÇÃO IMEDIATA necessária',
                      '🔄 Números atualizam automaticamente em tempo real',
                    ],
                  ),
                  TutorialStep(
                    key: _keyDashQuickActions,
                    title: 'Ações Rápidas',
                    description: 'Esta grade colorida é seu atalho para as 6 funções principais do app. Cada cartão tem ícone, título e subtítulo descritivo. Foram projetados para acesso com 1 toque — sem precisar navegar por menus.',
                    icon: Icons.grid_view_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      '📷 Escanear: entrada por código de barras (camera)',
                      '📦 Estoque: ver e editar produtos cadastrados',
                      '📤 Saída: distribuir produtos manualmente',
                      '📋 Receitas: distribuição por modelo (kits)',
                      '🔔 Alertas: ver tudo que precisa de atenção',
                      '🏷️ Localizações: gerenciar prateleiras do depósito',
                    ],
                  ),
                  TutorialStep(
                    key: _keyDashMlRisk,
                    title: 'Análise de Risco com IA',
                    description: 'O EducaStock usa Inteligência Artificial (TFLite on-device) para classificar o risco de cada lote vencer sem ser distribuído. Analisa histórico de saídas, velocidade de consumo e dias até vencimento para sugerir prioridades de distribuição.',
                    icon: Icons.psychology_rounded,
                    align: ContentAlign.top,
                    hints: const [
                      '🤖 IA roda direto no celular (privacidade total)',
                      '🔴 Alto risco: provavelmente vai vencer — distribua HOJE',
                      '🟡 Médio: monitore nos próximos dias',
                      '🟢 Baixo: situação controlada — relax',
                      '👆 Toque "Ver detalhes" para análise lote por lote',
                    ],
                  ),
                  TutorialStep(
                    key: _keyDashMlForecast,
                    title: 'Previsão de Consumo (Prophet)',
                    description: 'O modelo Prophet (Meta/Facebook) analisa o histórico real de saídas e prevê o consumo futuro de cada produto, sugerindo quantidades para reposição automaticamente. Detecta sazonalidade, eventos e tendências de aumento/queda.',
                    icon: Icons.trending_up_rounded,
                    align: ContentAlign.top,
                    hints: const [
                      '📈 Prevê consumo dos próximos 30 dias',
                      '🛒 Sugestão de compra = consumo × 1.2 - estoque atual',
                      '↗️ Tendência crescendo? Aumente o pedido',
                      '↘️ Caindo? Diminua para não desperdiçar',
                      '🔄 Re-execute notebook Colab mensalmente',
                    ],
                  ),
                  TutorialStep(
                    key: _keyDashExpiring,
                    title: 'Alertas Críticos da Semana',
                    description: 'Lista visual dos produtos que vencem em até 7 dias. Cada cartão mostra produto, dias restantes e quantidade afetada. Tome ação IMEDIATA: distribua, doe ou descarte. Evita desperdício e garante segurança alimentar das crianças.',
                    icon: Icons.warning_amber_rounded,
                    align: ContentAlign.top,
                    hints: const [
                      '🚨 Vence em 1-3 dias? Distribua HOJE!',
                      '🤝 Não consegue distribuir? Doe para outra ONG',
                      '🗑️ Vencido? Registre descarte em Saída → Vencimento',
                      '👆 "Ver todos" abre a lista completa de alertas',
                    ],
                  ),
                ],
              ),
            ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Ações rápidas
            const CasaSectionHeader(title: 'Ações Rápidas'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cross = constraints.maxWidth >= 900
                      ? 6
                      : constraints.maxWidth >= 620
                          ? 4
                          : 3;
                  return GridView.count(
                    crossAxisCount: cross,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.0,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      KeyedSubtree(
                        key: _keyDashQuickActions,
                        child: _AnimatedQuickAction(
                          delayMs: 0,
                          child: _QuickActionTile(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Escanear',
                            subtitle: 'Entrada por código',
                            color: AppColors.brandPrimary600,
                            onTap: () => context.push(AppRoutes.scanner),
                          ),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 60,
                        child: _QuickActionTile(
                          icon: Icons.list_alt_rounded,
                          label: 'Estoque',
                          subtitle: 'Produtos e lotes',
                          color: AppColors.secondaryBlue600,
                          onTap: () => context.go(AppRoutes.productList),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 120,
                        child: _QuickActionTile(
                          icon: Icons.outbound_rounded,
                          label: 'Saída',
                          subtitle: 'Baixa de estoque',
                          color: AppColors.danger600,
                          onTap: () => context.push('${AppRoutes.movement}?batchId='),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 180,
                        child: _QuickActionTile(
                          icon: Icons.menu_book_rounded,
                          label: 'Receitas',
                          subtitle: 'Saída automática',
                          color: AppColors.brandPrimary600,
                          onTap: () => context.push(AppRoutes.recipes),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 240,
                        child: _QuickActionTile(
                          icon: Icons.notifications_active_rounded,
                          label: 'Alertas',
                          subtitle: 'Prazos e riscos',
                          color: AppColors.warning600,
                          onTap: () => context.go(AppRoutes.alerts),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 300,
                        child: _QuickActionTile(
                          icon: Icons.add_location_alt_rounded,
                          label: 'Localizações',
                          subtitle: 'Estrutura física',
                          color: AppColors.secondaryBlue600,
                          onTap: () => context.push(AppRoutes.locations),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            const _DashboardChartsSection(),

            const SizedBox(height: AppSpacing.xl),

            // Análise de Risco ML — tutorial foca apenas o header da seção
            _MlRiskSection(headerKey: _keyDashMlRisk),

            const SizedBox(height: AppSpacing.xl),

            // Previsão de Consumo Prophet — tutorial foca apenas o header
            _ForecastSection(headerKey: _keyDashMlForecast),

            const SizedBox(height: AppSpacing.xl),

            // Alertas recentes — key SEMPRE no tree para o tutorial encontrar
            KeyedSubtree(
              key: _keyDashExpiring,
              child: expiringCritical.when(
                data: (batches) {
                  if (batches.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      child: CasaSectionHeader(
                        title: 'Alertas Críticos',
                        count: 0,
                      ),
                    );
                  }
                  return Column(
                    children: [
                      CasaSectionHeader(
                        title: 'Alertas Críticos',
                        count: batches.length,
                        action: 'Ver todos',
                        onAction: () => context.go(AppRoutes.alerts),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...batches.take(3).map(
                            (b) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.xs,
                              ),
                              child: _AlertBatchTile(batch: b),
                            ),
                          ),
                    ],
                  );
                },
                loading: () => const SizedBox(height: 80),
                error: (_, __) => const SizedBox(height: 80),
              ),
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
        floatingActionButton: CasaFabScan(
          onPressed: () => context.push(AppRoutes.scanner),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard Header — Visão Geral completa
// ---------------------------------------------------------------------------

class _DashboardHeader extends ConsumerWidget {
  final dynamic user;
  final AsyncValue<List<dynamic>> allBatches;
  final AsyncValue<List<dynamic>> expiringCritical;
  final AsyncValue<List<dynamic>> expiringWarning;
  final GlobalKey kpiKey;
  final VoidCallback onSettingsTap;
  final VoidCallback onLotesTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onHelpTap;

  const _DashboardHeader({
    required this.user,
    required this.allBatches,
    required this.expiringCritical,
    required this.expiringWarning,
    required this.kpiKey,
    required this.onSettingsTap,
    required this.onLotesTap,
    required this.onAlertsTap,
    required this.onHelpTap,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _formattedDate() {
    return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());
  }

  String _firstName() {
    final name = user?.name as String? ?? '';
    return name.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 360;
    final alertCount = ref.watch(allAvailableBatchesProvider).when(
          data: (list) =>
              list.where((b) => !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30)).length,
          loading: () => 0,
          error: (_, __) => 0,
        );
    final lotesCount = allBatches.maybeWhen(
        data: (l) => '${l.length}', orElse: () => '…');
    final critCount = expiringCritical.maybeWhen(
        data: (l) => '${l.length}', orElse: () => '…');
    final warnCount = expiringWarning.maybeWhen(
        data: (l) => '${l.length}', orElse: () => '…');
    final hasCritical =
        expiringCritical.maybeWhen(data: (l) => l.isNotEmpty, orElse: () => false);

    final normalizedName = user?.name?.trim() as String? ?? '';
    final initial = normalizedName.isEmpty
        ? 'U'
        : normalizedName.substring(0, 1).toUpperCase();

    final avatarSize = isCompact ? 38.0 : 44.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2444), Color(0xFF1A3A6B), Color(0xFF1D5FA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: logo + saudação + ações ──────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Logo do app com glow (zoom no logo) ──
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.06),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.55),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Transform.scale(
                        scale: 1.25, // zoom moderado, sem cortar
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()}, ${_firstName()} 👋',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: isCompact ? 17 : 19,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formattedDate(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ── Botões de ação: dicas + sino + dark/light + avatar ─────────────
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      buildHelpButton(
                        context: context,
                        onPressed: onHelpTap,
                      ),
                      CasaAlertsBellButton(
                        alertCount: alertCount,
                        onDarkBg: true,
                      ),
                      const CasaThemeToggleButton(),
                      // Avatar + settings
                      GestureDetector(
                        onTap: onSettingsTap,
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: isCompact ? 16 : 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Divisor ────────────────────────────────────────────────
              Container(
                height: 1,
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

              const SizedBox(height: 18),

              // ── KPI cards ─────────────────────────────────────────────
              KeyedSubtree(
                key: kpiKey,
                child: Row(
                  children: [
                    Expanded(
                      child: _HeaderKpiCard(
                        icon: Icons.inventory_2_rounded,
                        value: lotesCount,
                        label: 'Lotes',
                        gradientColors: const [
                          Color(0xFF1A56C4),
                          Color(0xFF2F74D0)
                        ],
                        onTap: onLotesTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeaderKpiCard(
                        icon: Icons.warning_rounded,
                        value: critCount,
                        label: 'Vencem 7d',
                        gradientColors: const [
                          Color(0xFFC53030),
                          Color(0xFFE53E3E)
                        ],
                        badge: hasCritical ? critCount : null,
                        onTap: onAlertsTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeaderKpiCard(
                        icon: Icons.schedule_rounded,
                        value: warnCount,
                        label: 'Atenção 30d',
                        gradientColors: const [
                          Color(0xFFB7791F),
                          Color(0xFFD69E2E)
                      ],
                      onTap: onAlertsTap,
                    ),
                  ),
                 ],
               ),
             ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── KPI card dentro do header ─────────────────────────────────────────────

class _HeaderKpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradientColors;
  final String? badge;
  final VoidCallback? onTap;

  const _HeaderKpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradientColors,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Linha 1: ícone + número lado a lado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.productName(
                          size: 26,
                          weight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Linha 2: label maior, contraste melhor
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: gradientColors.first,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
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

class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final color = widget.color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.32 : 0.18),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(
                    alpha: isDark ? 0.18 : (_pressed ? 0.18 : 0.10)),
                blurRadius: _pressed ? 6 : 12,
                offset: Offset(0, _pressed ? 2 : 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Círculo decorativo sutil no canto
              Positioned(
                right: -12,
                top: -12,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: isDark ? 0.10 : 0.06),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Ícone maior centralizado
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              Color.lerp(color, Colors.black, 0.18)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.50),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(widget.icon,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 8),
                      // Label centralizada
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTypography.productName(
                          size: 13.5,
                          weight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedQuickAction extends StatelessWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedQuickAction({
    required this.delayMs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (_, value, c) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

class _AlertBatchTile extends StatelessWidget {
  final dynamic batch;
  const _AlertBatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger600.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.danger600.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded,
              color: AppColors.danger600, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.productName as String,
                  style: AppTypography.labelLarge.copyWith(
                    color: onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Vence em ${batch.daysToExpiry} dia(s) • ${batch.quantity} ${batch.quantity == 1 ? 'un' : 'uns'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.danger600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seção de Previsão de Consumo Prophet no dashboard
// ---------------------------------------------------------------------------

class _ForecastSection extends ConsumerWidget {
  final Key? headerKey;
  const _ForecastSection({this.headerKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topAsync = ref.watch(topReplenishmentForecastsProvider);
    final hasData = ref.watch(hasForecastDataProvider);

    if (!hasData && topAsync is! AsyncLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: headerKey,
            child: CasaSectionHeader(
              title: 'Sugestão de Reposição',
              action: 'Ver tudo',
              onAction: () => context.push(AppRoutes.mlForecast),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const ForecastEmptyState(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          key: headerKey,
          child: CasaSectionHeader(
            title: 'Sugestão de Reposição',
            action: 'Ver tudo',
            onAction: () => context.push(AppRoutes.mlForecast),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        switch (topAsync) {
          AsyncLoading() => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: List.generate(
                  2,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: CasaCardSkeleton(),
                  ),
                ),
              ),
            ),
          AsyncError() => const SizedBox.shrink(),
          AsyncData(value: final forecasts) when forecasts.isEmpty =>
            const SizedBox.shrink(),
          AsyncData(value: final forecasts) => Column(
              children: forecasts
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                      child: ForecastSuggestionCard(
                        forecast: f,
                        onTap: () => context.push(AppRoutes.mlForecast),
                      ),
                    ),
                  )
                  .toList(),
            ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Seção de Risco ML no dashboard
// ---------------------------------------------------------------------------

class _MlRiskSection extends ConsumerWidget {
  final Key? headerKey;
  const _MlRiskSection({this.headerKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(riskCountsProvider);
    final criticalAsync = ref.watch(criticalBatchPredictionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          key: headerKey,
          child: CasaSectionHeader(
            title: 'Análise de Risco ML',
            action: 'Ver detalhes',
            onAction: () => context.push(AppRoutes.mlInsights),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Donut chart + contadores por nível
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: countsAsync.when(
            data: (counts) => _RiskDistributionCard(counts: counts),
            loading: () => Row(
              children: List.generate(
                3,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: CasaCardSkeleton(),
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Top críticos
        criticalAsync.when(
          data: (critical) {
            if (critical.isEmpty) return const SizedBox.shrink();
            return Column(
              children: critical.take(2).map(
                (p) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: RiskInsightCard(
                    prediction: p,
                    onTap: () => context.push(AppRoutes.mlInsights),
                  ),
                ),
              ).toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card de Distribuição de Risco (donut chart + contadores)
// ---------------------------------------------------------------------------

class _RiskDistributionCard extends StatelessWidget {
  final Map<RiskLevel, int> counts;
  const _RiskDistributionCard({required this.counts});

  Color _colorFor(RiskLevel level) {
    switch (level) {
      case RiskLevel.verde:
        return AppColors.success600;
      case RiskLevel.amarelo:
        return AppColors.warning600;
      case RiskLevel.vermelho:
        return AppColors.danger600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = counts.values.fold<int>(0, (s, v) => s + v);

    if (total == 0) {
      return RiskSummaryRow(counts: counts);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Donut chart
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    startDegreeOffset: -90,
                    sections: RiskLevel.values.map((level) {
                      final value = (counts[level] ?? 0).toDouble();
                      final color = _colorFor(level);
                      return PieChartSectionData(
                        color: color,
                        value: value <= 0 ? 0.0001 : value,
                        title: '',
                        radius: 18,
                      );
                    }).toList(),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: AppTypography.headingSmall.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    Text(
                      'lotes',
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Lista lateral com barras proporcionais
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: RiskLevel.values.map((level) {
                final count = counts[level] ?? 0;
                final pct = total == 0 ? 0.0 : count / total;
                final color = _colorFor(level);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    level.label,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$count',
                                  style: AppTypography.labelMedium.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${(pct * 100).toStringAsFixed(0)}%)',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 4,
                                backgroundColor: color.withValues(
                                    alpha: isDark ? 0.15 : 0.10),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seção de Gráficos do Dashboard
// ---------------------------------------------------------------------------

class _DashboardChartsSection extends ConsumerStatefulWidget {
  const _DashboardChartsSection();

  @override
  ConsumerState<_DashboardChartsSection> createState() =>
      _DashboardChartsSectionState();
}

class _DashboardChartsSectionState
    extends ConsumerState<_DashboardChartsSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CasaSectionHeader(
          title: 'Visão Gráfica',
          action: 'Ver relatórios',
          onAction: () => context.push(AppRoutes.reports),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F2444),
                        Color(0xFF1D5FA8)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card - 2),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  tabs: const [
                    Tab(text: 'Categorias'),
                    Tab(text: 'Movimentos'),
                    Tab(text: 'Urgência'),
                  ],
                ),
                SizedBox(
                  height: 240,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _CategoryPieChart(isDark: isDark),
                      _MovementsLineChart(isDark: isDark),
                      _UrgencyBarChart(isDark: isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pie chart: distribution by category ────────────────────────────────────

class _CategoryPieChart extends ConsumerWidget {
  final bool isDark;
  const _CategoryPieChart({required this.isDark});

  static const _colors = [
    Color(0xFF1D5FA8),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(stockByCategoryProvider);
    return categoryAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Center(
          child: Icon(Icons.bar_chart_rounded, size: 40)),
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('Sem dados'));
        }
        final total = categories.fold<int>(0, (s, c) => s + c.totalItems);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 36,
                    sections: List.generate(
                      categories.length,
                      (i) {
                        final cat = categories[i];
                        final color = _colors[i % _colors.length];
                        final pct = total > 0
                            ? (cat.totalItems / total * 100)
                                .toStringAsFixed(0)
                            : '0';
                        return PieChartSectionData(
                          color: color,
                          value: cat.totalItems.toDouble(),
                          title: '$pct%',
                          radius: 48,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    categories.length > 5 ? 5 : categories.length,
                    (i) {
                      final cat = categories[i];
                      final color = _colors[i % _colors.length];
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cat.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Line chart: movements last 30 days ─────────────────────────────────────

class _MovementsLineChart extends ConsumerStatefulWidget {
  final bool isDark;
  const _MovementsLineChart({required this.isDark});

  @override
  ConsumerState<_MovementsLineChart> createState() =>
      _MovementsLineChartState();
}

class _MovementsLineChartState extends ConsumerState<_MovementsLineChart> {
  late final DateTimeRange range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    range = DateTimeRange(
      start: today.subtract(const Duration(days: 29)),
      end: today,
    );
  }

  @override
  Widget build(BuildContext context) {
    final movAsync = ref.watch(movementsReportProvider(range));
    return movAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Center(
          child: Icon(Icons.show_chart_rounded, size: 40)),
      data: (movements) {
        final entriesPerDay = <int, int>{};
        final exitsPerDay = <int, int>{};
        for (final m in movements) {
          final dayKey = m.performedAt.difference(range.start).inDays;
          if (dayKey < 0 || dayKey > 29) continue;
          if (m.type.name == 'entrada') {
            entriesPerDay[dayKey] = (entriesPerDay[dayKey] ?? 0) + m.quantity;
          } else if (m.type.name == 'saida' || m.type.name == 'descarte') {
            exitsPerDay[dayKey] = (exitsPerDay[dayKey] ?? 0) + m.quantity;
          }
        }

        List<FlSpot> entrySpots = [];
        List<FlSpot> exitSpots = [];
        for (int d = 0; d <= 29; d += 5) {
          entrySpots.add(FlSpot(d.toDouble(),
              (entriesPerDay[d] ?? 0).toDouble()));
          exitSpots.add(
              FlSpot(d.toDouble(), (exitsPerDay[d] ?? 0).toDouble()));
        }
        entrySpots.add(FlSpot(29, (entriesPerDay[29] ?? 0).toDouble()));
        exitSpots.add(FlSpot(29, (exitsPerDay[29] ?? 0).toDouble()));

        final allVals = [
          ...entrySpots.map((s) => s.y),
          ...exitSpots.map((s) => s.y),
        ];
        final maxY =
            allVals.isEmpty ? 10.0 : (allVals.reduce((a, b) => a > b ? a : b) + 2);

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(
                      color: AppColors.success600, label: 'Entradas'),
                  const SizedBox(width: 16),
                  _LegendDot(color: AppColors.danger600, label: 'Saídas'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 29,
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.3),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true, reservedSize: 28)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (val, _) {
                            final day = range.start
                                .add(Duration(days: val.toInt()));
                            if (val % 10 != 0 && val != 29) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              '${day.day}/${day.month}',
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: entrySpots,
                        isCurved: true,
                        color: AppColors.success600,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              AppColors.success600.withValues(alpha: 0.08),
                        ),
                      ),
                      LineChartBarData(
                        spots: exitSpots,
                        isCurved: true,
                        color: AppColors.danger600,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              AppColors.danger600.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Bar chart: batches by urgency ──────────────────────────────────────────

class _UrgencyBarChart extends ConsumerWidget {
  final bool isDark;
  const _UrgencyBarChart({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allAvailableBatchesProvider);
    final crit7 = ref.watch(expiringBatchesProvider(7));
    final warn30 = ref.watch(expiringBatchesProvider(30));

    return allAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Center(
          child: Icon(Icons.bar_chart_rounded, size: 40)),
      data: (all) {
        final critCount =
            crit7.maybeWhen(data: (l) => l.length, orElse: () => 0);
        final warnCount = warn30.maybeWhen(
            data: (warnList) {
              final critList = crit7.valueOrNull ?? [];
              return warnList
                  .where((b) => !critList.any((c) => c.id == b.id))
                  .length;
            },
            orElse: () => 0);
        final okCount =
            all.where((b) => b.noExpiry || b.daysToExpiry > 30).length;

        final maxY =
            [critCount, warnCount, okCount].reduce((a, b) => a > b ? a : b);
        final yMax = (maxY + 2).toDouble();

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: yMax,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 28)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, _) {
                      const labels = ['Crítico', 'Atenção', 'OK'];
                      final i = val.toInt();
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(labels[i],
                          style: const TextStyle(fontSize: 11));
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [
                  BarChartRodData(
                    toY: critCount.toDouble(),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC53030), Color(0xFFE53E3E)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 36,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  )
                ]),
                BarChartGroupData(x: 1, barRods: [
                  BarChartRodData(
                    toY: warnCount.toDouble(),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB7791F), Color(0xFFD69E2E)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 36,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  )
                ]),
                BarChartGroupData(x: 2, barRods: [
                  BarChartRodData(
                    toY: okCount.toDouble(),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF276749), Color(0xFF38A169)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 36,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  )
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Legend dot helper ───────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
