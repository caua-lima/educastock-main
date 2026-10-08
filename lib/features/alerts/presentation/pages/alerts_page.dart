import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../ml/domain/entities/risk_prediction.dart';
import '../../../ml/presentation/controllers/risk_classifier_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../controllers/alerts_provider.dart';

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  final _keyAlertCard = GlobalKey();
  final _keyAlertList = GlobalKey();
  final _keyFilters = GlobalKey();

  AlertLevel? _filter; // null = todos
  RiskLevel? _riskFilter; // null = não filtrado por ML

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  Future<void> _runCheck() async {
    final config = ref.read(alertsConfigProvider).valueOrNull;
    if (config == null || !config.expiryEnabled) return;
    try {
      await ref.read(alertsNotifierProvider.notifier).checkAlerts(
            config.criticalDays,
            config.warningDays,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final alertsAsync = ref.watch(activeAlertsProvider);
    final alertsConfig = ref.watch(alertsConfigProvider);

    if (alertsConfig.valueOrNull?.expiryEnabled == false) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Column(children: [
        ModernProfileAppBar(
          title: 'Alertas',
          subtitle: 'Alertas desativados',
          pageIcon: Icons.notifications_off_rounded,
          iconColor: const Color(0xFF94A3B8),
          profileName: user?.name,
          onProfileTap: () => context.push(AppRoutes.settings),
          actions: [
            buildHelpButton(
              context: context,
              onPressed: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyAlertCard,
                    title: 'Alertas de Vencimento',
                    description:
                        'Os alertas mostram produtos próximos do vencimento ou já vencidos. Ative os alertas em Configurações para começar o monitoramento automático.',
                    icon: Icons.notification_important_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      'Vá em Configurações → Alertas para ativar',
                      'Defina quantos dias antes do vencimento você quer ser avisado',
                      'Alertas aparecem também na tela inicial do app',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const Expanded(child: CasaEmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'Alertas desativados',
            description: 'Ative em Configurações → Alertas para monitorar prazos.',
          )),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Notificações',
        pageIcon: Icons.notifications_active_rounded,
        iconColor: const Color(0xFFFBBF24),
        subtitle: alertsAsync.when(
          data: (list) => list.isEmpty
              ? 'Tudo em dia'
              : '${list.length} ${list.length == 1 ? 'alerta ativo' : 'alertas ativos'}',
          loading: () => 'Carregando...',
          error: (_, __) => 'Erro ao carregar',
        ),
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        extraContent: alertsAsync.maybeWhen(
          data: (alerts) {
            if (alerts.isEmpty) return null;
            final counts = _SeverityCounts.from(alerts);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Stats compactas
                Row(
                  children: [
                    _HeaderStatPill(
                      label: 'Críticos',
                      value: counts.critical,
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.danger600,
                    ),
                    const SizedBox(width: 8),
                    _HeaderStatPill(
                      label: 'Atenção',
                      value: counts.warning,
                      icon: Icons.schedule_rounded,
                      color: AppColors.warning600,
                    ),
                    const SizedBox(width: 8),
                    _HeaderStatPill(
                      label: 'Info',
                      value: counts.info,
                      icon: Icons.info_outline_rounded,
                      color: AppColors.brandPrimary600,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Filtros chips
                KeyedSubtree(
                  key: _keyFilters,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _HeaderFilterChip(
                          label: 'Todos',
                          selected: _filter == null,
                          color: Colors.white,
                          onTap: () => setState(() => _filter = null),
                        ),
                        const SizedBox(width: 6),
                        _HeaderFilterChip(
                          label: 'Críticos (${counts.critical})',
                          selected: _filter == AlertLevel.critical,
                          color: AppColors.danger600,
                          onTap: () => setState(() => _filter =
                              _filter == AlertLevel.critical
                                  ? null
                                  : AlertLevel.critical),
                        ),
                        const SizedBox(width: 6),
                        _HeaderFilterChip(
                          label: 'Atenção (${counts.warning})',
                          selected: _filter == AlertLevel.warning,
                          color: AppColors.warning600,
                          onTap: () => setState(() => _filter =
                              _filter == AlertLevel.warning
                                  ? null
                                  : AlertLevel.warning),
                        ),
                        const SizedBox(width: 6),
                        _HeaderFilterChip(
                          label: 'Info (${counts.info})',
                          selected: _filter == AlertLevel.info,
                          color: AppColors.brandPrimary600,
                          onTap: () => setState(() => _filter =
                              _filter == AlertLevel.info
                                  ? null
                                  : AlertLevel.info),
                        ),
                        // ─── Separador visual ──────────────────────────────
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          height: 22,
                          width: 1,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        // ─── Filtros por Risco ML ───────────────────────────
                        _HeaderFilterChip(
                          label: '🤖 Risco Crítico',
                          selected: _riskFilter == RiskLevel.vermelho,
                          color: AppColors.danger600,
                          onTap: () => setState(() => _riskFilter =
                              _riskFilter == RiskLevel.vermelho
                                  ? null
                                  : RiskLevel.vermelho),
                        ),
                        const SizedBox(width: 6),
                        _HeaderFilterChip(
                          label: '🤖 Atenção',
                          selected: _riskFilter == RiskLevel.amarelo,
                          color: AppColors.warning600,
                          onTap: () => setState(() => _riskFilter =
                              _riskFilter == RiskLevel.amarelo
                                  ? null
                                  : RiskLevel.amarelo),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          orElse: () => null,
        ),
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyAlertCard,
                  title: 'Card de Alerta',
                  description:
                      'Cada cartão alerta sobre um produto com validade próxima ou vencida. Mostra: ícone de urgência, nome do produto, mensagem (quantos dias para vencer) e horário de geração. A cor indica criticidade.',
                  icon: Icons.notification_important_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🔴 Vermelho (crítico): vence em até 7 dias',
                    '🟡 Amarelo (atenção): vence em até 30 dias',
                    '🔵 Azul (info): alertas manuais customizados',
                    '👆 Toque longo para ver ações (distribuir, ver produto)',
                  ],
                ),
                TutorialStep(
                  key: _keyFilters,
                  title: 'Filtros por Urgência',
                  description:
                      'Os chips coloridos no topo são filtros rápidos por nível de urgência. Cada chip mostra a contagem da categoria. Toque para filtrar; toque novamente para limpar.',
                  icon: Icons.filter_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '👆 1 toque: ativa o filtro',
                    '👆 2 toques: limpa o filtro',
                    '🔢 Número no chip = quantos alertas naquela categoria',
                  ],
                ),
                TutorialStep(
                  key: _keyAlertList,
                  title: 'Lista Priorizada',
                  description:
                      'Todos os alertas ativos em ordem de urgência (mais críticos primeiro). Arraste para a esquerda para excluir um alerta. Toque longo abre o menu de ações.',
                  icon: Icons.list_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '👈 Arrastar para esquerda = excluir',
                    '👇 Toque longo = mais ações (distribuir, abrir produto)',
                    '📊 Lista atualiza automaticamente quando estoque muda',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: alertsAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar alertas',
            description: e.toString(),
          ),
          data: (alerts) {
            if (alerts.isEmpty) {
              return _EmptyAllClear(cs: cs);
            }

            var filtered = _filter == null
                ? alerts
                : alerts.where((a) => a.level == _filter).toList();

            // Filtro ML — cruza com batchRiskPredictionsProvider
            if (_riskFilter != null) {
              final predictions =
                  ref.watch(batchRiskPredictionsProvider).valueOrNull ??
                      const [];
              final riskByBatch = <String, RiskLevel>{
                for (final p in predictions) p.batchId: p.level,
              };
              filtered = filtered
                  .where((a) =>
                      a.batchId != null &&
                      riskByBatch[a.batchId] == _riskFilter)
                  .toList();
            }

            return CustomScrollView(
              slivers: [
                // ── Lista ────────────────────────────────────────
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyForFilter(level: _filter, cs: cs),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final card = _ModernAlertCard(
                          alert: filtered[i],
                          cs: cs,
                          onOpenActions: () => _showActionsSheet(filtered[i]),
                        );
                        if (i == 0) {
                          return KeyedSubtree(key: _keyAlertCard, child: card);
                        }
                        if (i == 1) {
                          return KeyedSubtree(key: _keyAlertList, child: card);
                        }
                        return card;
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAlertSheet(context),
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Alerta manual'),
        tooltip: 'Criar alerta manual',
      ),
    );
  }

  // ─── Ações ──────────────────────────────────────────────────────────────

  Future<void> _showActionsSheet(StockAlert alert) async {
    final color = _colorForLevel(alert.level);
    final hasBatch = alert.batchId != null && alert.batchId!.isNotEmpty;
    final isCritical = alert.level == AlertLevel.critical;

    final actions = <CasaSheetItem>[
      // Ação primária: distribuir/descartar (quando há lote)
      if (hasBatch)
        CasaSheetItem(
          icon: Icons.output_rounded,
          label: isCritical ? 'Registrar descarte' : 'Distribuir lote',
          subtitle: isCritical
              ? 'Marcar saída por vencimento'
              : 'Ir para Saída com o produto selecionado',
          color: AppColors.brandPrimary600,
          onTap: () => context.push(
            '${AppRoutes.movement}'
            '?batchId=${alert.batchId}'
            '&productId=${alert.productId}'
            '&reason=${isCritical ? "validade" : "uso"}',
          ),
        ),
      // Ver produto (quando não é manual)
      if (!alert.isManual)
        CasaSheetItem(
          icon: Icons.inventory_2_rounded,
          label: 'Ver produto',
          subtitle: 'Detalhes e todos os lotes',
          color: AppColors.brandPrimary600,
          onTap: () => context.push('/products/${alert.productId}'),
        ),
      // Excluir (destrutivo)
      CasaSheetItem(
        icon: Icons.delete_outline_rounded,
        label: 'Excluir alerta',
        destructive: true,
        onTap: () => _deleteAlert(alert),
      ),
    ];

    await showCasaActionSheet(
      context: context,
      title: alert.productName,
      subtitle: '${_levelHeaderLabel(alert.level)} · ${_relativeTime(alert.createdAt)}',
      headerColor: color,
      headerIcon: _iconForLevel(alert.level),
      actions: actions,
    );
  }

  Future<void> _deleteAlert(StockAlert alert) async {
    final ok = await CasaDialogConfirmacao.show(
      context: context,
      title: 'Excluir alerta?',
      message: 'Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
      isDanger: true,
    );
    if (ok != true || !mounted) return;
    try {
      HapticFeedback.mediumImpact();
      await ref.read(alertsNotifierProvider.notifier).delete(alert.id);
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Alerta excluído.', isSuccess: true);
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Erro ao excluir alerta.', isError: true);
    }
  }

  // ─── Criação manual ─────────────────────────────────────────────────────

  Future<void> _showCreateAlertSheet(BuildContext context) async {
    final nameController = TextEditingController();
    final msgController = TextEditingController();
    AlertLevel selectedLevel = AlertLevel.warning;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // acima da TabBar
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: const Icon(Icons.add_alert_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text('Criar Alerta Manual',
                        style: AppTypography.headingSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Produto / Descrição',
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Ex: Arroz, Feijão…',
                    prefixIcon: const Icon(Icons.inventory_2_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Nível de urgência',
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: AlertLevel.values.map((lvl) {
                    final color = _colorForLevel(lvl);
                    final label = switch (lvl) {
                      AlertLevel.critical => '🔴 Crítico',
                      AlertLevel.warning => '🟡 Atenção',
                      AlertLevel.info => '🔵 Info',
                    };
                    return ChoiceChip(
                      label: Text(label),
                      selected: selectedLevel == lvl,
                      selectedColor: color.withValues(alpha: 0.18),
                      onSelected: (_) => setModal(() => selectedLevel = lvl),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Mensagem',
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: msgController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Descreva o motivo do alerta…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_alert_rounded, size: 18),
                        label: const Text('Criar alerta'),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final msg = msgController.text.trim();
                          if (name.isEmpty || msg.isEmpty) {
                            showCasaSnackbar(ctx,
                                message: 'Preencha todos os campos.',
                                isError: true);
                            return;
                          }
                          Navigator.pop(ctx);
                          try {
                            await ref
                                .read(alertsNotifierProvider.notifier)
                                .createManualAlert(
                                  productName: name,
                                  level: selectedLevel,
                                  message: msg,
                                );
                            if (!context.mounted) return;
                            showCasaSnackbar(context,
                                message: 'Alerta criado com sucesso!',
                                isSuccess: true);
                          } catch (e) {
                            if (!context.mounted) return;
                            showCasaSnackbar(context,
                                message: 'Erro ao criar alerta.',
                                isError: true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    nameController.dispose();
    msgController.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers visuais
// ═══════════════════════════════════════════════════════════════════════════

Color _colorForLevel(AlertLevel lvl) => switch (lvl) {
      AlertLevel.critical => AppColors.danger600,
      AlertLevel.warning => AppColors.warning600,
      AlertLevel.info => AppColors.brandPrimary600,
    };

IconData _iconForLevel(AlertLevel lvl) => switch (lvl) {
      AlertLevel.critical => Icons.warning_amber_rounded,
      AlertLevel.warning => Icons.schedule_rounded,
      AlertLevel.info => Icons.info_outline_rounded,
    };

String _labelForLevel(AlertLevel lvl) => switch (lvl) {
      AlertLevel.critical => 'Críticos',
      AlertLevel.warning => 'Atenção',
      AlertLevel.info => 'Info',
    };

String _levelHeaderLabel(AlertLevel lvl) => switch (lvl) {
      AlertLevel.critical => 'Crítico',
      AlertLevel.warning => 'Atenção',
      AlertLevel.info => 'Informativo',
    };

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return 'há $m min';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'há $h ${h == 1 ? "hora" : "horas"}';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return 'há $d ${d == 1 ? "dia" : "dias"}';
  }
  if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    return 'há $w ${w == 1 ? "semana" : "semanas"}';
  }
  final months = (diff.inDays / 30).floor();
  return 'há $months ${months == 1 ? "mês" : "meses"}';
}

// ═══════════════════════════════════════════════════════════════════════════
// Stats banner
// ═══════════════════════════════════════════════════════════════════════════

class _SeverityCounts {
  final int critical;
  final int warning;
  final int info;
  const _SeverityCounts(this.critical, this.warning, this.info);

  int get total => critical + warning + info;

  factory _SeverityCounts.from(List<StockAlert> list) {
    var c = 0, w = 0, i = 0;
    for (final a in list) {
      switch (a.level) {
        case AlertLevel.critical:
          c++;
        case AlertLevel.warning:
          w++;
        case AlertLevel.info:
          i++;
      }
    }
    return _SeverityCounts(c, w, i);
  }

  int countFor(AlertLevel lvl) => switch (lvl) {
        AlertLevel.critical => critical,
        AlertLevel.warning => warning,
        AlertLevel.info => info,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// Widgets compactos para uso no header (fundo gradiente escuro)
// ═══════════════════════════════════════════════════════════════════════════

class _HeaderStatPill extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _HeaderStatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0.16),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      height: 1,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _HeaderFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _HeaderFilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [color, color.withValues(alpha: 0.75)])
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Card moderno
// ═══════════════════════════════════════════════════════════════════════════

class _ModernAlertCard extends ConsumerWidget {
  final StockAlert alert;
  final ColorScheme cs;
  final VoidCallback onOpenActions;

  const _ModernAlertCard({
    required this.alert,
    required this.cs,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorForLevel(alert.level);
    final icon = _iconForLevel(alert.level);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey('alert-${alert.id}'),
      // Só permite arrastar da direita para esquerda = excluir
      direction: DismissDirection.endToStart,
      background: _SwipeBg(
        align: Alignment.centerRight,
        color: AppColors.danger600,
        icon: Icons.delete_forever_rounded,
        label: 'Excluir',
      ),
      confirmDismiss: (direction) async {
        final ok = await CasaDialogConfirmacao.show(
          context: context,
          title: 'Excluir alerta?',
          message: 'Esta ação não pode ser desfeita.',
          confirmLabel: 'Excluir',
          isDanger: true,
        );
        if (ok != true) return false;
        try {
          HapticFeedback.mediumImpact();
          await ref.read(alertsNotifierProvider.notifier).delete(alert.id);
          if (context.mounted) {
            showCasaSnackbar(context,
                message: 'Alerta excluído.', isSuccess: true);
          }
          return true;
        } catch (_) {
          if (context.mounted) {
            showCasaSnackbar(context,
                message: 'Erro ao excluir.', isError: true);
          }
          return false;
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.modal),
          onTap: alert.isManual
              ? onOpenActions
              : () {
                  HapticFeedback.selectionClick();
                  context.push('/products/${alert.productId}');
                },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onOpenActions();
          },
          child: Ink(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.modal),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.35 : 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Barra vertical de cor (gradiente)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.55)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.modal),
                        bottomLeft: Radius.circular(AppRadius.modal),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(AppSpacing.md + 4, AppSpacing.md, 4, AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícone em badge gradiente
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.95),
                              color.withValues(alpha: 0.55),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Conteúdo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    alert.productName,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _LevelPill(level: alert.level, color: color),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alert.message,
                              style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 12,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  _relativeTime(alert.createdAt),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                if (!alert.isManual) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Icon(Icons.touch_app_outlined,
                                      size: 12,
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ver produto',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Menu (3 pontos)
                      IconButton(
                        tooltip: 'Mais ações',
                        icon: Icon(Icons.more_vert_rounded,
                            color: cs.onSurfaceVariant),
                        onPressed: onOpenActions,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final AlertLevel level;
  final Color color;
  const _LevelPill({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (level) {
      AlertLevel.critical => 'CRÍTICO',
      AlertLevel.warning => 'ATENÇÃO',
      AlertLevel.info => 'INFO',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Alignment align;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBg({
    required this.align,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.85), color],
          begin: align == Alignment.centerLeft
              ? Alignment.centerLeft
              : Alignment.centerRight,
          end: align == Alignment.centerLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      alignment: align,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty states
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyAllClear extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyAllClear({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success600.withValues(alpha: 0.18),
                    AppColors.success600.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: AppColors.success600),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tudo em dia!',
              style: AppTypography.headingMedium.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nenhum produto com validade próxima.\nVocê está no controle.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyForFilter extends StatelessWidget {
  final AlertLevel? level;
  final ColorScheme cs;
  const _EmptyForFilter({required this.level, required this.cs});

  @override
  Widget build(BuildContext context) {
    final color = level == null
        ? AppColors.success600
        : _colorForLevel(level!);
    final label =
        level == null ? 'tudo em dia' : 'nenhum em ${_labelForLevel(level!).toLowerCase()}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded,
                size: 48, color: color.withValues(alpha: 0.65)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sem alertas — $label',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
