import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../ml/domain/entities/risk_prediction.dart';
import '../../../ml/presentation/controllers/risk_classifier_provider.dart';
import '../../../stock/presentation/pages/movement_page.dart';

final auditLogsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(stockDatasourceProvider).watchAuditLogs(limit: 100);
});

Future<void> _exportAuditCsv(
    BuildContext context, List<Map<String, dynamic>> logs) async {
  final buffer = StringBuffer();
  buffer.writeln('Data,Hora,Ação,Usuário,Antes,Depois');
  final fmt = DateFormat('dd/MM/yyyy');
  final fmtTime = DateFormat('HH:mm');
  for (final log in logs) {
    final action = log['action'] as String? ?? '';
    final performedAt = log['performedAt'] as String? ?? '';
    DateTime? date;
    try {
      date = DateTime.parse(performedAt);
    } catch (_) {}
    final user = log['performedByName'] as String? ?? '';
    final before =
        log['before']?.toString().replaceAll('"', '""') ?? '';
    final after =
        log['after']?.toString().replaceAll('"', '""') ?? '';
    buffer.writeln([
      '"${date != null ? fmt.format(date) : ''}"',
      '"${date != null ? fmtTime.format(date) : ''}"',
      '"$action"',
      '"$user"',
      '"$before"',
      '"$after"',
    ].join(','));
  }
  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/auditoria_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(buffer.toString());
  await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      text: 'Auditoria EducaStock');
}

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  String? _filterAction;
  DateTimeRange? _filterDateRange;
  String? _filterUser;
  final _keyAuditList = GlobalKey();
  final _keyFilterBtn = GlobalKey();
  final _keyExportBtn = GlobalKey();
  final _keyAuditTile = GlobalKey();

  int get _activeFilterCount =>
      (_filterAction != null ? 1 : 0) +
      (_filterDateRange != null ? 1 : 0) +
      (_filterUser != null && _filterUser!.isNotEmpty ? 1 : 0);

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> logs) {
    var filtered = logs;
    if (_filterAction != null) {
      filtered = filtered
          .where((l) => (l['action'] as String?) == _filterAction)
          .toList();
    }
    if (_filterDateRange != null) {
      filtered = filtered.where((l) {
        final performedAt = l['performedAt'] as String? ?? '';
        try {
          final date = DateTime.parse(performedAt);
          return !date.isBefore(_filterDateRange!.start) &&
              !date.isAfter(_filterDateRange!.end
                  .add(const Duration(hours: 23, minutes: 59)));
        } catch (_) {
          return false;
        }
      }).toList();
    }
    if (_filterUser != null && _filterUser!.isNotEmpty) {
      final query = _filterUser!.toLowerCase();
      filtered = filtered
          .where((l) => (l['performedByName'] as String? ?? '')
              .toLowerCase()
              .contains(query))
          .toList();
    }
    return filtered;
  }

  Future<void> _showFilterBottomSheet(BuildContext context) async {
    String? tmpAction = _filterAction;
    DateTimeRange? tmpRange = _filterDateRange;
    String? tmpUser = _filterUser;
    final userController = TextEditingController(text: tmpUser ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
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
                Text('Filtrar Auditoria',
                    style: AppTypography.headingSmall),
                const SizedBox(height: AppSpacing.lg),
                Text('Tipo de ação',
                    style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    null,
                    'entrada',
                    'saida',
                    'ajustePositivo',
                    'ajusteNegativo',
                    'descarte',
                  ].map((a) {
                    final label = a == null
                        ? 'Todos'
                        : switch (a) {
                            'entrada' => 'Entrada',
                            'saida' => 'Saída',
                            'ajustePositivo' => 'Ajuste +',
                            'ajusteNegativo' => 'Ajuste -',
                            'descarte' => 'Descarte',
                            _ => a,
                          };
                    final selected = tmpAction == a;
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setModal(() => tmpAction = a),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Período',
                    style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    _PeriodChip(
                      label: 'Hoje',
                      selected: tmpRange != null &&
                          tmpRange!.duration.inHours < 25,
                      onTap: () {
                        final now = DateTime.now();
                        setModal(() => tmpRange = DateTimeRange(
                            start: DateTime(now.year, now.month, now.day),
                            end: now));
                      },
                    ),
                    _PeriodChip(
                      label: '7 dias',
                      selected: tmpRange != null &&
                          tmpRange!.duration.inDays >= 6 &&
                          tmpRange!.duration.inDays <= 8,
                      onTap: () {
                        final now = DateTime.now();
                        setModal(() => tmpRange = DateTimeRange(
                            start: now.subtract(const Duration(days: 7)),
                            end: now));
                      },
                    ),
                    _PeriodChip(
                      label: '30 dias',
                      selected: tmpRange != null &&
                          tmpRange!.duration.inDays >= 29 &&
                          tmpRange!.duration.inDays <= 31,
                      onTap: () {
                        final now = DateTime.now();
                        setModal(() => tmpRange = DateTimeRange(
                            start: now.subtract(const Duration(days: 30)),
                            end: now));
                      },
                    ),
                    _PeriodChip(
                      label: 'Personalizado',
                      selected: false,
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: tmpRange,
                        );
                        if (picked != null) {
                          setModal(() => tmpRange = picked);
                        }
                      },
                    ),
                  ],
                ),
                if (tmpRange != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(tmpRange!.start)} → ${DateFormat('dd/MM/yyyy').format(tmpRange!.end)}',
                    style: AppTypography.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Usuário',
                    style: AppTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: TextField(
                    controller: userController,
                    onChanged: (v) {
                      setModal(() => tmpUser = v.isEmpty ? null : v);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Filtrar por nome do usuário',
                      prefixIcon: Icon(Icons.person_search_rounded),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModal(() {
                            tmpAction = null;
                            tmpRange = null;
                            tmpUser = null;
                            userController.clear();
                          });
                        },
                        child: const Text('Limpar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _filterAction = tmpAction;
                            _filterDateRange = tmpRange;
                            _filterUser = tmpUser;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Aplicar'),
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
    userController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Auditoria',
        subtitle: 'Histórico de alterações críticas',
        pageIcon: Icons.shield_rounded,
        iconColor: const Color(0xFF22C55E),
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyFilterBtn,
                  title: 'Filtros de Auditoria',
                  description: 'Toque no ícone de filtro para abrir um bottom sheet onde você pode filtrar por tipo de ação (criar/editar/excluir), por usuário, por entidade (produto/lote/categoria) e por intervalo de datas. O badge azul mostra quantos filtros estão ativos.',
                  icon: Icons.filter_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🔵 "create" = novos cadastros (produtos, lotes, etc)',
                    '🟡 "update" = edições e alterações',
                    '🔴 "delete" = exclusões e descartes',
                    'Combine filtros para investigar incidentes específicos',
                  ],
                ),
                TutorialStep(
                  key: _keyExportBtn,
                  title: 'Exportar para CSV',
                  description: 'O ícone de download exporta os registros filtrados em formato CSV (planilha). Essencial para auditoria externa, prestação de contas a doadores ou análise em Excel/Google Sheets.',
                  icon: Icons.download_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Exporta APENAS os registros após aplicar filtros',
                    'O arquivo abre direto no Excel e Google Sheets',
                    'Inclui colunas: data, usuário, ação, entidade, antes, depois',
                    'Use para relatórios mensais de governança',
                  ],
                ),
                TutorialStep(
                  key: _keyAuditList,
                  title: 'Registro Imutável',
                  description: 'Esta é a lista cronológica de todas as ações realizadas no sistema, em ordem mais recente primeiro. NADA pode ser apagado ou editado — é um log de auditoria à prova de adulteração para compliance e investigação.',
                  icon: Icons.security_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Cada ação é registrada com timestamp e autor',
                    'Mudanças de quantidade aparecem como "antes → depois"',
                    'Mesmo admins NÃO podem apagar logs (proteção)',
                    'Investigação de roubo/perda começa por aqui',
                  ],
                ),
                TutorialStep(
                  key: _keyAuditTile,
                  title: 'Detalhes do Evento',
                  description: 'Cada card é um evento registrado: você vê o ícone da ação (criar/editar/excluir), o nome do usuário, o produto ou entidade afetada e o horário exato. Para edições, mostra o valor antes e depois da mudança.',
                  icon: Icons.fact_check_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Ícone verde = criação | azul = edição | vermelho = exclusão',
                    'Toque para ver detalhes completos em modal',
                    'Acompanhe responsabilidades por colaboradora',
                    'Combine com Histórico de Saídas para visão completa',
                  ],
                ),
              ],
            ),
          ),
          logsAsync.whenData((logs) {
            final filtered = _applyFilters(logs);
            return IconButton(
              key: _keyExportBtn,
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Exportar CSV',
              onPressed: () => _exportAuditCsv(context, filtered),
            );
          }).valueOrNull ??
              const SizedBox.shrink(),
          Stack(
              key: _keyFilterBtn,
              children: [
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filtros',
                onPressed: () => _showFilterBottomSheet(context),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary600,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      Expanded(child: logsAsync.when(
          data: (logs) {
            final filtered = _applyFilters(logs);
            if (filtered.isEmpty) {
              return const CasaEmptyState(
                icon: Icons.history_rounded,
                title: 'Nenhum log registrado',
                description: 'As alterações críticas aparecerão aqui.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              itemCount: filtered.length + 1, // +1 para o snapshot ML
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                if (i == 0) return const _AuditMlSnapshotCard();
                final realIdx = i - 1;
                final tile = _AuditLogTile(log: filtered[realIdx], cs: cs);
                if (realIdx == 0) {
                  return KeyedSubtree(key: _keyAuditList, child: tile);
                }
                if (realIdx == 1) {
                  return KeyedSubtree(key: _keyAuditTile, child: tile);
                }
                return tile;
              },
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 8,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar',
            description: e.toString(),
          ),
        ),
      ),
      ]),
    );
  }
}

// ─── Period chip helper ───────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );
}

class _AuditLogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final ColorScheme cs;
  const _AuditLogTile({required this.log, required this.cs});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final action = log['action'] as String? ?? '';
    final performedAt = log['performedAt'] as String? ?? '';
    final performedByName =
        log['performedByName'] as String? ?? 'Desconhecido';
    DateTime? date;
    try {
      date = DateTime.parse(performedAt);
    } catch (_) {}

    final color = switch (action) {
      'entrada' || 'ajustePositivo' => AppColors.success600,
      'saida' => AppColors.brandPrimary600,
      'ajusteNegativo' => AppColors.warning600,
      'descarte' => AppColors.danger600,
      _ => AppColors.neutral500,
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: color, width: 3),
          top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(_actionIcon(action), color: color, size: 18),
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
                        _actionLabel(action),
                        style: AppTypography.labelMedium.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (date != null)
                      Text(
                        fmt.format(date),
                        style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant, fontSize: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Por: $performedByName',
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                if (log['before'] != null || log['after'] != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius:
                          BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      'Antes: ${log['before']}  →  Depois: ${log['after']}',
                      style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(String action) => switch (action) {
        'entrada' => 'Entrada registrada',
        'saida' => 'Saída registrada',
        'ajustePositivo' => 'Ajuste positivo',
        'ajusteNegativo' => 'Ajuste negativo',
        'descarte' => 'Descarte registrado',
        _ => 'Operação: $action',
      };

  IconData _actionIcon(String action) => switch (action) {
        'entrada' => Icons.add_circle_outline_rounded,
        'saida' => Icons.outbound_rounded,
        'ajustePositivo' => Icons.trending_up_rounded,
        'ajusteNegativo' => Icons.trending_down_rounded,
        'descarte' => Icons.delete_outline_rounded,
        _ => Icons.history_rounded,
      };
}

// ─── ML Snapshot card (no topo do audit) ────────────────────────────────────

class _AuditMlSnapshotCard extends ConsumerWidget {
  const _AuditMlSnapshotCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final countsAsync = ref.watch(riskCountsProvider);
    final counts = countsAsync.valueOrNull ?? const {};
    final total = counts.values.fold<int>(0, (s, v) => s + v);

    final red = counts[RiskLevel.vermelho] ?? 0;
    final yellow = counts[RiskLevel.amarelo] ?? 0;
    final green = counts[RiskLevel.verde] ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary600
                .withValues(alpha: isDark ? 0.18 : 0.08),
            AppColors.secondaryBlue600
                .withValues(alpha: isDark ? 0.10 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.brandPrimary600
                .withValues(alpha: isDark ? 0.35 : 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600,
                  ]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Snapshot ML — agora',
                        style: AppTypography.labelLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800)),
                    Text(
                      '$total lote${total == 1 ? '' : 's'} classificado${total == 1 ? '' : 's'}',
                      style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _RiskMiniCount(
                  label: 'Crítico',
                  count: red,
                  color: AppColors.danger600,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _RiskMiniCount(
                  label: 'Atenção',
                  count: yellow,
                  color: AppColors.warning600,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _RiskMiniCount(
                  label: 'Seguro',
                  count: green,
                  color: AppColors.success600,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    if (green > 0)
                      Expanded(
                        flex: green,
                        child: Container(color: AppColors.success600),
                      ),
                    if (yellow > 0)
                      Expanded(
                        flex: yellow,
                        child: Container(color: AppColors.warning600),
                      ),
                    if (red > 0)
                      Expanded(
                        flex: red,
                        child: Container(color: AppColors.danger600),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskMiniCount extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isDark;

  const _RiskMiniCount({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

