import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/system_settings_provider.dart';

class AlertsSettingsPage extends ConsumerStatefulWidget {
  const AlertsSettingsPage({super.key});

  @override
  ConsumerState<AlertsSettingsPage> createState() => _AlertsSettingsPageState();
}

class _AlertsSettingsPageState extends ConsumerState<AlertsSettingsPage> {
  final _criticalCtrl = TextEditingController();
  final _warningCtrl = TextEditingController();
  bool _expiryEnabled = true;
  bool _silentModeEnabled = false;
  TimeOfDay _silentFrom = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _silentUntil = const TimeOfDay(hour: 7, minute: 0);
  bool _initialized = false;
  final _keyExpirySwitch = GlobalKey();
  final _keyCriticalField = GlobalKey();
  final _keyWarningField = GlobalKey();
  final _keySilentMode = GlobalKey();

  @override
  void dispose() {
    _criticalCtrl.dispose();
    _warningCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String? s, TimeOfDay fallback) {
    if (s == null) return fallback;
    final parts = s.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? fallback.hour,
        minute: int.tryParse(parts[1]) ?? fallback.minute);
  }

  Future<void> _pickTime(bool isFrom) async {
    final initial = isFrom ? _silentFrom : _silentUntil;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isFrom ? 'Início do silêncio' : 'Fim do silêncio',
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _silentFrom = picked;
        } else {
          _silentUntil = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    ref.watch(alertsConfigNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final configState = ref.watch(alertsConfigProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Alertas',
        subtitle: 'Regras de vencimento',
        pageIcon: Icons.notifications_active_rounded,
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
                  key: _keyExpirySwitch,
                  title: 'Ligar / Desligar Alertas',
                  description: 'Este switch principal liga ou desliga todo o sistema de monitoramento de validade. Quando desligado, nenhum alerta é gerado nem enviado — útil para período de baixa atividade ou ajustes de configuração.',
                  icon: Icons.notifications_active_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Recomendado: SEMPRE ligado em produção',
                    'Quando desligado, a tela de Alertas fica vazia',
                    'Ideal para férias coletivas ou testes',
                    'Sem alertas = risco de produtos vencerem sem aviso',
                  ],
                ),
                TutorialStep(
                  key: _keyCriticalField,
                  title: 'Prazo Crítico (vermelho)',
                  description: 'Define em quantos dias antes do vencimento o produto entra na faixa CRÍTICA (vermelha). Itens nesta faixa exigem ação imediata: distribuir, doar ou descartar. Aparecem em destaque no dashboard.',
                  icon: Icons.emergency_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🟥 Recomendado: 7 dias para alimentos frescos',
                    '🟥 14 dias para refrigerados/laticínios',
                    'Quanto menor o número, mais urgente o alerta',
                    'Aparece no card vermelho do dashboard',
                  ],
                ),
                TutorialStep(
                  key: _keyWarningField,
                  title: 'Prazo de Atenção (amarelo)',
                  description: 'Define em quantos dias antes do vencimento o produto entra na faixa ATENÇÃO (amarela). Esta faixa é para planejamento — você ainda tem tempo de organizar uma distribuição antes que vire crítico.',
                  icon: Icons.warning_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🟨 Recomendado: 30 dias para planejamento',
                    '🟨 60 dias se a rotação for lenta',
                    'Deve ser MAIOR que o prazo crítico',
                    'Aparece no card amarelo do dashboard',
                  ],
                ),
                TutorialStep(
                  key: _keySilentMode,
                  title: 'Modo Silencioso',
                  description: 'Define um intervalo de horas em que nenhuma notificação push é enviada (mas os alertas continuam sendo registrados). Útil para não incomodar a equipe fora do horário de trabalho.',
                  icon: Icons.bedtime_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Padrão sugerido: 22h às 7h (durante o sono)',
                    'Os alertas ainda aparecem na tela ao abrir o app',
                    'Só silencia notificações push do celular',
                    'Use horário comercial inverso para sua ONG',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: configState.when(
          data: (config) {
            if (!_initialized) {
              _criticalCtrl.text = config.criticalDays.toString();
              _warningCtrl.text = config.warningDays.toString();
              _expiryEnabled = config.expiryEnabled;
              _silentModeEnabled = config.silentModeEnabled;
              _silentFrom =
                  _parseTime(config.silentFrom, const TimeOfDay(hour: 22, minute: 0));
              _silentUntil =
                  _parseTime(config.silentUntil, const TimeOfDay(hour: 7, minute: 0));
              _initialized = true;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                // ─── Banner informativo
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandPrimary600.withValues(alpha: 0.08),
                        AppColors.brandPrimary600.withValues(alpha: 0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                        color: AppColors.brandPrimary600.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary100,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Icon(Icons.notifications_active_rounded,
                            color: AppColors.brandPrimary600, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sistema de alertas',
                                style: AppTypography.labelMedium
                                    .copyWith(color: cs.onSurface,
                                        fontWeight: FontWeight.w700)),
                            Text(
                              'Configure os prazos que ativam notificações de vencimento.',
                              style: AppTypography.bodySmall
                                  .copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ─── Card principal
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6),
                    ],
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle ativo/inativo
                      Row(
                        key: _keyExpirySwitch,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _expiryEnabled
                                  ? AppColors.success600.withValues(alpha: 0.1)
                                  : cs.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.small),
                            ),
                            child: Icon(Icons.notifications_outlined,
                                color: _expiryEnabled
                                    ? AppColors.success600
                                    : cs.onSurfaceVariant,
                                size: 20),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alerta por vencimento',
                                    style: AppTypography.labelLarge
                                        .copyWith(color: cs.onSurface)),
                                Text(
                                  _expiryEnabled ? 'Ativo' : 'Inativo',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: _expiryEnabled
                                        ? AppColors.success600
                                        : cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _expiryEnabled,
                            onChanged: (v) =>
                                setState(() => _expiryEnabled = v),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Divider(height: 1),
                      ),

                      // Dias crítico
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: AppColors.danger600,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Prazo crítico',
                              style: AppTypography.labelMedium
                                  .copyWith(color: cs.onSurface)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      CasaTextField(
                        key: _keyCriticalField,
                        label: 'Dias para alerta crítico',
                        hint: 'Ex: 7',
                        controller: _criticalCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.warning_rounded,
                            size: 18, color: AppColors.danger600),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Dias atenção
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: AppColors.warning600,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Prazo de atenção',
                              style: AppTypography.labelMedium
                                  .copyWith(color: cs.onSurface)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      CasaTextField(
                        key: _keyWarningField,
                        label: 'Dias para alerta de atenção',
                        hint: 'Ex: 30',
                        controller: _warningCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.schedule_rounded,
                            size: 18, color: AppColors.warning600),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      CasaButton(
                        label: 'Salvar configurações',
                        icon: Icons.save_rounded,
                        onPressed: () async {
                          final critical =
                              int.tryParse(_criticalCtrl.text.trim());
                          final warning =
                              int.tryParse(_warningCtrl.text.trim());

                          if (critical == null || warning == null) {
                            showCasaSnackbar(context,
                                message: 'Preencha os dias com números válidos.',
                                isError: true);
                            return;
                          }
                          if (critical <= 0 ||
                              warning <= 0 ||
                              warning <= critical) {
                            showCasaSnackbar(context,
                                message:
                                    'Atenção deve ser maior que crítico e ambos maiores que zero.',
                                isError: true);
                            return;
                          }

                          await ref
                              .read(alertsConfigNotifierProvider.notifier)
                              .save(AlertsConfig(
                                criticalDays: critical,
                                warningDays: warning,
                                expiryEnabled: _expiryEnabled,
                                silentModeEnabled: _silentModeEnabled,
                                silentFrom: _formatTime(_silentFrom),
                                silentUntil: _formatTime(_silentUntil),
                              ));
                          if (!context.mounted) return;
                          showCasaSnackbar(context,
                              message: 'Configurações salvas!',
                              isSuccess: true);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ─── Modo silencioso ─────────────────────────────────────────
                Container(
                  key: _keySilentMode,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6),
                    ],
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _silentModeEnabled
                                  ? AppColors.secondarySky500.withValues(alpha: 0.12)
                                  : cs.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.small),
                            ),
                            child: Icon(
                              Icons.bedtime_rounded,
                              color: _silentModeEnabled
                                  ? AppColors.secondarySky500
                                  : cs.onSurfaceVariant,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Horário de silêncio',
                                    style: AppTypography.labelLarge
                                        .copyWith(color: cs.onSurface)),
                                Text(
                                  'Suspende notificações em horários específicos',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _silentModeEnabled,
                            onChanged: (v) =>
                                setState(() => _silentModeEnabled = v),
                            activeColor: AppColors.secondarySky500,
                          ),
                        ],
                      ),
                      if (_silentModeEnabled) ...[
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Divider(height: 1),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _TimeTile(
                                label: 'Início',
                                icon: Icons.nights_stay_rounded,
                                iconColor: AppColors.secondarySky500,
                                time: _silentFrom,
                                onTap: () => _pickTime(true),
                                cs: cs,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _TimeTile(
                                label: 'Fim',
                                icon: Icons.wb_twilight_rounded,
                                iconColor: AppColors.warning600,
                                time: _silentUntil,
                                onTap: () => _pickTime(false),
                                cs: cs,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color:
                                AppColors.secondarySky500.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  size: 14, color: AppColors.secondarySky500),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  'Notificações serão suprimidas de '
                                  '${_formatTime(_silentFrom)} às ${_formatTime(_silentUntil)}. '
                                  'Suporta horários que cruzam a meia-noite.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.secondarySky500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Faixas de urgência',
                          style: AppTypography.labelMedium
                              .copyWith(color: cs.onSurface)),
                      const SizedBox(height: AppSpacing.sm),
                      _UrgencyRow(
                          color: AppColors.danger600,
                          label:
                              'Crítico — 0 a ${_criticalCtrl.text.isEmpty ? '?' : _criticalCtrl.text} dias',
                          icon: Icons.warning_rounded),
                      const SizedBox(height: AppSpacing.xs),
                      _UrgencyRow(
                          color: AppColors.warning600,
                          label:
                              'Atenção — até ${_warningCtrl.text.isEmpty ? '?' : _warningCtrl.text} dias',
                          icon: Icons.schedule_rounded),
                      const SizedBox(height: AppSpacing.xs),
                      _UrgencyRow(
                          color: AppColors.success600,
                          label: 'OK — acima do prazo de atenção',
                          icon: Icons.check_circle_outline_rounded),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar configurações',
            description: e.toString(),
          ),
        ),
      ),
      ]),
    );
  }
}

class _UrgencyRow extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;
  const _UrgencyRow(
      {required this.color, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppTypography.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final TimeOfDay time;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _TimeTile({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.time,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final display =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: AppSpacing.xs),
                Text(label,
                    style: AppTypography.labelSmall
                        .copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(display,
                style: AppTypography.headingSmall.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
