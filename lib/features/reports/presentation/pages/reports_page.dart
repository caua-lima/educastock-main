import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../../core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import '../../../ml/presentation/controllers/risk_classifier_provider.dart';
import '../../../ml/domain/entities/risk_prediction.dart';
import '../../../ml/presentation/widgets/risk_widgets.dart';
import '../../../ml/presentation/controllers/consumption_forecast_provider.dart';
import '../../../ml/domain/entities/consumption_forecast.dart';
import '../../../ml/presentation/widgets/forecast_widgets.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';

import '../controllers/reports_provider.dart';
import '../../../stock/domain/entities/stock_movement.dart';

// ─── Gradient shared with ModernProfileAppBar ────────────────────────────
const _kReportsGradient = LinearGradient(
  colors: [Color(0xFF0F2444), Color(0xFF1A3A6B), Color(0xFF1D5FA8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final _keyTrendChart = GlobalKey();
final _keyExpiryChart = GlobalKey();
final _keyCategoryChart = GlobalKey();

// ─── Tutorial keys – Risk tab ─────────────────────────────────────────────
final _keyRiskBanner = GlobalKey();
final _keyRiskDonut = GlobalKey();

// ─── Tutorial keys – Movements tab ───────────────────────────────────────
final _keyMovSummary = GlobalKey();
final _keyMovChart = GlobalKey();
final _keyMovList = GlobalKey();

// ─── Tutorial keys – Forecast tab ────────────────────────────────────────
final _keyForecastKpi = GlobalKey();
final _keyForecastCoverage = GlobalKey();
final _keyForecastReplenish = GlobalKey();

// ─── Tutorial steps por aba (centralizado para o header tab-aware) ──────
List<TutorialStep> _chartsTutorialSteps() => [
      TutorialStep(
        key: _keyTrendChart,
        title: 'Tendência Mensal de Entrada',
        description:
            'Gráfico de linha com entradas nos últimos 6 meses. Identifique padrões sazonais.',
        icon: Icons.show_chart_rounded,
        align: ContentAlign.bottom,
        hints: const [
          'Toque nos pontos para ver o valor exato',
          'Picos = meses com grande volume de doações',
        ],
      ),
      TutorialStep(
        key: _keyExpiryChart,
        title: 'Distribuição por Prazo',
        description:
            'Barras mostrando quantos lotes estão em cada faixa de vencimento.',
        icon: Icons.bar_chart_rounded,
        align: ContentAlign.bottom,
        hints: const [
          '🔴 Vermelho = vencidos — descarte imediato',
          '🟢 Verde = prazo seguro (>30 dias)',
        ],
      ),
      TutorialStep(
        key: _keyCategoryChart,
        title: 'Lotes por Origem',
        description:
            'Pizza mostrando proporção de lotes por origem (doação, compra, etc.).',
        icon: Icons.pie_chart_rounded,
        align: ContentAlign.bottom,
        hints: const ['Toque em cada fatia para ver o percentual'],
      ),
    ];

List<TutorialStep> _riskTutorialSteps() => [
      TutorialStep(
        key: _keyRiskBanner,
        title: 'Saúde do Estoque',
        description:
            'Painel com totais de lotes críticos, em atenção e seguros. Quanto mais verde, melhor a situação.',
        icon: Icons.shield_rounded,
        align: ContentAlign.bottom,
        hints: const [
          '🔴 Críticos = ação imediata necessária',
          '🟡 Atenção = monitorar de perto nos próximos dias',
        ],
      ),
      TutorialStep(
        key: _keyRiskDonut,
        title: 'Distribuição por Risco',
        description:
            'Gráfico de rosca mostrando a proporção dos lotes em cada nível de risco. Ideal ter >70% verde.',
        icon: Icons.pie_chart_rounded,
        align: ContentAlign.bottom,
        hints: const [
          'Toque nas fatias para ver quantidade e %',
          'Vermelho alto? Execute o Colab para redistribuição urgente',
        ],
      ),
    ];

List<TutorialStep> _movementsTutorialSteps() => [
      TutorialStep(
        key: _keyMovSummary,
        title: 'Resumo do Período',
        description:
            'Saldo líquido do período: entradas menos saídas e descartes. Verde = estoque cresceu, vermelho = diminuiu.',
        icon: Icons.summarize_rounded,
        align: ContentAlign.bottom,
        hints: const [
          'Alterne o período para comparar meses diferentes',
          'Saldo negativo pode indicar distribuição alta — ótimo sinal!',
        ],
      ),
      TutorialStep(
        key: _keyMovChart,
        title: 'Entradas × Saídas',
        description:
            'Comparativo visual por período. Verde = entradas no estoque; vermelho = saídas e descartes.',
        icon: Icons.bar_chart_rounded,
        align: ContentAlign.bottom,
        hints: const [
          'Toque nas barras para ver o valor exato',
          'Saídas altas em período curto = distribuição ativa',
        ],
      ),
      TutorialStep(
        key: _keyMovList,
        title: 'Histórico de Movimentações',
        description:
            'Lista completa agrupada por data. Use os filtros para visualizar apenas entradas, saídas ou descartes.',
        icon: Icons.list_alt_rounded,
        align: ContentAlign.top,
        hints: const [
          'Filtros de tipo na barra superior',
          'Toque em "Ver mais" para carregar o histórico completo',
        ],
      ),
    ];

List<TutorialStep> _forecastTutorialSteps() => [
      TutorialStep(
        key: _keyForecastKpi,
        title: 'KPIs de Previsão',
        description:
            'Resumo rápido: quantos produtos precisam repor, quantos estão em risco crítico, e o total de unidades sugeridas.',
        icon: Icons.dashboard_rounded,
        align: ContentAlign.bottom,
        hints: const [
          '🔴 Críticos = estoque muito baixo para consumo previsto',
          '📦 Reposição = toque em "Gerar Pedido" para exportar CSV',
        ],
      ),
      TutorialStep(
        key: _keyForecastCoverage,
        title: 'Cobertura de Estoque',
        description:
            'Barras azuis = estoque atual; barras verdes = consumo previsto para 30 dias. Se azul < verde, precisa repor.',
        icon: Icons.bar_chart_rounded,
        align: ContentAlign.bottom,
        hints: const [
          'Produtos sem barra azul têm estoque zerado',
          'Use essa visualização para planejar compras mensais',
        ],
      ),
      TutorialStep(
        key: _keyForecastReplenish,
        title: 'Lista de Reposição',
        description:
            'Produtos ordenados por urgência com a quantidade sugerida de compra. Exporte em CSV ou envie para fornecedores.',
        icon: Icons.add_shopping_cart_rounded,
        align: ContentAlign.top,
        hints: const [
          'Toque "Gerar Pedido" para exportar a lista',
          'Treinar o modelo regularmente no Colab melhora as previsões',
        ],
      ),
    ];

/// Retorna os passos do tutorial conforme a aba ativa do reports.
List<TutorialStep> _reportsTutorialForTab(int index) {
  switch (index) {
    case 0:
      return _chartsTutorialSteps();
    case 1:
      return _riskTutorialSteps();
    case 2:
      return _movementsTutorialSteps();
    case 3:
      return _forecastTutorialSteps();
    default:
      return _chartsTutorialSteps();
  }
}

Future<void> _exportCsv({
  required BuildContext context,
  required List<Batch> allBatches,
  required List<Batch> expiring30,
}) async {
  final buffer = StringBuffer();
  buffer.writeln('Produto,Quantidade,Validade,Dias para vencer,Origem,Status');
  final fmt = DateFormat('dd/MM/yyyy');
  for (final b in allBatches) {
    final validade =
        b.expiryDate != null ? fmt.format(b.expiryDate!) : 'Sem validade';
    final dias = b.noExpiry ? 'Sem val.' : '${b.daysToExpiry}';
    buffer.writeln([
      '"${b.productName.replaceAll('"', '""')}"',
      '${b.quantity}',
      '"$validade"',
      dias,
      '"${b.origin.replaceAll('"', '""')}"',
    ].join(','));
  }
  buffer.writeln('');
  buffer.writeln('Total de lotes,${allBatches.length}');
  buffer.writeln('Vencendo em 30 dias,${expiring30.length}');

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/relatorio_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(buffer.toString());
  await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
      text: 'Relatório EducastStock (CSV)');
  if (!context.mounted) return;
  showCasaSnackbar(context,
      message: 'Relatório CSV gerado!', isSuccess: true);
}

Future<void> _exportPdf({
  required List<Batch> allBatches,
  required List<Batch> expiring7,
  required List<Batch> expiring30,
}) async {
  final doc = pw.Document();
  final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  final total =
      allBatches.fold<int>(0, (s, b) => s + b.quantity);
  doc.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text('Relatório EducastStock',
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Gerado em: $now'),
        pw.SizedBox(height: 16),
        pw.Bullet(text: 'Lotes disponíveis: ${allBatches.length}'),
        pw.Bullet(text: 'Itens em estoque: $total'),
        pw.Bullet(text: 'Críticos (≤7 dias): ${expiring7.length}'),
        pw.Bullet(text: 'Atenção (≤30 dias): ${expiring30.length}'),
        pw.SizedBox(height: 16),
        pw.Text('Próximos a vencer',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Produto', 'Validade', 'Dias'],
          data: expiring30.take(15).map((b) {
            final date = b.expiryDate != null
                ? DateFormat('dd/MM/yyyy').format(b.expiryDate!)
                : '-';
            return [b.productName, date, b.noExpiry ? 'Sem val.' : '${b.daysToExpiry}'];
          }).toList(),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

// ─── Custom AppBar with TabBar ────────────────────────────────────────────

class _ReportsAppBar extends ConsumerWidget {
  final List<Widget>? actions;
  const _ReportsAppBar({this.actions});

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Container(
        decoration: const BoxDecoration(gradient: _kReportsGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header row ─────────────────────────────────────────────
              SizedBox(
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: [
                      // ── Ícone com glow estilo dashboard ──
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.20),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.analytics_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      // ── Barra lateral branca + título ──
                      Container(
                        width: 3.5,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.white.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Relatórios',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                shadows: [
                                  Shadow(
                                    color: Color(0x66000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Análise e tendências do estoque',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Actions extras (export, etc) ──
                      if (actions != null) ...actions!,
                      // ── Sino de alertas ──
                      CasaAlertsBellButton(
                        alertCount: alertCount,
                        onDarkBg: true,
                      ),
                      // ── Toggle dark/light ──
                      const Padding(
                        padding: EdgeInsets.only(left: AppSpacing.xs),
                        child: CasaThemeToggleButton(),
                      ),
                      // ── Avatar de perfil ──
                      if (user?.name != null) ...[
                        const SizedBox(width: AppSpacing.xs),
                        GestureDetector(
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
                                user!.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // ── TabBar ─────────────────────────────────────────────────
              TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
                overlayColor: WidgetStateProperty.all(
                    Colors.white.withValues(alpha: 0.1)),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.bar_chart_rounded, size: 18),
                    text: 'Gráficos',
                    height: 52,
                  ),
                  Tab(
                    icon: Icon(Icons.psychology_rounded, size: 18),
                    text: 'Risco',
                    height: 52,
                  ),
                  Tab(
                    icon: Icon(Icons.swap_horiz_rounded, size: 18),
                    text: 'Movimentações',
                    height: 52,
                  ),
                  Tab(
                    icon: Icon(Icons.trending_up_rounded, size: 18),
                    text: 'Previsão',
                    height: 52,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Página principal ─────────────────────────────────────────────────────

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: const Column(children: [
          _ReportsAppBar(),
          Expanded(child: TabBarView(
            children: [
              _ChartsTab(),
              _MlRiskTab(),
              _MovementsTab(),
              _ForecastReportTab(),
            ],
          )),
        ]),
      ),
    );
  }
  static void _showScheduleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ReportScheduleSheet(),
    );
  }
}

// ─── Report Schedule Bottom Sheet ────────────────────────────────────────────

class _ReportScheduleSheet extends ConsumerStatefulWidget {
  const _ReportScheduleSheet();

  @override
  ConsumerState<_ReportScheduleSheet> createState() =>
      _ReportScheduleSheetState();
}

class _ReportScheduleSheetState extends ConsumerState<_ReportScheduleSheet> {
  bool _enabled = false;
  int _dayOfWeek = 1; // Monday
  TimeOfDay _sendTime = const TimeOfDay(hour: 8, minute: 0);
  final _emailCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String? s) {
    if (s == null) return const TimeOfDay(hour: 8, minute: 0);
    final parts = s.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 8, minute: 0);
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0);
  }

  static const _dayLabels = [
    '', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'
  ];

  Future<void> _save() async {
    final email = _emailCtrl.text.trim();
    if (_enabled && (email.isEmpty || !email.contains('@'))) {
      showCasaSnackbar(context,
          message: 'Informe um e-mail válido para receber o relatório.',
          isError: true);
      return;
    }
    await ref.read(reportScheduleNotifierProvider.notifier).save(
          ReportScheduleConfig(
            enabled: _enabled,
            recipientEmail: email,
            dayOfWeek: _dayOfWeek,
            sendTime: _formatTime(_sendTime),
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    showCasaSnackbar(context,
        message: _enabled
            ? 'Relatório agendado para ${_dayLabels[_dayOfWeek]} às ${_formatTime(_sendTime)}'
            : 'Agendamento desativado.',
        isSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scheduleAsync = ref.watch(reportScheduleConfigProvider);

    // Initialize once
    scheduleAsync.whenData((config) {
      if (!_initialized) {
        _enabled = config.enabled;
        _dayOfWeek = config.dayOfWeek;
        _sendTime = _parseTime(config.sendTime);
        _emailCtrl.text = config.recipientEmail;
        _initialized = true;
      }
    });

    final notifierState = ref.watch(reportScheduleNotifierProvider);
    final isSaving = notifierState is AsyncLoading;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill)),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary600.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Icon(Icons.event_repeat_rounded,
                      color: AppColors.brandPrimary600, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Relatório Semanal Automático',
                          style: AppTypography.headingSmall.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700)),
                      Text(
                        'Receba o relatório de estoque por e-mail',
                        style: AppTypography.bodySmall
                            .copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  activeColor: AppColors.brandPrimary600,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_enabled) ...[
              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail destinatário',
                  hintText: 'Ex: diretor@casadacrianca.org.br',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.input)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Day of week
              Text('Dia da semana',
                  style: AppTypography.labelMedium
                      .copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final selected = _dayOfWeek == day;
                    return Padding(
                      padding:
                          const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        label: Text(_dayLabels[day].substring(0, 3)),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _dayOfWeek = day),
                        selectedColor: AppColors.brandPrimary600,
                        labelStyle: AppTypography.labelSmall.copyWith(
                          color: selected
                              ? Colors.white
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Time
              Text('Horário de envio',
                  style: AppTypography.labelMedium
                      .copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _sendTime,
                    helpText: 'Horário de envio do relatório',
                  );
                  if (picked != null) setState(() => _sendTime = picked);
                },
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: AppColors.brandPrimary600),
                      const SizedBox(width: AppSpacing.sm),
                      Text(_formatTime(_sendTime),
                          style: AppTypography.headingSmall.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Info banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning600.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                      color: AppColors.warning600.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: AppColors.warning600),
                    const SizedBox(width: AppSpacing.xs),
                    const Expanded(
                      child: Text(
                        'O envio automático requer que a Cloud Function '
                        '"scheduledReport" esteja implantada no Firebase.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.warning600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaving ? null : _save,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(isSaving ? 'Salvando...' : 'Salvar agendamento'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 1: Gráficos ─────────────────────────────────────────────────────

class _ChartsTab extends ConsumerWidget {
  const _ChartsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allBatchesAsync = ref.watch(allAvailableBatchesProvider);
    final expiring7 = ref.watch(expiringBatchesProvider(7));
    final expiring30 = ref.watch(expiringBatchesProvider(30));
    final exp7List = expiring7.valueOrNull ?? [];
    final exp30List = expiring30.valueOrNull ?? [];

    return allBatchesAsync.when(
      loading: () => ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: CasaCardSkeleton(),
        ),
      ),
      error: (e, _) => CasaEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Erro ao carregar dados',
        description: e.toString(),
      ),
      data: (batches) {
        final totalItems = batches.fold<int>(0, (s, b) => s + b.quantity);
        final totalValue =
            batches.fold<double>(0, (s, b) => s + (b.unitPrice ?? 0) * b.quantity);
        final expired = batches.where((b) => b.isExpired).length;

        final Map<String, int> catCount = {};
        for (final b in batches) {
          catCount[b.productName] = (catCount[b.productName] ?? 0) + b.quantity;
        }
        final topProducts =
            (catCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                .take(5)
                .toList();

        final Map<String, int> originCount = {};
        for (final b in batches) {
          originCount[b.origin] = (originCount[b.origin] ?? 0) + 1;
        }
        const originLabels = {
          'doacao': 'Doação',
          'compra': 'Compra',
          'parceiro': 'Parceiro',
          'transferencia': 'Transferência',
        };

        final Map<String, int> monthTrend = {};
        final now = DateTime.now();
        for (int i = 5; i >= 0; i--) {
          final d = DateTime(now.year, now.month - i);
          final key = '${d.month.toString().padLeft(2, '0')}/${d.year % 100}';
          monthTrend[key] = 0;
        }
        for (final b in batches) {
          final key =
              '${b.entryDate.month.toString().padLeft(2, '0')}/${b.entryDate.year % 100}';
          if (monthTrend.containsKey(key)) {
            monthTrend[key] = monthTrend[key]! + b.quantity;
          }
        }

        final healthScore = (100 -
                (expired * 10) -
                (exp7List.length * 5) -
                (exp30List.length - exp7List.length) * 2)
            .clamp(0, 100);

        final Map<String, int> expiryBuckets = {
          'Vencido': 0,
          '0–7d': 0,
          '8–30d': 0,
          '31–90d': 0,
          '>90d': 0,
          'Sem val.': 0,
        };
        for (final b in batches) {
          final d = b.daysToExpiry;
          if (b.noExpiry) {
            expiryBuckets['Sem val.'] = expiryBuckets['Sem val.']! + 1;
          } else if (b.isExpired) {
            expiryBuckets['Vencido'] = expiryBuckets['Vencido']! + 1;
          } else if (d <= 7) {
            expiryBuckets['0–7d'] = expiryBuckets['0–7d']! + 1;
          } else if (d <= 30) {
            expiryBuckets['8–30d'] = expiryBuckets['8–30d']! + 1;
          } else if (d <= 90) {
            expiryBuckets['31–90d'] = expiryBuckets['31–90d']! + 1;
          } else {
            expiryBuckets['>90d'] = expiryBuckets['>90d']! + 1;
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
          children: [
            // ─── Botão de tutorial
            Align(
              alignment: Alignment.centerRight,
              child: buildHelpButton(
                context: context,
                onPressed: () => showCasaTutorial(
                  context: context,
                  steps: _chartsTutorialSteps(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // ─── Modern stats banner
            _ModernStatsBanner(
              totalBatches: batches.length,
              totalItems: totalItems,
              totalValue: totalValue,
              expired: expired,
              criticals: exp7List.length,
              warnings: exp30List.length,
              healthScore: healthScore,
              isDark: isDark,
              cs: cs,
              criticalBatches: exp7List,
              warningBatches: exp30List,
              expiredBatches: batches.where((b) => b.isExpired).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Tendência mensal
            _SectionHeader(
              title: 'Entradas Mensais',
              subtitle: 'Evolução das entradas nos últimos 6 meses',
              icon: Icons.trending_up_rounded,
              color: AppColors.brandPrimary600,
            ),
            const SizedBox(height: AppSpacing.sm),
            KeyedSubtree(
              key: _keyTrendChart,
              child: _MonthlyTrendChart(
                  monthTrend: monthTrend, isDark: isDark, cs: cs),
            ),
            const _ChartNote(
              text: 'Soma total de itens cadastrados por mês. Toque nos pontos para ver o valor exato.',
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Validade por faixa
            _SectionHeader(
              title: 'Distribuição por Prazo de Validade',
              subtitle: 'Quantos lotes estão em cada faixa de vencimento',
              icon: Icons.schedule_rounded,
              color: AppColors.warning600,
            ),
            const SizedBox(height: AppSpacing.sm),
            KeyedSubtree(
              key: _keyExpiryChart,
              child: _ExpiryBarChart(
                  buckets: expiryBuckets, isDark: isDark, cs: cs),
            ),
            const _ChartNote(
              text: 'Vermelho = vencidos ou críticos (≤7d). Laranja = atenção (8–30d). Verde = seguros (>30d).',
            ),
            const SizedBox(height: AppSpacing.xl),

            // ─── Origem (pizza)
            if (originCount.isNotEmpty) ...[
              _SectionHeader(
                title: 'Lotes por Origem',
                subtitle: 'Proporção de cada fonte no estoque atual',
                icon: Icons.pie_chart_rounded,
                color: AppColors.secondaryBlue600,
              ),
              const SizedBox(height: AppSpacing.sm),
              KeyedSubtree(
                key: _keyCategoryChart,
                child: _CategoryPieChart(
                  catCount: originCount,
                  labelMap: originLabels,
                  isDark: isDark,
                  cs: cs,
                ),
              ),
              const _ChartNote(
                text: 'Toque em cada fatia para ver o percentual. Ajuda a entender as principais fontes de entrada.',
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ─── Top 5 produtos
            if (topProducts.isNotEmpty) ...[
              _SectionHeader(
                title: 'Top 5 Produtos em Estoque',
                subtitle: 'Produtos com maior quantidade disponível',
                icon: Icons.inventory_2_rounded,
                color: AppColors.success600,
              ),
              const SizedBox(height: AppSpacing.sm),
              _TopProductsChart(
                products: topProducts,
                totalItems: totalItems,
                isDark: isDark,
                cs: cs,
              ),
              const _ChartNote(
                text: 'A barra mostra a proporção de cada produto em relação ao total.',
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ─── Value distribution by product
            if (topProducts.isNotEmpty) ...[
              _SectionHeader(
                title: 'Valor Estimado por Produto',
                subtitle: 'Top 5 — valor total em estoque (R\$)',
                icon: Icons.monetization_on_rounded,
                color: AppColors.success600,
              ),
              const SizedBox(height: AppSpacing.sm),
              _ValueBarChart(
                batches: batches,
                isDark: isDark,
                cs: cs,
              ),
              const _ChartNote(
                text: 'Baseado no preço unitário de cada lote. Itens sem preço não são contabilizados.',
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ─── Tips
            _TabTipCard(
              tips: const [
                _TipItem(
                  icon: Icons.show_chart_rounded,
                  color: AppColors.brandPrimary600,
                  title: 'Tendência Mensal',
                  body: 'Toque nos pontos do gráfico de linha para ver o volume exato de entradas. Picos indicam meses com muitas doações.',
                ),
                _TipItem(
                  icon: Icons.bar_chart_rounded,
                  color: AppColors.warning600,
                  title: 'Validade por Faixa',
                  body: 'Barras vermelhas = lotes vencidos ou críticos. Priorize a distribuição imediata desses itens.',
                ),
                _TipItem(
                  icon: Icons.pie_chart_rounded,
                  color: AppColors.secondaryBlue600,
                  title: 'Lotes por Origem',
                  body: 'Entenda de onde vem o estoque. Se "Doação" dominar, reforce parcerias. Se "Compra" for alto, revise o orçamento.',
                ),
                _TipItem(
                  icon: Icons.inventory_2_rounded,
                  color: AppColors.success600,
                  title: 'Top 5 Produtos',
                  body: 'Produtos com maior estoque — úteis para planejar distribuições. Cruze com a previsão de consumo para evitar desperdício.',
                ),
              ],
              isDark: isDark,
              cs: cs,
            ),
          ],
        );
      },
    );
  }
}

// ─── Tab 2: Risco ML ─────────────────────────────────────────────────────

class _MlRiskTab extends ConsumerWidget {
  const _MlRiskTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final riskCountsAsync = ref.watch(riskCountsProvider);
    final riskPredictionsAsync = ref.watch(batchRiskPredictionsProvider);
    final classifierSourceAsync = ref.watch(classifierSourceProvider);

    final predictions = riskPredictionsAsync.valueOrNull ?? [];
    final sortedPredictions = [...predictions]..sort(_sortByRisk);
    final classifierSrc = classifierSourceAsync.valueOrNull ?? 'rule_based';

    final criticals =
        sortedPredictions.where((p) => p.level == RiskLevel.vermelho).toList();
    final amarelos =
        sortedPredictions.where((p) => p.level == RiskLevel.amarelo).toList();
    final verdes =
        sortedPredictions.where((p) => p.level == RiskLevel.verde).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        // ─── Botão de tutorial
        Align(
          alignment: Alignment.centerRight,
          child: buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: _riskTutorialSteps(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // ─── Classifier badge
        _SectionHeader(
          title: 'Análise de Risco',
          subtitle: classifierSrc == 'tflite'
              ? 'Modelo TFLite on-device ativo'
              : 'Classificação por regras inteligentes',
          icon: classifierSrc == 'tflite'
              ? Icons.memory_rounded
              : Icons.rule_rounded,
          color: AppColors.brandPrimary600,
          badge: classifierSrc == 'tflite' ? 'TFLite' : 'Rules',
        ),
        const SizedBox(height: AppSpacing.md),

        // ─── Quick actions
        _MlRiskActionsRow(
          criticalCount: criticals.length,
          predictions: sortedPredictions,
        ),
        const SizedBox(height: AppSpacing.md),

        // ─── Risk score banner
        _MlScoreBanner(
          key: _keyRiskBanner,
          criticalCount: criticals.length,
          warningCount: amarelos.length,
          safeCount: verdes.length,
          cs: cs,
        ),
        const SizedBox(height: AppSpacing.md),

        // ─── Risk counts row
        riskCountsAsync.when(
          data: (counts) => RiskSummaryRow(counts: counts),
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
        const SizedBox(height: AppSpacing.md),

        // ─── Donut chart
        riskPredictionsAsync.when(
          data: (_) => _MlRiskDonutChart(
            key: _keyRiskDonut,
            verdeCount: verdes.length,
            amareloCount: amarelos.length,
            vermelhoCount: criticals.length,
            cs: cs,
            isDark: isDark,
          ),
          loading: () => const CasaCardSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const _ChartNote(
          text: 'Visão geral da saúde do estoque por IA. Toque nas fatias para ver os percentuais.',
        ),
        const SizedBox(height: AppSpacing.md),

        // ─── Confidence distribution chart
        if (sortedPredictions.isNotEmpty) ...[
          _SectionHeader(
            title: 'Distribuição de Confiança',
            subtitle: 'Certeza do modelo por nível de risco',
            icon: Icons.bar_chart_rounded,
            color: AppColors.secondaryBlue600,
          ),
          const SizedBox(height: AppSpacing.sm),
          _MlConfidenceDistChart(predictions: sortedPredictions, cs: cs, isDark: isDark),
          const _ChartNote(text: 'Barras mais altas indicam que o modelo está mais certo da classificação.'),
          const SizedBox(height: AppSpacing.md),
        ],
        if (criticals.isNotEmpty) ...[
          _SectionHeader(
            title: 'Lotes Críticos',
            subtitle: 'Requerem ação imediata',
            icon: Icons.warning_rounded,
            color: AppColors.danger600,
            count: criticals.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...criticals.take(8).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: RiskInsightCard(
                  prediction: p,
                  onTap: () => _showRiskActionSheet(context, p),
                ),
              )),
          if (criticals.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.sm),
              child: Center(
                child: Text(
                  '+ ${criticals.length - 8} lotes críticos adicionais',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.danger600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ─── Atenção
        if (amarelos.isNotEmpty) ...[
          _SectionHeader(
            title: 'Lotes em Atenção',
            subtitle: 'Monitorar de perto',
            icon: Icons.schedule_rounded,
            color: AppColors.warning600,
            count: amarelos.length,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...amarelos.take(5).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: RiskInsightCard(
                  prediction: p,
                  onTap: () => _showRiskActionSheet(context, p),
                ),
              )),
          if (amarelos.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Center(
                child: Text(
                  '+ ${amarelos.length - 5} em atenção',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.warning600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
        ],

        // ─── Resumo lotes seguros
        if (verdes.isNotEmpty)
          _MlNonCriticalSummary(
            amareloCount: amarelos.length,
            verdeCount: verdes.length,
            cs: cs,
          ),
        const SizedBox(height: AppSpacing.md),

      ],
    );
  }

  static int _sortByRisk(RiskPrediction a, RiskPrediction b) {
    const order = {
      RiskLevel.vermelho: 0,
      RiskLevel.amarelo: 1,
      RiskLevel.verde: 2,
    };
    final cmp = order[a.level]!.compareTo(order[b.level]!);
    if (cmp != 0) return cmp;
    return b.confidence.compareTo(a.confidence);
  }
}

// ─── Risk Action Sheet ────────────────────────────────────────────────────

void _showRiskActionSheet(BuildContext context, RiskPrediction prediction) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RiskActionSheet(prediction: prediction),
  );
}

class _RiskActionSheet extends StatelessWidget {
  final RiskPrediction prediction;
  const _RiskActionSheet({required this.prediction});

  Color get _fg => switch (prediction.level) {
        RiskLevel.vermelho => AppColors.danger600,
        RiskLevel.amarelo => AppColors.warning600,
        RiskLevel.verde => AppColors.success600,
      };

  IconData get _icon => switch (prediction.level) {
        RiskLevel.vermelho => Icons.warning_rounded,
        RiskLevel.amarelo => Icons.schedule_rounded,
        RiskLevel.verde => Icons.check_circle_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = _fg;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            // Header info card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: fg.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(_icon, color: fg, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prediction.productName,
                          style: AppTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          prediction.level.description,
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  RiskBadge(level: prediction.level),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ações disponíveis',
              style: AppTypography.labelMedium.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (prediction.level == RiskLevel.vermelho) ...[
              _ActionTile(
                icon: Icons.local_shipping_rounded,
                label: 'Distribuir urgente',
                description: 'Registre a saída imediata deste lote crítico',
                color: AppColors.danger600,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.movement);
                },
                cs: cs,
              ),
              const SizedBox(height: AppSpacing.xs),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Registrar descarte',
                description: 'Lote vencido ou inapropriado para uso',
                color: AppColors.warning600,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.movement);
                },
                cs: cs,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (prediction.level == RiskLevel.amarelo) ...[
              _ActionTile(
                icon: Icons.local_shipping_rounded,
                label: 'Planejar distribuição',
                description: 'Registre a saída antes do vencimento',
                color: AppColors.warning600,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(AppRoutes.movement);
                },
                cs: cs,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            _ActionTile(
              icon: Icons.psychology_rounded,
              label: 'Ver análise de IA completa',
              description: 'Detalhes do modelo de classificação de risco',
              color: AppColors.brandPrimary600,
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.mlInsights);
              },
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Action Tile (shared) ─────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w700, color: cs.onSurface),
                  ),
                  Text(
                    description,
                    style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── ML Score Banner ──────────────────────────────────────────────────────

class _MlScoreBanner extends StatelessWidget {
  final int criticalCount;
  final int warningCount;
  final int safeCount;
  final ColorScheme cs;

  const _MlScoreBanner({
    super.key,
    required this.criticalCount,
    required this.warningCount,
    required this.safeCount,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final total = criticalCount + warningCount + safeCount;
    if (total == 0) return const SizedBox.shrink();

    final safetyScore = total == 0
        ? 100
        : ((safeCount / total) * 100).round();
    final Color bannerColor;
    final IconData bannerIcon;
    final String bannerMsg;

    if (criticalCount == 0 && warningCount == 0) {
      bannerColor = AppColors.success600;
      bannerIcon = Icons.verified_rounded;
      bannerMsg = 'Estoque saudável — nenhum lote em risco';
    } else if (criticalCount > 0) {
      bannerColor = AppColors.danger600;
      bannerIcon = Icons.emergency_rounded;
      bannerMsg =
          '$criticalCount lote${criticalCount > 1 ? 's' : ''} em estado crítico — ação imediata!';
    } else {
      bannerColor = AppColors.warning600;
      bannerIcon = Icons.warning_amber_rounded;
      bannerMsg = '$warningCount lote${warningCount > 1 ? 's' : ''} em atenção — monitore de perto';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bannerColor, bannerColor.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(bannerIcon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score de Segurança: $safetyScore%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  bannerMsg,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: safetyScore / 100,
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
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

// ─── Tab 3: Movimentações ────────────────────────────────────────────────

class _MovementsTab extends ConsumerStatefulWidget {
  const _MovementsTab();

  @override
  ConsumerState<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends ConsumerState<_MovementsTab> {
  int _days = 30;
  DateTimeRange? _customRange;
  Set<MovementType> _typeFilter = {};
  bool _showAll = false;

  static const _periods = [7, 30, 90, 180];
  static const _periodLabels = {
    7: '7 dias',
    30: '30 dias',
    90: '90 dias',
    180: '6 meses',
  };

  DateTimeRange get _range {
    if (_customRange != null) return _customRange!;
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: _days - 1)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  void _setPeriod(int days) => setState(() {
        _days = days;
        _customRange = null;
        _showAll = false;
      });

  Future<void> _pickCustomRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx)
              .colorScheme
              .copyWith(primary: AppColors.brandPrimary600),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      setState(() {
        _customRange = result;
        _days = 0;
        _showAll = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(movementsSummaryProvider(_range));
    final movementsAsync = ref.watch(movementsReportProvider(_range));
    final lossesAsync = ref.watch(lossesByReasonProvider(_range));

    final dateFmt = DateFormat('dd/MM/yy');
    final rangeLabel =
        '${dateFmt.format(_range.start)} – ${dateFmt.format(_range.end)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        // ─── Botão de tutorial
        Align(
          alignment: Alignment.centerRight,
          child: buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: _movementsTutorialSteps(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // ─── Modern period header
        _MovementsPeriodHeader(
          rangeLabel: rangeLabel,
          selectedDays: _customRange != null ? 0 : _days,
          periods: _periods,
          periodLabels: _periodLabels,
          onPeriodSelected: _setPeriod,
          onCustomRange: _pickCustomRange,
          cs: cs,
          isDark: isDark,
        ),
        const SizedBox(height: AppSpacing.md),

        // ─── Resumo KPIs
        summaryAsync.when(
          loading: () => const CasaCardSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (summary) => _MovementsSummaryGrid(
            key: _keyMovSummary,
            summary: summary,
            cs: cs,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ─── Gráfico entradas × saídas
        _SectionHeader(
          title: 'Entradas × Saídas',
          subtitle: 'Comparativo por período',
          icon: Icons.show_chart_rounded,
          color: AppColors.brandPrimary600,
        ),
        const SizedBox(height: AppSpacing.sm),
        movementsAsync.when(
          loading: () => const CasaCardSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (movements) {
            final grouped = _groupByPeriod(movements, _range);
            return _MovementsBarChart(
              key: _keyMovChart,
              data: grouped,
              cs: cs,
            );
          },
        ),
        const _ChartNote(
          text: 'Verde = entradas. Vermelho = saídas e descartes. Toque nas barras para ver o valor.',
        ),
        const SizedBox(height: AppSpacing.xl),

        // ─── Perdas por motivo
        _SectionHeader(
          title: 'Perdas por Motivo',
          subtitle: 'Distribuição das saídas por razão',
          icon: Icons.pie_chart_outline_rounded,
          color: AppColors.danger600,
        ),
        const SizedBox(height: AppSpacing.sm),
        lossesAsync.when(
          loading: () => const CasaCardSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (losses) => losses.isEmpty
              ? const CasaEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Nenhuma perda registrada no período',
                  description: 'Ótimo! Tudo foi distribuído corretamente.',
                )
              : _LossesBreakdown(losses: losses, cs: cs),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ─── Lista completa com filtro
        _SectionHeader(
          title: 'Lista de Movimentações',
          subtitle: 'Detalhamento de todas as movimentações',
          icon: Icons.list_alt_rounded,
          color: AppColors.brandPrimary600,
        ),
        const SizedBox(height: AppSpacing.sm),
        _TypeFilterChips(
          selectedTypes: _typeFilter,
          onChanged: (types) => setState(() {
            _typeFilter = types;
            _showAll = false;
          }),
          cs: cs,
        ),
        const SizedBox(height: AppSpacing.sm),
        movementsAsync.when(
          loading: () => Column(
            children: List.generate(
                5,
                (_) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.xs),
                      child: CasaCardSkeleton(),
                    )),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (movements) {
            final filtered = _typeFilter.isEmpty
                ? movements
                : movements
                    .where((m) => _typeFilter.contains(m.type))
                    .toList();

            if (filtered.isEmpty) {
              return CasaEmptyState(
                icon: Icons.swap_horiz_rounded,
                title: 'Sem movimentações no período',
                description: _typeFilter.isNotEmpty
                    ? 'Nenhuma movimentação do tipo selecionado. Limpe os filtros.'
                    : 'Ajuste o período de análise para ver dados.',
              );
            }

            final shown =
                _showAll ? filtered : filtered.take(20).toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MovementsListView(
                  key: _keyMovList,
                  movements: shown,
                  cs: cs,
                  isDark: isDark,
                ),
                if (filtered.length > 20 && !_showAll) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showAll = true),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(
                        'Ver mais ${filtered.length - 20} movimentações'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary600,
                      side: const BorderSide(
                          color: AppColors.brandPrimary600),
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // ─── Tips
        _TabTipCard(
          tips: const [
            _TipItem(
              icon: Icons.show_chart_rounded,
              color: AppColors.brandPrimary600,
              title: 'Entradas × Saídas',
              body: 'Barras verdes = entradas no estoque. Barras vermelhas = saídas e descartes. Selecione períodos diferentes para comparar meses.',
            ),
            _TipItem(
              icon: Icons.pie_chart_outline_rounded,
              color: AppColors.danger600,
              title: 'Perdas por Motivo',
              body: 'Identifique os motivos de perda mais frequentes. Se "vencimento" dominar, use a IA de Risco para antecipar-se.',
            ),
            _TipItem(
              icon: Icons.filter_list_rounded,
              color: AppColors.secondaryBlue600,
              title: 'Filtros de Tipo',
              body: 'Use os chips de filtro para ver apenas Entradas, Saídas ou Descartes. Combine com o seletor de período para análises precisas.',
            ),
            _TipItem(
              icon: Icons.date_range_rounded,
              color: AppColors.success600,
              title: 'Período Personalizado',
              body: 'Toque em "Personalizado" para selecionar qualquer intervalo de datas. Ideal para auditorias mensais ou trimestrais.',
            ),
          ],
          isDark: isDark,
          cs: cs,
        ),
      ],
    );
  }
}

// ─── Modern Period Header ────────────────────────────────────────────────

class _MovementsPeriodHeader extends StatelessWidget {
  final String rangeLabel;
  final int selectedDays;
  final List<int> periods;
  final Map<int, String> periodLabels;
  final void Function(int) onPeriodSelected;
  final VoidCallback onCustomRange;
  final ColorScheme cs;
  final bool isDark;

  const _MovementsPeriodHeader({
    required this.rangeLabel,
    required this.selectedDays,
    required this.periods,
    required this.periodLabels,
    required this.onPeriodSelected,
    required this.onCustomRange,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.08),
            cs.secondary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range_rounded,
                  color: cs.primary, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Período: $rangeLabel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...periods.map((p) {
                  final selected = p == selectedDays;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppRadius.small),
                        color: selected
                            ? cs.primary
                            : cs.surface,
                        border: Border.all(
                          color: selected
                              ? cs.primary
                              : cs.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onPeriodSelected(p),
                          borderRadius: BorderRadius.circular(
                              AppRadius.small),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              periodLabels[p]!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: selected
                                    ? cs.onPrimary
                                    : cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Material(
                    color: cs.tertiary.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppRadius.small),
                    child: InkWell(
                      onTap: onCustomRange,
                      borderRadius:
                          BorderRadius.circular(AppRadius.small),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: cs.tertiary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Personalizado',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

// ─── Period Selector (old version, kept for reference) ──────────────────────

class _PeriodSelector extends StatelessWidget {
  final int selectedDays;
  final List<int> periods;
  final Map<int, String> periodLabels;
  final void Function(int) onPeriodSelected;
  final VoidCallback onCustomRange;
  final ColorScheme cs;

  const _PeriodSelector({
    required this.selectedDays,
    required this.periods,
    required this.periodLabels,
    required this.onPeriodSelected,
    required this.onCustomRange,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...periods.map((p) {
            final selected = p == selectedDays;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: FilterChip(
                label: Text(periodLabels[p]!),
                selected: selected,
                onSelected: (_) => onPeriodSelected(p),
                selectedColor:
                    AppColors.secondaryBlue600.withValues(alpha: 0.15),
                checkmarkColor: AppColors.secondaryBlue600,
                labelStyle: TextStyle(
                  color: selected
                      ? AppColors.secondaryBlue600
                      : cs.onSurfaceVariant,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            );
          }),
          ActionChip(
            avatar: Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: selectedDays == 0
                  ? AppColors.brandPrimary600
                  : cs.onSurfaceVariant,
            ),
            label: Text(
              selectedDays == 0 ? 'Personalizado ✓' : 'Personalizado',
              style: TextStyle(
                color: selectedDays == 0
                    ? AppColors.brandPrimary600
                    : cs.onSurfaceVariant,
                fontWeight: selectedDays == 0
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            backgroundColor: selectedDays == 0
                ? AppColors.brandPrimary600.withValues(alpha: 0.1)
                : null,
            side: selectedDays == 0
                ? BorderSide(
                    color:
                        AppColors.brandPrimary600.withValues(alpha: 0.4))
                : null,
            onPressed: onCustomRange,
          ),
        ],
      ),
    );
  }
}

// ─── Movements Summary Grid ───────────────────────────────────────────────

class _MovementsSummaryGrid extends StatelessWidget {
  final Map<String, int> summary;
  final ColorScheme cs;

  const _MovementsSummaryGrid({super.key, required this.summary, required this.cs});

  @override
  Widget build(BuildContext context) {
    final entrada = summary['entrada'] ?? 0;
    final saida = summary['saida'] ?? 0;
    final ajustPos = summary['ajustePositivo'] ?? 0;
    final ajustNeg = summary['ajusteNegativo'] ?? 0;
    final descarte = summary['descarte'] ?? 0;
    final totalIn = entrada + ajustPos;
    final totalOut = saida + ajustNeg + descarte;
    final net = totalIn - totalOut;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Saldo principal
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: net >= 0
                  ? [AppColors.success600, const Color(0xFF4CAF50)]
                  : [AppColors.danger600, const Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: [
              BoxShadow(
                color: (net >= 0 ? AppColors.success600 : AppColors.danger600)
                    .withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(
                  net >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo do Período',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${net >= 0 ? '+' : ''}$net unidades',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '↑ $totalIn entr.  ↓ $totalOut saíd.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Cards individuais
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.2,
          children: [
            _MovKpiCard(
                icon: Icons.add_circle_outline_rounded,
                label: 'Entradas',
                value: entrada,
                color: AppColors.success600,
                cs: cs),
            _MovKpiCard(
                icon: Icons.outbound_rounded,
                label: 'Saídas',
                value: saida,
                color: AppColors.brandPrimary600,
                cs: cs),
            _MovKpiCard(
                icon: Icons.delete_outline_rounded,
                label: 'Descartes',
                value: descarte,
                color: AppColors.danger600,
                cs: cs),
            _MovKpiCard(
                icon: Icons.trending_up_rounded,
                label: 'Ajuste +',
                value: ajustPos,
                color: AppColors.secondarySky500,
                cs: cs),
            _MovKpiCard(
                icon: Icons.trending_down_rounded,
                label: 'Ajuste −',
                value: ajustNeg,
                color: AppColors.warning600,
                cs: cs),
            _MovKpiCard(
                icon: Icons.swap_horiz_rounded,
                label: 'Total',
                value: entrada + saida + ajustPos + ajustNeg + descarte,
                color: AppColors.brandPrimary600,
                cs: cs),
          ],
        ),
      ],
    );
  }
}

class _MovKpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final ColorScheme cs;

  const _MovKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 9,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          Text('un.',
              style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─── Daily/Weekly data model ──────────────────────────────────────────────

class _MovDayData {
  final String label;
  final int inbound;
  final int outbound;
  const _MovDayData(this.label, this.inbound, this.outbound);
}

List<_MovDayData> _groupByPeriod(
    List<StockMovement> movements, DateTimeRange range) {
  final days = range.end.difference(range.start).inDays + 1;
  if (days <= 14) return _groupByDay(movements, range);
  if (days <= 60) return _groupByWeek(movements, range);
  return _groupByMonth(movements, range);
}

List<_MovDayData> _groupByDay(
    List<StockMovement> movements, DateTimeRange range) {
  final days = range.end.difference(range.start).inDays + 1;
  final dayFmt = days <= 7 ? DateFormat('E', 'pt_BR') : DateFormat('dd/MM');
  final result = <String, _MovDayData>{};

  for (int i = 0; i < days; i++) {
    final day = range.start.add(Duration(days: i));
    final key = dayFmt.format(day);
    result[key] = _MovDayData(key, 0, 0);
  }
  for (final m in movements) {
    final key = dayFmt.format(m.performedAt);
    if (result.containsKey(key)) {
      final curr = result[key]!;
      if (m.isInbound) {
        result[key] = _MovDayData(key, curr.inbound + m.quantity, curr.outbound);
      } else {
        result[key] = _MovDayData(key, curr.inbound, curr.outbound + m.quantity);
      }
    }
  }
  return result.values.toList();
}

List<_MovDayData> _groupByWeek(
    List<StockMovement> movements, DateTimeRange range) {
  final days = range.end.difference(range.start).inDays + 1;
  final weekCount = (days / 7).ceil();
  return List.generate(weekCount, (w) {
    final weekStart = range.start.add(Duration(days: w * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final label = 'S${w + 1}';
    int inbound = 0;
    int outbound = 0;
    for (final m in movements) {
      if (!m.performedAt.isBefore(weekStart) &&
          !m.performedAt.isAfter(weekEnd)) {
        if (m.isInbound) {
          inbound += m.quantity;
        } else {
          outbound += m.quantity;
        }
      }
    }
    return _MovDayData(label, inbound, outbound);
  });
}

List<_MovDayData> _groupByMonth(
    List<StockMovement> movements, DateTimeRange range) {
  final monthFmt = DateFormat('MM/yy');
  final result = <String, _MovDayData>{};
  var cursor = DateTime(range.start.year, range.start.month);
  while (!cursor.isAfter(range.end)) {
    final key = monthFmt.format(cursor);
    result[key] = _MovDayData(key, 0, 0);
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  for (final m in movements) {
    final key = monthFmt.format(m.performedAt);
    if (result.containsKey(key)) {
      final curr = result[key]!;
      if (m.isInbound) {
        result[key] = _MovDayData(key, curr.inbound + m.quantity, curr.outbound);
      } else {
        result[key] = _MovDayData(key, curr.inbound, curr.outbound + m.quantity);
      }
    }
  }
  return result.values.toList();
}

// ─── Movements Bar Chart ──────────────────────────────────────────────────

class _MovementsBarChart extends StatelessWidget {
  final List<_MovDayData> data;
  final ColorScheme cs;

  const _MovementsBarChart({super.key, required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final maxVal = data
        .fold(0, (prev, d) => math.max(prev, math.max(d.inbound, d.outbound)))
        .toDouble();

    if (maxVal == 0) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 36,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Sem movimentações no período',
                style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final groups = data.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
            toY: e.value.inbound.toDouble(),
            gradient: const LinearGradient(
              colors: [AppColors.success600, Color(0xFF66BB6A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: data.length > 12 ? 8 : 12,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: e.value.outbound.toDouble(),
            gradient: const LinearGradient(
              colors: [AppColors.danger600, AppColors.warning600],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: data.length > 12 ? 8 : 12,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs, AppSpacing.md, AppSpacing.xs, AppSpacing.xs),
      height: 240,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(
                  color: AppColors.success600, label: 'Entradas'),
              SizedBox(width: AppSpacing.lg),
              _LegendDot(color: AppColors.danger600, label: 'Saídas'),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: BarChart(
              BarChartData(
                barGroups: groups,
                maxY: maxVal * 1.3,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, maxVal / 4),
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.25),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= data.length) {
                          return const SizedBox.shrink();
                        }
                        if (data.length > 14 && idx % 2 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data[idx].label,
                            style: TextStyle(
                              fontSize: 8,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) {
                        if (v == 0) return const SizedBox.shrink();
                        return Text(
                          v.toInt().toString(),
                          style: TextStyle(
                              fontSize: 8, color: cs.onSurfaceVariant),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => cs.surfaceContainer,
                    getTooltipItem: (group, gI, rod, rI) {
                      final val = rod.toY.toInt();
                      final label = rI == 0
                          ? '$val entrada${val != 1 ? 's' : ''}'
                          : '$val saída${val != 1 ? 's' : ''}';
                      return BarTooltipItem(
                        label,
                        TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

// ─── Losses Breakdown ─────────────────────────────────────────────────────

class _LossesBreakdown extends StatelessWidget {
  final Map<String, int> losses;
  final ColorScheme cs;

  const _LossesBreakdown({required this.losses, required this.cs});

  static const _labels = {
    'validade': 'Vencimento',
    'avaria': 'Avaria / Perda',
    'uso': 'Uso / Distribuição',
    'receita': 'Receita',
    'ajusteInventario': 'Ajuste de Inventário',
    'doacao': 'Doação',
    'outro': 'Outro',
  };

  static const _reasonColors = [
    AppColors.danger600,
    AppColors.warning600,
    AppColors.brandPrimary600,
    AppColors.secondaryBlue600,
    AppColors.success600,
    Color(0xFF7C3AED),
    AppColors.neutral500,
  ];

  @override
  Widget build(BuildContext context) {
    final total = losses.values.fold(0, (a, b) => a + b);
    final sorted = losses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: sorted.asMap().entries.map((e) {
          final color = _reasonColors[e.key % _reasonColors.length];
          final label = _labels[e.value.key] ?? e.value.key;
          final pct = total == 0 ? 0.0 : e.value.value / total;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value.value} un.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor:
                        cs.outlineVariant.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Type Filter Chips ────────────────────────────────────────────────────

class _TypeFilterChips extends StatelessWidget {
  final Set<MovementType> selectedTypes;
  final void Function(Set<MovementType>) onChanged;
  final ColorScheme cs;

  const _TypeFilterChips({
    required this.selectedTypes,
    required this.onChanged,
    required this.cs,
  });

  static const _typeData = [
    (
      MovementType.entrada,
      'Entrada',
      Icons.add_circle_outline_rounded,
      AppColors.success600
    ),
    (
      MovementType.saida,
      'Saída',
      Icons.outbound_rounded,
      AppColors.brandPrimary600
    ),
    (
      MovementType.ajustePositivo,
      'Ajuste +',
      Icons.trending_up_rounded,
      AppColors.secondaryBlue600
    ),
    (
      MovementType.ajusteNegativo,
      'Ajuste −',
      Icons.trending_down_rounded,
      AppColors.warning600
    ),
    (
      MovementType.descarte,
      'Descarte',
      Icons.delete_outline_rounded,
      AppColors.danger600
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: FilterChip(
              label: const Text('Todos'),
              selected: selectedTypes.isEmpty,
              onSelected: (_) => onChanged({}),
              selectedColor:
                  AppColors.brandPrimary600.withValues(alpha: 0.15),
              checkmarkColor: AppColors.brandPrimary600,
              labelStyle: TextStyle(
                color: selectedTypes.isEmpty
                    ? AppColors.brandPrimary600
                    : cs.onSurfaceVariant,
                fontWeight: selectedTypes.isEmpty
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          ..._typeData.map((t) {
            final selected = selectedTypes.contains(t.$1);
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: FilterChip(
                avatar: Icon(t.$3,
                    size: 14,
                    color:
                        selected ? t.$4 : cs.onSurfaceVariant),
                label: Text(t.$2),
                selected: selected,
                onSelected: (val) {
                  final newSet = Set<MovementType>.from(selectedTypes);
                  if (val) {
                    newSet.add(t.$1);
                  } else {
                    newSet.remove(t.$1);
                  }
                  onChanged(newSet);
                },
                selectedColor: t.$4.withValues(alpha: 0.15),
                checkmarkColor: t.$4,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color:
                      selected ? t.$4 : cs.onSurfaceVariant,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Movements List View ──────────────────────────────────────────────────

class _MovementsListView extends StatelessWidget {
  final List<StockMovement> movements;
  final ColorScheme cs;
  final bool isDark;

  const _MovementsListView({
    super.key,
    required this.movements,
    required this.cs,
    required this.isDark,
  });

  Color _typeColor(MovementType type) => switch (type) {
        MovementType.entrada => AppColors.success600,
        MovementType.saida => AppColors.brandPrimary600,
        MovementType.ajustePositivo => AppColors.secondaryBlue600,
        MovementType.ajusteNegativo => AppColors.warning600,
        MovementType.descarte => AppColors.danger600,
      };

  IconData _typeIcon(MovementType type) => switch (type) {
        MovementType.entrada => Icons.add_circle_outline_rounded,
        MovementType.saida => Icons.outbound_rounded,
        MovementType.ajustePositivo => Icons.trending_up_rounded,
        MovementType.ajusteNegativo => Icons.trending_down_rounded,
        MovementType.descarte => Icons.delete_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: movements.asMap().entries.map((e) {
          final m = e.value;
          final color = _typeColor(m.type);
          final icon = _typeIcon(m.type);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (e.key > 0)
                Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    indent: 56,
                    endIndent: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.productName,
                            style: AppTypography.labelMedium.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                m.typeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (m.activity != null ||
                                  m.reasonCode != null) ...[
                                Text(' · ',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant)),
                                Expanded(
                                  child: Text(
                                    m.activity ?? m.reasonCode ?? '',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${dateFmt.format(m.performedAt)} · ${m.performedByName}',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quantity chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: color.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        '${m.isInbound ? '+' : '-'}${m.quantity}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}



// ─── Section Header moderno ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final int? count;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.small),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppTypography.headingSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  if (badge != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Nota informativa de gráfico ─────────────────────────────────────────

class _ChartNote extends StatelessWidget {
  final String text;
  const _ChartNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Produtos chart ───────────────────────────────────────────────────

class _TopProductsChart extends StatelessWidget {
  final List<MapEntry<String, int>> products;
  final int totalItems;
  final bool isDark;
  final ColorScheme cs;
  const _TopProductsChart(
      {required this.products,
      required this.totalItems,
      required this.isDark,
      required this.cs});

  static const _colors = [
    AppColors.brandPrimary600,
    AppColors.secondaryBlue600,
    AppColors.success600,
    AppColors.warning600,
    Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...products.asMap().entries.map((e) {
            final color = _colors[e.key % _colors.length];
            final pct = totalItems == 0
                ? 0.0
                : e.value.value / totalItems;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.value.key,
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value.value} un.',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: AppTypography.labelSmall.copyWith(
                            color: cs.onSurfaceVariant, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor:
                          cs.outlineVariant.withValues(alpha: 0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
          Divider(height: 12, color: cs.outlineVariant.withValues(alpha: 0.3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total em estoque: ',
                style: AppTypography.bodySmall
                    .copyWith(color: cs.onSurfaceVariant, fontSize: 10),
              ),
              Text(
                '$totalItems unidades',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Gráfico de Donut: Risco ML ───────────────────────────────────────────

class _MlRiskDonutChart extends StatefulWidget {
  final int verdeCount;
  final int amareloCount;
  final int vermelhoCount;
  final ColorScheme cs;
  final bool isDark;

  const _MlRiskDonutChart({
    super.key,
    required this.verdeCount,
    required this.amareloCount,
    required this.vermelhoCount,
    required this.cs,
    required this.isDark,
  });

  @override
  State<_MlRiskDonutChart> createState() => _MlRiskDonutChartState();
}

class _MlRiskDonutChartState extends State<_MlRiskDonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final total =
        widget.verdeCount + widget.amareloCount + widget.vermelhoCount;

    if (total == 0) return const SizedBox.shrink();

    final items = [
      (widget.vermelhoCount, AppColors.danger600, 'Crítico',
          Icons.warning_rounded),
      (widget.amareloCount, AppColors.warning600, 'Atenção',
          Icons.schedule_rounded),
      (widget.verdeCount, AppColors.success600, 'Seguro',
          Icons.check_circle_rounded),
    ];

    final sections = items.asMap().entries.map((e) {
      final isTouched = e.key == _touched;
      final count = e.value.$1;
      final color = e.value.$2;
      final pct = total == 0 ? 0.0 : count / total * 100;
      return PieChartSectionData(
        color: color,
        value: count == 0 ? 0.001 : count.toDouble(),
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 56 : 46,
        titleStyle: const TextStyle(
            fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800),
        borderSide: isTouched
            ? BorderSide(
                color: Colors.white.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (ev, resp) {
                        setState(() {
                          if (!ev.isInterestedForInteractions ||
                              resp == null ||
                              resp.touchedSection == null) {
                            _touched = -1;
                            return;
                          }
                          _touched =
                              resp.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'lotes',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                final pct =
                    total == 0 ? 0.0 : item.$1 / total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(item.$4, size: 14, color: item.$2),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.$3,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${item.$1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: item.$2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${pct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor:
                              cs.outlineVariant.withValues(alpha: 0.25),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(item.$2),
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

// ─── Resumo compacto dos lotes não-críticos ───────────────────────────────

class _MlNonCriticalSummary extends StatelessWidget {
  final int amareloCount;
  final int verdeCount;
  final ColorScheme cs;

  const _MlNonCriticalSummary({
    required this.amareloCount,
    required this.verdeCount,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_outlined,
              size: 14, color: AppColors.secondaryBlue600),
          const SizedBox(width: 8),
          Text(
            'Demais lotes: ',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (amareloCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: AppColors.warning600.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 11, color: AppColors.warning600),
                  const SizedBox(width: 3),
                  Text(
                    '$amareloCount em atenção',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (verdeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: AppColors.success600.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 11, color: AppColors.success600),
                  const SizedBox(width: 3),
                  Text(
                    '$verdeCount seguros',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success600,
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

// ─── Legenda ML ───────────────────────────────────────────────────────────

class _MlLegend extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  const _MlLegend({required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.check_circle_rounded, AppColors.success600, 'Seguro',
          'Lote em condições normais.'),
      (Icons.schedule_rounded, AppColors.warning600, 'Atenção',
          'Vencimento se aproximando ou estoque baixo.'),
      (Icons.warning_rounded, AppColors.danger600, 'Crítico',
          'Risco iminente de perda. Priorize a distribuição.'),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Como funciona a classificação',
              style: AppTypography.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(item.$1, color: item.$2, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      item.$3,
                      style: TextStyle(
                          fontSize: 11,
                          color: item.$2,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.$4,
                        style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Modern Stats Banner ─────────────────────────────────────────────────

class _ModernStatsBanner extends StatelessWidget {
  final int totalBatches;
  final int totalItems;
  final double totalValue;
  final int expired;
  final int criticals;
  final int warnings;
  final int healthScore;
  final bool isDark;
  final ColorScheme cs;
  final List<Batch> criticalBatches;
  final List<Batch> warningBatches;
  final List<Batch> expiredBatches;

  const _ModernStatsBanner({
    required this.totalBatches,
    required this.totalItems,
    required this.totalValue,
    required this.expired,
    required this.criticals,
    required this.warnings,
    required this.healthScore,
    required this.isDark,
    required this.cs,
    this.criticalBatches = const [],
    this.warningBatches = const [],
    this.expiredBatches = const [],
  });

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final healthColor = healthScore >= 80
        ? AppColors.success600
        : healthScore >= 50
            ? AppColors.warning600
            : AppColors.danger600;
    final healthLabel = healthScore >= 80
        ? 'Ótimo'
        : healthScore >= 50
            ? 'Regular'
            : 'Crítico';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Hero row: health ring + 3 key stats
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      healthColor.withValues(alpha: 0.18),
                      cs.surfaceContainerLow,
                    ]
                  : [
                      healthColor.withValues(alpha: 0.08),
                      cs.surfaceContainerLowest,
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
                color: healthColor.withValues(alpha: isDark ? 0.35 : 0.2)),
          ),
          child: Row(
            children: [
              // ─── Health ring
              SizedBox(
                width: 88,
                height: 88,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 88,
                      height: 88,
                      child: CircularProgressIndicator(
                        value: healthScore / 100,
                        strokeWidth: 8,
                        backgroundColor:
                            cs.outlineVariant.withValues(alpha: 0.3),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(healthColor),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$healthScore%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: healthColor,
                            height: 1,
                          ),
                        ),
                        Text(
                          healthLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // ─── 3 key stats
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatRow(
                      icon: Icons.layers_rounded,
                      color: AppColors.brandPrimary600,
                      label: 'Lotes no estoque',
                      value: '$totalBatches',
                      cs: cs,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _StatRow(
                      icon: Icons.widgets_outlined,
                      color: AppColors.secondaryBlue600,
                      label: 'Total de itens',
                      value: totalItems.toString(),
                      cs: cs,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _StatRow(
                      icon: Icons.attach_money_rounded,
                      color: AppColors.success600,
                      label: 'Valor estimado',
                      value: currFmt.format(totalValue),
                      cs: cs,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ─── Alert chips row
        Row(
          children: [
            Expanded(
              child: _AlertChip(
                icon: Icons.warning_rounded,
                label: 'Críticos',
                value: criticals,
                color: criticals > 0 ? AppColors.danger600 : AppColors.success600,
                isDark: isDark,
                cs: cs,
                onTap: criticalBatches.isEmpty
                    ? null
                    : () => _showBatchListSheet(
                          context,
                          title: 'Lotes Críticos (≤7 dias)',
                          batches: criticalBatches,
                          color: AppColors.danger600,
                          icon: Icons.warning_rounded,
                        ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _AlertChip(
                icon: Icons.schedule_rounded,
                label: 'Atenção (30d)',
                value: warnings,
                color: warnings > 0 ? AppColors.warning600 : AppColors.success600,
                isDark: isDark,
                cs: cs,
                onTap: warningBatches.isEmpty
                    ? null
                    : () => _showBatchListSheet(
                          context,
                          title: 'Lotes em Atenção (≤30 dias)',
                          batches: warningBatches,
                          color: AppColors.warning600,
                          icon: Icons.schedule_rounded,
                        ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _AlertChip(
                icon: Icons.cancel_outlined,
                label: 'Vencidos',
                value: expired,
                color: expired > 0 ? AppColors.danger600 : AppColors.success600,
                isDark: isDark,
                cs: cs,
                onTap: expiredBatches.isEmpty
                    ? null
                    : () => _showBatchListSheet(
                          context,
                          title: 'Lotes Vencidos',
                          batches: expiredBatches,
                          color: AppColors.danger600,
                          icon: Icons.cancel_outlined,
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final ColorScheme cs;

  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.labelMedium.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _AlertChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback? onTap;

  const _AlertChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.cs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 3),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    ),  // closes Container
    );  // closes GestureDetector
  }
}

// ─── Value Bar Chart (top 5 products by R$) ───────────────────────────────

class _ValueBarChart extends StatelessWidget {
  final List<Batch> batches;
  final bool isDark;
  final ColorScheme cs;

  const _ValueBarChart({
    required this.batches,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, double> valueByProduct = {};
    for (final b in batches) {
      if ((b.unitPrice ?? 0) > 0) {
        valueByProduct[b.productName] =
            (valueByProduct[b.productName] ?? 0) +
                (b.unitPrice! * b.quantity);
      }
    }
    if (valueByProduct.isEmpty) {
      return Container(
        height: 80,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Center(
          child: Text(
            'Nenhum produto com preço cadastrado',
            style: AppTypography.bodySmall
                .copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    final sorted = valueByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final maxVal = top5.first.value;

    final colors = [
      AppColors.brandPrimary600,
      AppColors.secondaryBlue600,
      AppColors.success600,
      AppColors.warning600,
      AppColors.danger600,
    ];
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: top5.asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          final pct = maxVal == 0 ? 0.0 : entry.value / maxVal;
          final color = colors[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: AppTypography.labelSmall.copyWith(
                          color: cs.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      currFmt.format(entry.value),
                      style: AppTypography.labelSmall.copyWith(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor:
                        cs.outlineVariant.withValues(alpha: 0.2),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Grid de resumo (kept for reference) ─────────────────────────────────

// ─── Shared: Tab Tip Card ─────────────────────────────────────────────────

@immutable
class _TipItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _TipItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

class _TabTipCard extends StatefulWidget {
  final List<_TipItem> tips;
  final bool isDark;
  final ColorScheme cs;

  const _TabTipCard({
    required this.tips,
    required this.isDark,
    required this.cs,
  });

  @override
  State<_TabTipCard> createState() => _TabTipCardState();
}

class _TabTipCardState extends State<_TabTipCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 280),
      crossFadeState:
          _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: _buildCollapsed(cs, isDark),
      secondChild: _buildExpanded(cs, isDark),
    );
  }

  Widget _buildCollapsed(ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.secondaryBlue600.withValues(alpha: isDark ? 0.10 : 0.06),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: AppColors.secondaryBlue600.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.lightbulb_rounded,
                size: 16, color: AppColors.secondaryBlue600),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${widget.tips.length} dicas para esta aba — toque para expandir',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.secondaryBlue600,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: AppColors.secondaryBlue600),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(ColorScheme cs, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBlue600.withValues(alpha: isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.secondaryBlue600.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_rounded,
                      size: 16, color: AppColors.secondaryBlue600),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Dicas para esta aba',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.secondaryBlue600,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_up_rounded,
                      size: 16, color: AppColors.secondaryBlue600),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            color: AppColors.secondaryBlue600.withValues(alpha: 0.18),
          ),
          // Tip items
          ...widget.tips.asMap().entries.map((e) {
            final tip = e.value;
            final isLast = e.key == widget.tips.length - 1;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tip.color.withValues(
                              alpha: isDark ? 0.18 : 0.10),
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                        ),
                        child: Icon(tip.icon, size: 15, color: tip.color),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip.title,
                              style: AppTypography.labelSmall.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tip.body,
                              style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: AppSpacing.md + 30 + AppSpacing.sm,
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

// ─── ML Risk: Actions Row ─────────────────────────────────────────────────

class _MlRiskActionsRow extends ConsumerWidget {
  final int criticalCount;
  final List<RiskPrediction> predictions;

  const _MlRiskActionsRow({
    required this.criticalCount,
    required this.predictions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _ActionChip(
            icon: Icons.psychology_rounded,
            label: 'Ver IA Completa',
            color: AppColors.brandPrimary600,
            onTap: () => context.push(AppRoutes.mlInsights),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ActionChip(
            icon: Icons.local_shipping_rounded,
            label: 'Distribuir Críticos',
            color: criticalCount > 0 ? AppColors.danger600 : AppColors.neutral500,
            onTap: criticalCount > 0
                ? () => context.push(AppRoutes.movement)
                : null,
            badge: criticalCount > 0 ? '$criticalCount' : null,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _ActionChip(
            icon: Icons.share_rounded,
            label: 'Exportar Risco',
            color: AppColors.secondaryBlue600,
            onTap: predictions.isEmpty
                ? null
                : () => _exportRiskCsv(context, predictions),
          ),
        ),
      ],
    );
  }

  Future<void> _exportRiskCsv(
      BuildContext context, List<RiskPrediction> predictions) async {
    final buf = StringBuffer();
    buf.writeln('Produto,Nível de Risco,Confiança (%),Fonte');
    for (final p in predictions) {
      buf.writeln([
        '"${p.productName.replaceAll('"', '""')}"',
        p.level.label,
        (p.confidence * 100).toStringAsFixed(1),
        p.source,
      ].join(','));
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/risco_ml_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
          text: 'Relatório de Risco ML — EducaStock');
      if (!context.mounted) return;
      showCasaSnackbar(context,
          message: 'Lista de risco exportada!', isSuccess: true);
    } catch (_) {
      if (!context.mounted) return;
      showCasaSnackbar(context,
          message: 'Erro ao exportar. Tente novamente.', isSuccess: false);
    }
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String? badge;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onTap == null;
    final effectiveColor = disabled ? AppColors.neutral500 : color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: disabled ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: isDark ? 0.14 : 0.08),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
                color: effectiveColor.withValues(alpha: isDark ? 0.35 : 0.25)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: effectiveColor),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(
                      color: effectiveColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: effectiveColor,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
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

// ─── ML Risk: Confidence Distribution Chart ───────────────────────────────

class _MlConfidenceDistChart extends StatelessWidget {
  final List<RiskPrediction> predictions;
  final ColorScheme cs;
  final bool isDark;

  const _MlConfidenceDistChart({
    required this.predictions,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Buckets: <40%, 40-60%, 60-80%, 80-100%
    final bucketLabels = ['<40%', '40–60%', '60–80%', '>80%'];
    final vermelhos = predictions.where((p) => p.level == RiskLevel.vermelho).toList();
    final amarelos = predictions.where((p) => p.level == RiskLevel.amarelo).toList();
    final verdes = predictions.where((p) => p.level == RiskLevel.verde).toList();

    List<int> bucketsFor(List<RiskPrediction> list) {
      final b = [0, 0, 0, 0];
      for (final p in list) {
        final c = p.confidence;
        if (c < 0.4) b[0]++;
        else if (c < 0.6) b[1]++;
        else if (c < 0.8) b[2]++;
        else b[3]++;
      }
      return b;
    }

    final bV = bucketsFor(vermelhos);
    final bA = bucketsFor(amarelos);
    final bG = bucketsFor(verdes);

    final maxY = [
      ...bV, ...bA, ...bG
    ].fold<int>(0, (acc, v) => v > acc ? v : acc).toDouble();
    if (maxY == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxY * 1.2).ceilToDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      final labels = ['Crítico', 'Atenção', 'Seguro'];
                      return BarTooltipItem(
                        '${labels[ri]}: ${rod.toY.toInt()} lotes',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          bucketLabels[v.toInt()],
                          style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: AppTypography.labelSmall.copyWith(
                            fontSize: 9, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(4, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: bV[i].toDouble(),
                        color: AppColors.danger600,
                        width: 10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: bA[i].toDouble(),
                        color: AppColors.warning600,
                        width: 10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: bG[i].toDouble(),
                        color: AppColors.success600,
                        width: 10,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  );
                }),
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                  color: AppColors.danger600, label: 'Crítico'),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(
                  color: AppColors.warning600, label: 'Atenção'),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(
                  color: AppColors.success600, label: 'Seguro'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tab 4: Previsão de Consumo ───────────────────────────────────────────

class _ForecastReportTab extends ConsumerWidget {
  const _ForecastReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final forecastsAsync = ref.watch(liveForecastsProvider);
    final replenishCount = ref.watch(replenishmentCountProvider);
    final hasForecast = ref.watch(hasForecastDataProvider);

    final forecasts = forecastsAsync.valueOrNull ?? [];
    final critical = forecasts.where((f) => f.isCriticalStock).toList();
    final needsReplenishment =
        forecasts.where((f) => f.needsReplenishment).toList();
    final totalUnits = needsReplenishment.fold<int>(
        0, (sum, f) => sum + f.suggestedReplenishment);

    final prophets = forecasts.where((f) => f.isProphet).length;
    final movAvg = forecasts.where((f) => f.isMovingAverage).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
      children: [
        // ─── Botão de tutorial
        Align(
          alignment: Alignment.centerRight,
          child: buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: _forecastTutorialSteps(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // ─── Header section
        _SectionHeader(
          title: 'Previsão de Consumo',
          subtitle: 'Modelo Prophet (séries temporais)',
          icon: Icons.trending_up_rounded,
          color: AppColors.brandPrimary600,
          badge: 'Prophet',
        ),
        const SizedBox(height: AppSpacing.md),

        // ─── Quick actions
        Row(
          children: [
            Expanded(
              child: _ActionChip(
                icon: Icons.open_in_new_rounded,
                label: 'Ver Previsões',
                color: AppColors.brandPrimary600,
                onTap: () => context.push(AppRoutes.mlForecast),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _ActionChip(
                icon: Icons.add_shopping_cart_rounded,
                label: 'Gerar Pedido',
                color: AppColors.warning600,
                onTap: needsReplenishment.isEmpty
                    ? null
                    : () => _exportReplenishmentCsv(
                        context, needsReplenishment),
                badge: replenishCount > 0 ? '$replenishCount' : null,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _ActionChip(
                icon: Icons.science_rounded,
                label: 'Colab Notebook',
                color: AppColors.secondaryBlue600,
                onTap: hasForecast
                    ? () => showCasaSnackbar(context,
                        message: 'Execute o notebook: scripts/ml/consumption_forecast.ipynb',
                        isSuccess: true)
                    : () => showCasaSnackbar(context,
                        message: 'Abra scripts/ml/consumption_forecast.ipynb no Google Colab para gerar previsões.',
                        isSuccess: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        if (!hasForecast && forecastsAsync is! AsyncLoading) ...[
          _ForecastEmptyBanner(cs: cs, isDark: isDark),
          const SizedBox(height: AppSpacing.md),
        ],

        // ─── KPI grid
        if (hasForecast) ...[
          _ForecastKpiGrid(
            key: _keyForecastKpi,
            replenishCount: replenishCount,
            criticalCount: critical.length,
            totalUnits: totalUnits,
            totalProducts: forecasts.length,
            cs: cs,
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.md),

          // ─── Source distribution
          _ForecastSourceBanner(
            prophetCount: prophets,
            movAvgCount: movAvg,
            cs: cs,
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.md),

          // ─── Coverage chart
          _SectionHeader(
            title: 'Cobertura de Estoque',
            subtitle: 'Estoque atual vs previsão mensal',
            icon: Icons.analytics_rounded,
            color: AppColors.brandPrimary600,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ForecastCoverageChart(
            key: _keyForecastCoverage,
            forecasts: forecasts.take(8).toList(),
            cs: cs,
            isDark: isDark,
          ),
          const _ChartNote(
            text: 'Barras azuis = estoque atual. Barras verdes = previsão mensal. Abaixo da linha = precisa repor.',
          ),
          const SizedBox(height: AppSpacing.md),

          // ─── Trend donut
          _SectionHeader(
            title: 'Tendências de Consumo',
            subtitle: 'Distribuição entre produtos',
            icon: Icons.pie_chart_rounded,
            color: AppColors.secondaryBlue600,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ForecastTrendDonut(forecasts: forecasts, cs: cs, isDark: isDark),
          const _ChartNote(
            text: 'Crescente = consumo aumentando. Decrescente = consumo caindo.',
          ),
          const SizedBox(height: AppSpacing.md),

          // ─── Replenishment priority list
          if (needsReplenishment.isNotEmpty) ...[
            _SectionHeader(
              title: 'Lista de Reposição Prioritária',
              subtitle: 'Ordenado por urgência',
              icon: Icons.priority_high_rounded,
              color: AppColors.warning600,
              count: needsReplenishment.length,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              key: _keyForecastReplenish,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...needsReplenishment.take(10).map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _ForecastReplenishCard(
                            forecast: f,
                            cs: cs,
                            isDark: isDark,
                            onTap: () => _showForecastActionSheet(context, f),
                          ),
                        ),
                      ),
                ],
              ),
            ),
            if (needsReplenishment.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: AppSpacing.sm),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () => context.push(AppRoutes.mlForecast),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: Text(
                      'Ver todos os ${needsReplenishment.length} produtos',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.brandPrimary600),
                    ),
                  ),
                ),
              ),
          ],
        ],

        const SizedBox(height: AppSpacing.md),
        // ─── Tips
        _TabTipCard(
          tips: const [
            _TipItem(
              icon: Icons.science_rounded,
              color: AppColors.brandPrimary600,
              title: 'Como gerar previsões',
              body: 'Abra o arquivo scripts/ml/consumption_forecast.ipynb no Google Colab. Siga os passos para conectar ao Firestore e treinar o modelo Prophet.',
            ),
            _TipItem(
              icon: Icons.trending_up_rounded,
              color: AppColors.secondaryBlue600,
              title: 'Entendendo as Tendências',
              body: 'Crescente = consumo está aumentando — antecipe-se com mais estoque. Decrescente = consumo caindo — cuidado com excesso e vencimento.',
            ),
            _TipItem(
              icon: Icons.bar_chart_rounded,
              color: AppColors.warning600,
              title: 'Cobertura de Estoque',
              body: 'A barra azul mostra o estoque atual; a verde mostra o quanto deve ser consumido em 30 dias. Se azul < verde, precisa repor.',
            ),
            _TipItem(
              icon: Icons.add_shopping_cart_rounded,
              color: AppColors.success600,
              title: 'Gerar Pedido de Compra',
              body: 'Toque em "Gerar Pedido" para exportar um CSV com todos os produtos que precisam de reposição, incluindo a quantidade sugerida.',
            ),
          ],
          isDark: isDark,
          cs: cs,
        ),
      ],
    );
  }

  Future<void> _exportReplenishmentCsv(
      BuildContext context, List<ConsumptionForecast> forecasts) async {
    final buf = StringBuffer();
    buf.writeln('Produto,Previsão 7d,Previsão 30d,Estoque atual,Sugestão de reposição,Tendência,Modelo');
    for (final f in forecasts) {
      buf.writeln([
        '"${f.productName.replaceAll('"', '""')}"',
        f.forecastWeekly.toStringAsFixed(1),
        f.forecastMonthly.toStringAsFixed(1),
        f.currentStock,
        f.suggestedReplenishment,
        f.trend,
        f.source,
      ].join(','));
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/reposicao_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
          text: 'Pedido de Reposição — EducaStock');
      if (!context.mounted) return;
      showCasaSnackbar(context,
          message: 'Lista de reposição exportada!', isSuccess: true);
    } catch (_) {
      if (!context.mounted) return;
      showCasaSnackbar(context,
          message: 'Erro ao exportar.', isSuccess: false);
    }
  }
}

// ─── Forecast: Empty Banner ──────────────────────────────────────────────

class _ForecastEmptyBanner extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;

  const _ForecastEmptyBanner({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary600.withValues(alpha: 0.12),
            AppColors.secondaryBlue600.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.brandPrimary600.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.science_rounded,
            size: 36,
            color: AppColors.brandPrimary600.withValues(alpha: 0.7),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Previsões ainda não geradas',
            style: AppTypography.labelLarge.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Execute o notebook Prophet no Google Colab para gerar previsões de consumo.\nOs dados aparecerão aqui automaticamente.',
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded,
                    size: 14, color: AppColors.brandPrimary600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'scripts/ml/consumption_forecast.ipynb',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.brandPrimary600,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
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

// ─── Forecast: KPI Grid ───────────────────────────────────────────────────

class _ForecastKpiGrid extends StatelessWidget {
  final int replenishCount;
  final int criticalCount;
  final int totalUnits;
  final int totalProducts;
  final ColorScheme cs;
  final bool isDark;

  const _ForecastKpiGrid({
    super.key,
    required this.replenishCount,
    required this.criticalCount,
    required this.totalUnits,
    required this.totalProducts,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (
        Icons.inventory_rounded,
        AppColors.brandPrimary600,
        'Produtos\nAnalisados',
        '$totalProducts',
      ),
      (
        Icons.add_shopping_cart_rounded,
        AppColors.warning600,
        'Precisam\nRepor',
        '$replenishCount',
      ),
      (
        Icons.priority_high_rounded,
        AppColors.danger600,
        'Estoque\nCrítico',
        '$criticalCount',
      ),
      (
        Icons.local_shipping_rounded,
        AppColors.secondaryBlue600,
        'Unidades\nSugeridas',
        '$totalUnits',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.2,
      children: tiles
          .map((t) => _ForecastKpiTile(
                icon: t.$1,
                color: t.$2,
                label: t.$3,
                value: t.$4,
                cs: cs,
                isDark: isDark,
              ))
          .toList(),
    );
  }
}

class _ForecastKpiTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final ColorScheme cs;
  final bool isDark;

  const _ForecastKpiTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTypography.labelLarge.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    height: 1.2,
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

// ─── Forecast: Source Banner ──────────────────────────────────────────────

class _ForecastSourceBanner extends StatelessWidget {
  final int prophetCount;
  final int movAvgCount;
  final ColorScheme cs;
  final bool isDark;

  const _ForecastSourceBanner({
    required this.prophetCount,
    required this.movAvgCount,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = prophetCount + movAvgCount;
    if (total == 0) return const SizedBox.shrink();
    final prophetPct = total == 0 ? 0.0 : prophetCount / total;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded,
                  size: 14, color: AppColors.brandPrimary600),
              const SizedBox(width: 6),
              Text(
                'Origem das Previsões',
                style: AppTypography.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Stack(
                    children: [
                      Container(
                          height: 20,
                          color: AppColors.neutral500
                              .withValues(alpha: 0.2)),
                      FractionallySizedBox(
                        widthFactor: prophetPct.clamp(0.0, 1.0),
                        child: Container(
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.brandPrimary600,
                                AppColors.secondaryBlue600,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          AppColors.brandPrimary600,
                          AppColors.secondaryBlue600,
                        ]),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      )),
                  const SizedBox(width: 4),
                  Text(
                    'Prophet: $prophetCount (${(prophetPct * 100).toStringAsFixed(0)}%)',
                    style: AppTypography.labelSmall.copyWith(
                        color: AppColors.brandPrimary600,
                        fontWeight: FontWeight.w600,
                        fontSize: 11),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.neutral500
                            .withValues(alpha: 0.5),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      )),
                  const SizedBox(width: 4),
                  Text(
                    'Média Móvel: $movAvgCount',
                    style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Forecast: Coverage Chart ─────────────────────────────────────────────

class _ForecastCoverageChart extends StatelessWidget {
  final List<ConsumptionForecast> forecasts;
  final ColorScheme cs;
  final bool isDark;

  const _ForecastCoverageChart({
    super.key,
    required this.forecasts,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (forecasts.isEmpty) return const SizedBox.shrink();

    final items = forecasts.take(8).toList();
    final maxVal = items
        .map((f) => math.max(f.currentStock.toDouble(), f.forecastMonthly))
        .fold<double>(0.0, (acc, v) => v > acc ? v : acc);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxVal * 1.2).ceilToDouble(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      final f = items[gi];
                      final label = ri == 0 ? 'Atual: ${f.currentStock}' : 'Previsão: ${f.forecastMonthly.toStringAsFixed(0)}';
                      return BarTooltipItem(
                        '${f.productName}\n$label',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= items.length) {
                          return const SizedBox.shrink();
                        }
                        final name = items[idx].productName;
                        final short = name.length > 6
                            ? name.substring(0, 6)
                            : name;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            short,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 8,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: AppTypography.labelSmall.copyWith(
                            fontSize: 9,
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: items.asMap().entries.map((e) {
                  final i = e.key;
                  final f = e.value;
                  final isLow = f.isCriticalStock;
                  final stockColor = isLow
                      ? AppColors.danger600
                      : f.isLowStock
                          ? AppColors.warning600
                          : AppColors.secondaryBlue600;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: f.currentStock.toDouble(),
                        color: stockColor,
                        width: 12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: f.forecastMonthly,
                        color: AppColors.success600
                            .withValues(alpha: 0.6),
                        width: 12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                  color: AppColors.secondaryBlue600,
                  label: 'Estoque Atual'),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(
                  color: AppColors.success600.withValues(alpha: 0.6),
                  label: 'Previsão 30d'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Forecast: Trend Donut Chart ──────────────────────────────────────────

class _ForecastTrendDonut extends StatefulWidget {
  final List<ConsumptionForecast> forecasts;
  final ColorScheme cs;
  final bool isDark;

  const _ForecastTrendDonut({
    required this.forecasts,
    required this.cs,
    required this.isDark,
  });

  @override
  State<_ForecastTrendDonut> createState() => _ForecastTrendDonutState();
}

class _ForecastTrendDonutState extends State<_ForecastTrendDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final increasing =
        widget.forecasts.where((f) => f.trend == 'increasing').length;
    final stable =
        widget.forecasts.where((f) => f.trend == 'stable').length;
    final decreasing =
        widget.forecasts.where((f) => f.trend == 'decreasing').length;
    final total = increasing + stable + decreasing;

    if (total == 0) return const SizedBox.shrink();

    final items = [
      (increasing, AppColors.danger600, 'Crescente', Icons.trending_up_rounded),
      (stable, AppColors.neutral500, 'Estável', Icons.trending_flat_rounded),
      (decreasing, AppColors.success600, 'Decrescente', Icons.trending_down_rounded),
    ];

    final sections = items.asMap().entries.map((e) {
      final isTouched = e.key == _touched;
      final count = e.value.$1;
      final color = e.value.$2;
      final pct = total == 0 ? 0.0 : count / total * 100;
      return PieChartSectionData(
        color: color,
        value: count == 0 ? 0.001 : count.toDouble(),
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 52 : 42,
        titleStyle: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w800),
        borderSide: isTouched
            ? BorderSide(
                color: Colors.white.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 36,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (ev, resp) {
                        setState(() {
                          if (!ev.isInterestedForInteractions ||
                              resp == null ||
                              resp.touchedSection == null) {
                            _touched = -1;
                            return;
                          }
                          _touched = resp
                              .touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'produtos',
                      style: TextStyle(
                        fontSize: 8,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                final pct =
                    total == 0 ? 0.0 : item.$1 / total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(item.$4, size: 14, color: item.$2),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.$3,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${item.$1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: item.$2,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '(${pct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor:
                              cs.outlineVariant.withValues(alpha: 0.25),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(item.$2),
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

// ─── Forecast: Replenishment Card ─────────────────────────────────────────

class _ForecastReplenishCard extends StatelessWidget {
  final ConsumptionForecast forecast;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback? onTap;

  const _ForecastReplenishCard({
    required this.forecast,
    required this.cs,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final urgencyColor = forecast.isCriticalStock
        ? AppColors.danger600
        : forecast.isLowStock
            ? AppColors.warning600
            : AppColors.brandPrimary600;
    final urgencyLabel = forecast.isCriticalStock
        ? 'Crítico'
        : forecast.isLowStock
            ? 'Atenção'
            : 'Repor';
    final daysLeft = forecast.daysOfStockRemaining.clamp(0, 999).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: urgencyColor.withValues(
                alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Row(
        children: [
          // Lateral color strip
          Container(
            width: 4,
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  urgencyColor,
                  urgencyColor.withValues(alpha: 0.5)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppRadius.card)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: urgencyColor.withValues(
                  alpha: isDark ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Center(
              child: Text(
                '+${forecast.suggestedReplenishment}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: urgencyColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          forecast.productName,
                          style: AppTypography.labelMedium.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: urgencyColor.withValues(
                              alpha: isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(
                              AppRadius.pill),
                        ),
                        child: Text(
                          urgencyLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: urgencyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    daysLeft < 999
                        ? 'Estoque para ~$daysLeft dias · Previsão 30d: ${forecast.forecastMonthly.toStringAsFixed(0)} un.'
                        : 'Previsão mensal: ${forecast.forecastMonthly.toStringAsFixed(0)} un. · Sem saídas registradas',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SourceBadge(forecast: forecast),
                      const SizedBox(width: 4),
                      TrendChip(
                        trend: forecast.trend,
                        trendPercent: forecast.trendPercent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),  // closes Container
    );  // closes GestureDetector
  }
}



// ─── Forecast Action Sheet ────────────────────────────────────────────────

void _showForecastActionSheet(
    BuildContext context, ConsumptionForecast forecast) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ForecastActionSheet(forecast: forecast),
  );
}

class _ForecastActionSheet extends StatelessWidget {
  final ConsumptionForecast forecast;
  const _ForecastActionSheet({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urgencyColor = forecast.isCriticalStock
        ? AppColors.danger600
        : forecast.isLowStock
            ? AppColors.warning600
            : AppColors.brandPrimary600;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.modal)),
        ),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            // Info header
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: urgencyColor.withValues(alpha: isDark ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border:
                    Border.all(color: urgencyColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          forecast.productName,
                          style: AppTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TrendChip(
                          trend: forecast.trend,
                          trendPercent: forecast.trendPercent),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _ForecastStatChip(
                        label: 'Estoque',
                        value: '${forecast.currentStock} un.',
                        color: urgencyColor,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _ForecastStatChip(
                        label: 'Prev. 30d',
                        value:
                            '${forecast.forecastMonthly.toStringAsFixed(0)} un.',
                        color: AppColors.secondaryBlue600,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _ForecastStatChip(
                        label: 'Sugerir repor',
                        value: '+${forecast.suggestedReplenishment} un.',
                        color: AppColors.success600,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Ações disponíveis',
              style: AppTypography.labelMedium.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ActionTile(
              icon: Icons.add_circle_outline_rounded,
              label: 'Registrar entrada de estoque',
              description:
                  'Adicione ${forecast.suggestedReplenishment} unidades ao estoque',
              color: AppColors.success600,
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.movement);
              },
              cs: cs,
            ),
            const SizedBox(height: AppSpacing.xs),
            _ActionTile(
              icon: Icons.file_download_outlined,
              label: 'Exportar pedido deste produto',
              description:
                  'Gera CSV com sugestão de ${forecast.suggestedReplenishment} unidades',
              color: AppColors.warning600,
              onTap: () {
                Navigator.of(context).pop();
                _exportSingleForecastCsv(context, forecast);
              },
              cs: cs,
            ),
            const SizedBox(height: AppSpacing.xs),
            _ActionTile(
              icon: Icons.trending_up_rounded,
              label: 'Ver previsão completa',
              description: 'Histórico e série temporal do produto',
              color: AppColors.brandPrimary600,
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.mlForecast);
              },
              cs: cs,
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ForecastStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

Future<void> _exportSingleForecastCsv(
    BuildContext context, ConsumptionForecast f) async {
  final buf = StringBuffer();
  buf.writeln(
      'Produto,Previsão 7d,Previsão 30d,Estoque atual,Sugestão de reposição,Tendência,Modelo');
  buf.writeln([
    '"${f.productName.replaceAll('"', '""')}"',
    f.forecastWeekly.toStringAsFixed(1),
    f.forecastMonthly.toStringAsFixed(1),
    f.currentStock,
    f.suggestedReplenishment,
    f.trend,
    f.source,
  ].join(','));
  try {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/pedido_${f.productId}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buf.toString());
    await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
        text: 'Pedido — ${f.productName}');
    if (!context.mounted) return;
    showCasaSnackbar(context,
        message: 'Pedido exportado!', isSuccess: true);
  } catch (_) {
    if (!context.mounted) return;
    showCasaSnackbar(context,
        message: 'Erro ao exportar.', isSuccess: false);
  }
}

// ─── Grid de resumo (kept for reference) ─────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final int totalBatches;
  final int totalItems;
  final double totalValue;
  final int expired;
  final int criticals;
  final int warnings;
  final int healthScore;
  final bool isDark;
  final ColorScheme cs;
  const _SummaryGrid(
      {required this.totalBatches,
      required this.totalItems,
      required this.totalValue,
      required this.expired,
      required this.criticals,
      required this.warnings,
      required this.healthScore,
      required this.isDark,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final healthColor = healthScore >= 80
        ? AppColors.success600
        : healthScore >= 50
            ? AppColors.warning600
            : AppColors.danger600;
    final cards = [
      _SummaryDef('Lotes', '$totalBatches', Icons.layers_rounded,
          AppColors.brandPrimary600),
      _SummaryDef('Itens', '$totalItems', Icons.widgets_outlined,
          AppColors.secondaryBlue600),
      _SummaryDef('Valor est.', currFmt.format(totalValue),
          Icons.attach_money_rounded, AppColors.success600),
      _SummaryDef('Saúde', '$healthScore%',
          Icons.favorite_rounded, healthColor),
      _SummaryDef('Críticos', '$criticals', Icons.warning_rounded,
          criticals > 0 ? AppColors.danger600 : AppColors.success600),
      _SummaryDef('Vencidos', '$expired', Icons.cancel_outlined,
          expired > 0 ? AppColors.danger600 : AppColors.success600),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.4,
      children: cards.map((d) => _SummaryCard(def: d, cs: cs)).toList(),
    );
  }
}

class _SummaryDef {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryDef(this.label, this.value, this.icon, this.color);
}

class _SummaryCard extends StatelessWidget {
  final _SummaryDef def;
  final ColorScheme cs;
  const _SummaryCard({required this.def, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: def.color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(def.icon, size: 14, color: def.color),
            const SizedBox(width: 4),
            Text(def.label,
                style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurfaceVariant, fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          Text(
            def.value,
            style: AppTypography.headingSmall.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Gráfico de linha: tendência mensal ──────────────────────────────────

class _MonthlyTrendChart extends StatelessWidget {
  final Map<String, int> monthTrend;
  final bool isDark;
  final ColorScheme cs;
  const _MonthlyTrendChart(
      {required this.monthTrend, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final keys = monthTrend.keys.toList();
    final values = keys.map((k) => monthTrend[k]!.toDouble()).toList();
    final maxVal = values.fold(0.0, math.max);

    if (maxVal == 0) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Text('Sem entradas nos últimos 6 meses',
              style: AppTypography.bodySmall
                  .copyWith(color: cs.onSurfaceVariant)),
        ),
      );
    }

    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      height: 210,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxVal * 1.3,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max(1, maxVal / 4),
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.25),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= keys.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      keys[idx],
                      style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) {
                  if (v == 0) return const SizedBox.shrink();
                  return Text(
                    v.toInt().toString(),
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainer,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toInt()} un.',
                        TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 11),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.4,
              gradient: const LinearGradient(
                colors: [
                  AppColors.brandPrimary600,
                  AppColors.secondaryBlue600,
                ],
              ),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, pct, bar, idx) =>
                    FlDotCirclePainter(
                  radius: 4.5,
                  color: AppColors.brandPrimary600,
                  strokeColor: cs.surface,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.brandPrimary600.withValues(alpha: 0.28),
                    AppColors.secondaryBlue600.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      ),
    );
  }
}

// ─── Gráfico de barras: validade ─────────────────────────────────────────

class _ExpiryBarChart extends StatelessWidget {
  final Map<String, int> buckets;
  final bool isDark;
  final ColorScheme cs;
  const _ExpiryBarChart(
      {required this.buckets, required this.isDark, required this.cs});

  Color _bucketColor(String key) {
    switch (key) {
      case 'Vencido':
        return AppColors.danger600;
      case '0–7d':
        return AppColors.danger600.withValues(alpha: 0.7);
      case '8–30d':
        return AppColors.warning600;
      case '31–90d':
        return AppColors.success600.withValues(alpha: 0.7);
      case '>90d':
        return AppColors.success600;
      default:
        return AppColors.brandPrimary600.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = buckets.keys.toList();
    final maxVal =
        buckets.values.fold(0, (a, b) => math.max(a, b)).toDouble();
    if (maxVal == 0) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Sem dados')),
      );
    }

    final barGroups = keys.asMap().entries.map((e) {
      final barColor = _bucketColor(e.value);
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: buckets[e.value]!.toDouble(),
            gradient: LinearGradient(
              colors: [barColor, barColor.withValues(alpha: 0.7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal * 1.3,
              color: cs.surfaceContainer,
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      height: 230,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          maxY: maxVal * 1.3,
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxVal == 0 ? 1 : maxVal / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.25),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final key = keys[v.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      key,
                      style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  if (v == 0) return const SizedBox.shrink();
                  return Text(
                    v.toInt().toString(),
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainer,
              getTooltipItem: (group, gI, rod, rI) {
                return BarTooltipItem(
                  '${rod.toY.toInt()} lote${rod.toY.toInt() != 1 ? 's' : ''}',
                  TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                );
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      ),
    );
  }
}

// ─── Batch List Sheet (Charts tab alert chips) ───────────────────────────

void _showBatchListSheet(
  BuildContext context, {
  required String title,
  required List<Batch> batches,
  required Color color,
  required IconData icon,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _BatchListSheet(
      title: title,
      batches: batches,
      color: color,
      icon: icon,
    ),
  );
}

class _BatchListSheet extends StatelessWidget {
  final String title;
  final List<Batch> batches;
  final Color color;
  final IconData icon;

  const _BatchListSheet({
    required this.title,
    required this.batches,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd/MM/yyyy');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.modal)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                            color: cs.outlineVariant,
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface),
                              ),
                              Text(
                                '${batches.length} lote${batches.length != 1 ? 's' : ''}',
                                style: AppTypography.bodySmall
                                    .copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Divider(
                        color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                  itemCount: batches.length,
                  separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.2)),
                  itemBuilder: (_, i) {
                    final b = batches[i];
                    final days = b.noExpiry ? null : b.daysToExpiry;
                    final daysText = b.noExpiry
                        ? 'Sem validade'
                        : b.isExpired
                            ? 'Vencido há ${-days!}d'
                            : 'Vence em ${days}d';
                    final daysColor = b.isExpired
                        ? AppColors.danger600
                        : days != null && days <= 7
                            ? AppColors.danger600
                            : days != null && days <= 30
                                ? AppColors.warning600
                                : AppColors.success600;
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: daysColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.productName,
                                  style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${b.quantity} un.'
                                  '${b.expiryDate != null ? ' · ${dateFmt.format(b.expiryDate!)}' : ''}',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            daysText,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: daysColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Gráfico de pizza: categorias ────────────────────────────────────────

class _CategoryPieChart extends StatefulWidget {
  final Map<String, int> catCount;
  final Map<String, String> labelMap;
  final bool isDark;
  final ColorScheme cs;
  const _CategoryPieChart(
      {required this.catCount,
      required this.labelMap,
      required this.isDark,
      required this.cs});

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int _touched = -1;

  static const _pieColors = [
    AppColors.brandPrimary600,
    AppColors.secondaryBlue600,
    AppColors.success600,
    AppColors.warning600,
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    AppColors.danger600,
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final entries = widget.catCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (s, e) => s + e.value);

    final sections = entries.asMap().entries.map((e) {
      final isTouched = e.key == _touched;
      final color = _pieColors[e.key % _pieColors.length];
      final pct = total == 0 ? 0.0 : e.value.value / total * 100;
      return PieChartSectionData(
        color: color,
        value: e.value.value.toDouble(),
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 72 : 60,
        titleStyle: const TextStyle(
            fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800),
        borderSide: isTouched
            ? BorderSide(
                color: Colors.white.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (ev, resp) {
                    setState(() {
                      if (!ev.isInterestedForInteractions ||
                          resp == null ||
                          resp.touchedSection == null) {
                        _touched = -1;
                        return;
                      }
                      _touched =
                          resp.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((e) {
                final color = _pieColors[e.key % _pieColors.length];
                final label = widget.labelMap[e.value.key] ?? e.value.key;
                final pct = total == 0
                    ? 0.0
                    : e.value.value / total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value.value}',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w700),
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

// ─── Insights automáticos ─────────────────────────────────────────────────

class _InsightDef {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _InsightDef(this.icon, this.title, this.description, this.color);
}

List<_InsightDef> _buildInsights({
  required List<Batch> batches,
  required int exp7,
  required int exp30,
  required int expired,
  required int totalItems,
}) {
  final insights = <_InsightDef>[];

  if (expired > 0) {
    insights.add(_InsightDef(
      Icons.cancel_outlined,
      'Lotes vencidos detectados',
      'Há $expired lote${expired > 1 ? 's' : ''} com validade ultrapassada. Faça a baixa imediatamente.',
      AppColors.danger600,
    ));
  }
  if (exp7 > 0) {
    insights.add(_InsightDef(
      Icons.warning_rounded,
      'Ação urgente necessária',
      '$exp7 lote${exp7 > 1 ? 's' : ''} vence${exp7 == 1 ? '' : 'm'} em até 7 dias. Priorize o uso ou descarte.',
      AppColors.danger600,
    ));
  }
  if (exp30 > exp7 + expired) {
    insights.add(_InsightDef(
      Icons.schedule_rounded,
      'Planejar consumo em breve',
      '${exp30 - exp7 - expired} lotes vencem entre 8 e 30 dias. Programe distribuição com antecedência.',
      AppColors.warning600,
    ));
  }

  if (batches.isNotEmpty) {
    final Map<String, int> prodQty = {};
    for (final b in batches) {
      prodQty[b.productName] = (prodQty[b.productName] ?? 0) + b.quantity;
    }
    final sorted = prodQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isNotEmpty && totalItems > 0) {
      final topPct = sorted.first.value / totalItems * 100;
      if (topPct > 50) {
        insights.add(_InsightDef(
          Icons.pie_chart_outline_rounded,
          'Estoque concentrado',
          '${sorted.first.key} representa ${topPct.toStringAsFixed(0)}% do estoque total. Diversifique.',
          AppColors.secondaryBlue600,
        ));
      }
    }
  }

  if (insights.isEmpty) {
    insights.add(const _InsightDef(
      Icons.check_circle_outline_rounded,
      'Estoque saudável',
      'Nenhuma anomalia detectada. Continue monitorando as validades regularmente.',
      AppColors.success600,
    ));
  }

  return insights;
}

class _InsightsPanel extends StatelessWidget {
  final List<_InsightDef> insights;
  const _InsightsPanel({super.key, required this.insights});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: insights.map((insight) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          insight.color,
                          insight.color.withValues(alpha: 0.5)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: insight.color.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          child: Icon(insight.icon,
                              color: insight.color, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                insight.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
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
      }).toList(),
    );
  }
}

// ─── Lista de próximos a vencer (agrupada por urgência) ───────────────────

class _ExpiryList extends StatelessWidget {
  final List<Batch> batches;
  final ColorScheme cs;
  final bool isDark;
  const _ExpiryList(
      {required this.batches, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final critical =
        batches.where((b) => !b.noExpiry && b.daysToExpiry <= 7).toList();
    final warning =
        batches.where((b) => b.noExpiry || b.daysToExpiry > 7).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (critical.isNotEmpty) ...[
          _ExpiryGroupHeader(
            label: 'Crítico — vence em até 7 dias',
            color: AppColors.danger600,
            count: critical.length,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ExpirySection(batches: critical, cs: cs),
          const SizedBox(height: AppSpacing.md),
        ],
        if (warning.isNotEmpty) ...[
          _ExpiryGroupHeader(
            label: 'Atenção — vence entre 8 e 30 dias',
            color: AppColors.warning600,
            count: warning.length,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ExpirySection(batches: warning, cs: cs),
        ],
      ],
    );
  }
}

class _ExpiryGroupHeader extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  const _ExpiryGroupHeader(
      {required this.label, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpirySection extends StatelessWidget {
  final List<Batch> batches;
  final ColorScheme cs;
  const _ExpirySection({required this.batches, required this.cs});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: batches.take(15).toList().asMap().entries.map((e) {
          final b = e.value;
          final days = b.noExpiry ? 9999 : b.daysToExpiry;
          final urgentColor =
              days <= 7 ? AppColors.danger600 : AppColors.warning600;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (e.key > 0)
                Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: urgentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            b.productName,
                            style: AppTypography.labelMedium
                                .copyWith(color: cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                b.expiryDate != null
                                    ? fmt.format(b.expiryDate!)
                                    : '-',
                                style: AppTypography.bodySmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text('• ${b.quantity} un.',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        b.noExpiry ? 'Sem val.' : '${days}d',
                        style: TextStyle(
                          fontSize: 12,
                          color: urgentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

