import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../domain/entities/stock_movement.dart';
import '../controllers/stock_provider.dart';
import 'output_view_page.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _search = '';
  String? _filterReason; // null = todos
  DateTimeRange? _filterDateRange;
  final _keyFilterRow = GlobalKey();
  final _keyHistoryList = GlobalKey();
  final _keyHistoryHeader = GlobalKey();

  static const _reasonColors = <String, List<Color>>{
    'entrada': [Color(0xFF059669), Color(0xFF047857)],
    'uso': [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    'receita': [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    'validade': [Color(0xFFD97706), Color(0xFFB45309)],
    'avaria': [Color(0xFFDC2626), Color(0xFFB91C1C)],
    'doacao': [Color(0xFF14B8A6), Color(0xFF0F766E)],
    'outro': [Color(0xFF6B7280), Color(0xFF4B5563)],
  };

  static const _reasonLabels = <String, String>{
    'entrada': 'Entrada',
    'uso': 'Distribuição',
    'receita': 'Receita',
    'validade': 'Vencimento',
    'avaria': 'Avaria',
    'doacao': 'Doação',
    'outro': 'Outro',
  };

  static const _reasonIcons = <String, IconData>{
    'entrada': Icons.add_box_rounded,
    'uso': Icons.outbound_rounded,
    'receita': Icons.menu_book_rounded,
    'validade': Icons.hourglass_disabled_rounded,
    'avaria': Icons.broken_image_outlined,
    'doacao': Icons.volunteer_activism_rounded,
    'outro': Icons.more_horiz_rounded,
  };

  int get _activeFilterCount =>
      (_filterReason != null ? 1 : 0) + (_filterDateRange != null ? 1 : 0);

  // Guard: evita empilhar várias rotas de relatório com toques repetidos.
  bool _openingReport = false;

  Future<void> _openOutputDetail(List<StockMovement> session) async {
    if (_openingReport) return;
    _openingReport = true;
    try {
      // Navega IMEDIATAMENTE com os dados que já temos (sem query bloqueante).
      // O relatório completo é reconstruído a partir dos movimentos da sessão,
      // que já contêm tudo necessário. Isso elimina a demora ao abrir.
      final output = _reconstructOutputFromMovements(session);
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => OutputViewPage(output: output)),
      );
    } finally {
      _openingReport = false;
    }
  }

  Map<String, dynamic> _reconstructOutputFromMovements(List<StockMovement> movements) {
    final first = movements.first;
    // Enriquece com dados dos lotes/produtos já em cache (imagem, localização,
    // validade, unidade) — sem nenhuma query extra ao Firestore.
    final allBatches =
        ref.read(allAvailableBatchesProvider).valueOrNull ?? const [];
    final products =
        ref.read(productsProvider).valueOrNull ?? const [];
    return {
      'outputId': first.id,
      'createdAt': first.performedAt.toIso8601String(),
      'performedByName': first.performedByName,
      'reason': first.reason,
      'reasonCode': first.reasonCode,
      // Tipo do movimento — usado para diferenciar Entrada / Saída / Descarte.
      'movementType': first.type.name,
      'isInbound': first.isInbound,
      'movements': movements.map((m) {
        final batch = allBatches
            .where((b) => b.id == m.batchId)
            .cast<dynamic>()
            .firstOrNull;
        final product = products
            .where((p) => p.id == m.productId)
            .cast<dynamic>()
            .firstOrNull;
        return {
          'productId': m.productId,
          'productName': m.productName,
          'batchId': m.batchId,
          'consumed': m.quantity,
          'before': (m.auditBefore?['quantity'] as num?)?.toInt() ?? 0,
          'after': (m.auditAfter?['quantity'] as num?)?.toInt() ?? 0,
          'shelfLocation': batch?.shelfLocation,
          'expiryDate': batch?.expiryDate?.toIso8601String(),
          'imageUrl': product?.imageUrl ?? batch?.imageUrl,
          'unit': product?.unit,
        };
      }).toList(),
    };
  }

  void _showFilterModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? tempReason = _filterReason;
    DateTimeRange? tempRange = _filterDateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bg = isDark ? const Color(0xFF111827) : Colors.white;
          final textPrimary =
              isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
          final textSub =
              isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
          final borderColor =
              isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
          final pillBg =
              isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);

          return Container(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 8,
                left: 20,
                right: 20),
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Filtrar Histórico',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    if (tempReason != null || tempRange != null)
                      TextButton(
                        onPressed: () => setModalState(() {
                          tempReason = null;
                          tempRange = null;
                        }),
                        child: const Text(
                          'Limpar',
                          style: TextStyle(
                            color: Color(0xFF7C3AED),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'MOTIVO',
                  style: TextStyle(
                    color: textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ModalChip(
                      label: 'Todos',
                      icon: Icons.select_all_rounded,
                      selected: tempReason == null,
                      activeColor: const Color(0xFF7C3AED),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () => setModalState(() => tempReason = null),
                    ),
                    ..._reasonLabels.entries.map((e) => _ModalChip(
                          label: e.value,
                          icon: _reasonIcons[e.key]!,
                          selected: tempReason == e.key,
                          activeColor: _reasonColors[e.key]![0],
                          isDark: isDark,
                          pillBg: pillBg,
                          borderColor: borderColor,
                          onTap: () =>
                              setModalState(() => tempReason = e.key),
                        )),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'PERÍODO',
                  style: TextStyle(
                    color: textSub,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DateRangeChip(
                      label: 'Hoje',
                      icon: Icons.today_rounded,
                      active: tempRange != null &&
                          _isSameDayRange(tempRange!,
                              DateTimeRange(start: _todayDate, end: _todayDate)),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () => setModalState(() {
                        final t = _todayDate;
                        tempRange = DateTimeRange(start: t, end: t);
                      }),
                    ),
                    _DateRangeChip(
                      label: '7 dias',
                      icon: Icons.date_range_rounded,
                      active: tempRange != null &&
                          _isSameDayRange(tempRange!, _last7Days),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () =>
                          setModalState(() => tempRange = _last7Days),
                    ),
                    _DateRangeChip(
                      label: '30 dias',
                      icon: Icons.calendar_month_rounded,
                      active: tempRange != null &&
                          _isSameDayRange(tempRange!, _last30Days),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () =>
                          setModalState(() => tempRange = _last30Days),
                    ),
                    _DateRangeChip(
                      label: 'Personalizado',
                      icon: Icons.edit_calendar_rounded,
                      active: tempRange != null &&
                          !_isSameDayRange(tempRange!, _last7Days) &&
                          !_isSameDayRange(tempRange!, _last30Days) &&
                          !_isSameDayRange(tempRange!,
                              DateTimeRange(start: _todayDate, end: _todayDate)),
                      isDark: isDark,
                      pillBg: pillBg,
                      borderColor: borderColor,
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: tempRange,
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.fromSeed(
                                seedColor: const Color(0xFF7C3AED),
                                brightness: isDark
                                    ? Brightness.dark
                                    : Brightness.light,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => tempRange = picked);
                        }
                      },
                    ),
                    if (tempRange != null)
                      _DateRangeChip(
                        label: 'Sem filtro',
                        icon: Icons.close_rounded,
                        active: false,
                        isDark: isDark,
                        pillBg: isDark
                            ? const Color(0xFF2D1515)
                            : const Color(0xFFFFEBEB),
                        borderColor: isDark
                            ? const Color(0xFF5C2020)
                            : const Color(0xFFFFCDD2),
                        onTap: () =>
                            setModalState(() => tempRange = null),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterReason = tempReason;
                        _filterDateRange = tempRange;
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Aplicar Filtros',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  DateTime get _todayDate {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTimeRange get _last7Days => DateTimeRange(
      start: _todayDate.subtract(const Duration(days: 6)), end: _todayDate);

  DateTimeRange get _last30Days => DateTimeRange(
      start: _todayDate.subtract(const Duration(days: 29)), end: _todayDate);

  bool _isSameDayRange(DateTimeRange a, DateTimeRange b) =>
      _sameDay(a.start, b.start) && _sameDay(a.end, b.end);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Hoje';
    if (d == today.subtract(const Duration(days: 1))) return 'Ontem';
    return DateFormat('EEEE, d \'de\' MMMM', 'pt_BR').format(dt);
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final movementsAsync = ref.watch(stockMovementsProvider);

    final bg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary =
        isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
    final textSub =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final borderColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Histórico',
        subtitle: 'Entradas, saídas e descartes',
        pageIcon: Icons.history_rounded,
        iconColor: const Color(0xFFA78BFA),
        extraContent: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(
              key: _keyHistoryHeader,
              child: _buildHeaderStats(movementsAsync),
            ),
            const SizedBox(height: 6),
            // ── Search + Filter no header (estilo dark, compacto) ──
            Row(
              key: _keyFilterRow,
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      cursorColor: Colors.white,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText: 'Buscar produto ou responsável…',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.8)),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white
                                        .withValues(alpha: 0.7)),
                                onPressed: () =>
                                    setState(() => _search = ''),
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF1D5FA8),
                          Color(0xFF38BDF8),
                        ]),
                        borderRadius:
                            BorderRadius.circular(AppRadius.input),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8)
                                .withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.tune_rounded,
                            color: Colors.white, size: 18),
                        onPressed: _showFilterModal,
                        tooltip: 'Filtros',
                      ),
                    ),
                    if (_activeFilterCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger600,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '$_activeFilterCount',
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
              ],
            ),
          ],
        ),
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyHistoryHeader,
                  title: 'Resumo do Histórico',
                  description: 'O header colorido mostra o resumo dos últimos 30 dias: total de movimentações registradas, soma de unidades distribuídas, descartes por vencimento e o item mais movimentado. Use estes números para ter visão geral de saídas.',
                  icon: Icons.dashboard_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Os números atualizam ao mudar filtros',
                    'Compare com mês anterior para detectar tendências',
                    'Use em reuniões para apresentar volume de operações',
                    'Total inclui TODAS as saídas (uso, doação, descarte)',
                  ],
                ),
                TutorialStep(
                  key: _keyFilterRow,
                  title: 'Filtros de Movimentação',
                  description: 'Use os filtros para refinar a lista: busca por nome de produto ou usuário, chips de tipo (distribuição, vencimento, avaria, doação) e seletor de período. Combine filtros para análises específicas.',
                  icon: Icons.filter_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🔍 Busca: nome do produto ou da colaboradora',
                    'Chips de motivo: vencimento, avaria, doação, uso',
                    'Período: hoje, semana, mês, customizado',
                    'Filtros combinam — use vários ao mesmo tempo',
                  ],
                ),
                TutorialStep(
                  key: _keyHistoryList,
                  title: 'Registro de Movimentações',
                  description: 'Lista cronológica (mais recente primeiro) de todas as saídas e descartes. Cada cartão mostra produto, quantidade, motivo colorido, colaboradora responsável e horário. Toque para ver detalhes completos da movimentação.',
                  icon: Icons.history_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    '🔵 Azul: distribuição (uso normal)',
                    '🟣 Roxo: receita executada (kit)',
                    '🟡 Amarelo: vencimento (descarte preventivo)',
                    '🔴 Vermelho: avaria (produto danificado)',
                    '🟢 Verde: doação registrada como saída',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: Column(
        children: [
            const SizedBox(height: 12),

            // ─── Lista ─────────────────────────────────────────────────────
            Expanded(
              child: movementsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5)),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 52, color: textSub),
                      const SizedBox(height: 12),
                      Text('Erro ao carregar histórico',
                          style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(e.toString(),
                          style:
                              TextStyle(color: textSub, fontSize: 12),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
                data: (allMovements) {
                  // Inclui entradas, saídas e descartes
                  var outputs = allMovements
                      .where((m) =>
                          m.type == MovementType.entrada ||
                          m.type == MovementType.saida ||
                          m.type == MovementType.descarte)
                      .toList();

                  // Filtro de motivo (entrada usa 'entrada' como pseudo-reasonCode)
                  if (_filterReason != null) {
                    outputs = outputs.where((m) {
                      if (_filterReason == 'entrada') {
                        return m.type == MovementType.entrada;
                      }
                      return m.reasonCode == _filterReason;
                    }).toList();
                  }

                  // Filtro de período
                  if (_filterDateRange != null) {
                    final start = _filterDateRange!.start;
                    final end = DateTime(_filterDateRange!.end.year,
                        _filterDateRange!.end.month, _filterDateRange!.end.day, 23, 59, 59);
                    outputs = outputs
                        .where((m) =>
                            m.performedAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
                            m.performedAt.isBefore(end.add(const Duration(seconds: 1))))
                        .toList();
                  }

                  // Filtro de texto
                  if (_search.isNotEmpty) {
                    final q = _search.toLowerCase();
                    outputs = outputs
                        .where((m) =>
                            m.productName
                                .toLowerCase()
                                .contains(q) ||
                            m.performedByName
                                .toLowerCase()
                                .contains(q))
                        .toList();
                  }

                  if (outputs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 60, color: textSub),
                          const SizedBox(height: 14),
                          Text('Nenhuma saída encontrada',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                              'Tente ajustar os filtros ou aguarde\nnovas movimentações',
                              style: TextStyle(
                                  color: textSub, fontSize: 13),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    );
                  }

                  // Agrupa por sessão (mesmo performedAt + performedBy)
                  final sessionMap =
                      <String, List<StockMovement>>{};
                  for (final m in outputs) {
                    final key =
                        '${m.performedAt.toIso8601String()}|${m.performedBy}';
                    sessionMap.putIfAbsent(key, () => []).add(m);
                  }
                  final sessions = sessionMap.values.toList()
                    ..sort((a, b) => b.first.performedAt
                        .compareTo(a.first.performedAt));

                  // Agrupa por dia
                  final dayMap =
                      <String, List<List<StockMovement>>>{};
                  for (final s in sessions) {
                    final day = _dayLabel(s.first.performedAt);
                    dayMap.putIfAbsent(day, () => []).add(s);
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      // Summary banner when filters active
                      if (_filterReason != null ||
                          _filterDateRange != null ||
                          _search.isNotEmpty)
                        _SummaryBanner(
                          movements: outputs,
                          textPrimary: textPrimary,
                          textSub: textSub,
                          cardBg: cardBg,
                          borderColor: borderColor,
                        ),
                      for (final entry in dayMap.entries) ...[
                        _DayDivider(
                            label: entry.key,
                            isDark: isDark,
                            textSub: textSub),
                        ...entry.value.map((s) {
                          final card = _SessionCard(
                            movements: s,
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            reasonColors: _reasonColors,
                            reasonLabels: _reasonLabels,
                            reasonIcons: _reasonIcons,
                            formatTime: _formatTime,
                            onDetailsTap: () => _openOutputDetail(s),
                          );
                          // Tutorial foca apenas o PRIMEIRO card da lista.
                          if (identical(s, sessions.first)) {
                            return KeyedSubtree(
                                key: _keyHistoryList, child: card);
                          }
                          return card;
                        }),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        )),
        ]),
    );
  }

  /// Constrói só os badges de stats — usado como extraContent do header
  Widget _buildHeaderStats(
      AsyncValue<List<StockMovement>> movementsAsync) {
    final today = DateTime.now();
    int totalToday = 0;
    int totalWeek = 0;
    int totalAll = 0;

    movementsAsync.whenData((all) {
      final outputs = all.where((m) =>
          m.type == MovementType.saida || m.type == MovementType.descarte);
      for (final m in outputs) {
        totalAll++;
        final d = m.performedAt;
        if (d.year == today.year &&
            d.month == today.month &&
            d.day == today.day) {
          totalToday++;
        }
        final weekAgo = today.subtract(const Duration(days: 7));
        if (d.isAfter(weekAgo)) totalWeek++;
      }
    });

    return Row(
      children: [
        _StatBadge(
          label: 'Hoje',
          value: '$totalToday',
          icon: Icons.today_rounded,
          accent: const Color(0xFF38BDF8),
        ),
        const SizedBox(width: 6),
        _StatBadge(
          label: '7 dias',
          value: '$totalWeek',
          icon: Icons.date_range_rounded,
          accent: const Color(0xFFA78BFA),
        ),
        const SizedBox(width: 6),
        _StatBadge(
          label: 'Total',
          value: '$totalAll',
          icon: Icons.all_inclusive_rounded,
          accent: const Color(0xFFFBBF24),
        ),
      ],
    );
  }
}

// ─── Stat badge no header ──────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = const Color(0xFF38BDF8),
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 5, 9, 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.28),
              accent.withValues(alpha: 0.10),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: accent.withValues(alpha: 0.45),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.20),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
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

// ─── Chips do modal de filtro ──────────────────────────────────────────────

class _ModalChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final bool isDark;
  final Color pillBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _ModalChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.isDark,
    required this.pillBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? activeColor : pillBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? activeColor : borderColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151)),
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool isDark;
  final Color pillBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _DateRangeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.isDark,
    required this.pillBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF4F46E5);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? activeColor : pillBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? activeColor : borderColor,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: active
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : (isDark
                        ? const Color(0xFFD1D5DB)
                        : const Color(0xFF374151)),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Separador de dia ──────────────────────────────────────────────────────

class _DayDivider extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color textSub;

  const _DayDivider(
      {required this.label,
      required this.isDark,
      required this.textSub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textSub,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card de sessão ────────────────────────────────────────────────────────

class _SessionCard extends StatefulWidget {
  final List<StockMovement> movements;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Map<String, List<Color>> reasonColors;
  final Map<String, String> reasonLabels;
  final Map<String, IconData> reasonIcons;
  final String Function(DateTime) formatTime;
  final VoidCallback? onDetailsTap;

  const _SessionCard({
    required this.movements,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.reasonColors,
    required this.reasonLabels,
    required this.reasonIcons,
    required this.formatTime,
    this.onDetailsTap,
  });

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = false;

  /// Retorna true quando a saída é considerada DESCARTE (baixa por vencimento
  /// ou avaria). Visualmente exibimos com identidade própria para diferenciar
  /// de saídas normais (uso/distribuição/doação).
  bool get _isDiscard {
    final r = widget.movements.first.reasonCode;
    return r == 'validade' || r == 'avaria';
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.movements.first;
    final isEntrada = first.type == MovementType.entrada;
    // Para entradas, usa o pseudo-key 'entrada' para cor/ícone/label
    final reasonKey = isEntrada ? 'entrada' : (first.reasonCode ?? 'outro');
    final colors = widget.reasonColors[reasonKey] ?? widget.reasonColors['outro']!;
    final reasonLabel = isEntrada
        ? 'Cadastro de lote'
        : (widget.reasonLabels[reasonKey] ?? 'Saída');
    final reasonIcon = isEntrada
        ? Icons.inbox_rounded
        : (widget.reasonIcons[reasonKey] ?? Icons.outbound_rounded);
    final totalQty = widget.movements.fold<int>(0, (s, m) => s + m.quantity);
    final timeStr = widget.formatTime(first.performedAt);
    final firstName = first.performedByName.split(' ').first;
    final isDark = widget.isDark;
    final onCard = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final divColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);
    final discard = _isDiscard;
    final typeLabel =
        isEntrada ? 'ENTRADA' : (discard ? 'DESCARTE' : 'SAÍDA');
    final typeIcon = isEntrada
        ? Icons.add_box_rounded
        : (discard ? Icons.delete_sweep_rounded : Icons.outbound_rounded);

    final preview = widget.movements.take(4).toList();
    final extra = widget.movements.length > 4 ? widget.movements.length - 4 : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: discard
              ? colors[0].withValues(alpha: isDark ? 0.45 : 0.30)
              : widget.borderColor,
          width: discard ? 1.2 : 1,
        ),
        boxShadow: isDark
            ? [
                if (discard)
                  BoxShadow(
                    color: colors[0].withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
              ]
            : [
                BoxShadow(
                  color: discard
                      ? colors[0].withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.05),
                  blurRadius: discard ? 14 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          // ── Barra colorida no topo ───────────────────────────────────
          Container(
            height: discard ? 6 : 5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
          ),

          // ── Conteúdo principal ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Linha 0: badge de tipo (DESCARTE/SAÍDA) + motivo + total
                Row(
                  children: [
                    // Badge de TIPO (gradiente forte)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(typeIcon, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            typeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Pill do motivo (com ícone)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              colors[0].withValues(alpha: isDark ? 0.18 : 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: colors[0].withValues(alpha: 0.30),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(reasonIcon, size: 11, color: colors[0]),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                reasonLabel,
                                style: TextStyle(
                                  color: colors[0],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Badge total
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: widget.borderColor),
                      ),
                      child: Text(
                        '$totalQty un',
                        style: TextStyle(
                          color: onCard,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Linha 1: hora + responsável
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 12, color: subColor),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: onCard,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: subColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.person_outline_rounded,
                        size: 12, color: subColor),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        firstName,
                        style: TextStyle(color: subColor, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Linha 2: pills dos primeiros 4 produtos
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...preview.map((m) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: widget.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2_rounded,
                                  size: 11, color: colors[0]),
                              const SizedBox(width: 5),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 110),
                                child: Text(
                                  m.productName,
                                  style: TextStyle(
                                    color: onCard,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: colors[0].withValues(
                                      alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '×${m.quantity}',
                                  style: TextStyle(
                                    color: colors[0],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (extra > 0)
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: colors[0].withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+$extra mais',
                            style: TextStyle(
                              color: colors[0],
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // Linha 3: expandir se tiver mais de 4
                if (widget.movements.length > 4) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down_rounded,
                              size: 16, color: subColor),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _expanded ? 'Ocultar todos' : 'Ver todos ${widget.movements.length} produtos',
                          style: TextStyle(
                            color: subColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Linha 4: botão ver relatório (moderno, full-width gradient)
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onDetailsTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors[0],
                            Color.lerp(colors[0], Colors.black, 0.18)!,
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colors[0].withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(Icons.receipt_long_rounded,
                                  size: 14, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Ver relatório completo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 15, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Lista expandida ──────────────────────────────────────────
          if (_expanded) ...[
            Divider(height: 1, thickness: 1, color: divColor),
            ...widget.movements.skip(4).map((m) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colors[0].withValues(
                                  alpha: isDark ? 0.15 : 0.08),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(Icons.inventory_2_rounded,
                                size: 15, color: colors[0]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              m.productName,
                              style: TextStyle(
                                color: onCard,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors[0].withValues(
                                  alpha: isDark ? 0.18 : 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '×${m.quantity}',
                              style: TextStyle(
                                color: colors[0],
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: divColor),
                  ],
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Summary banner ───────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final List<StockMovement> movements;
  final Color textPrimary;
  final Color textSub;
  final Color cardBg;
  final Color borderColor;

  const _SummaryBanner({
    required this.movements,
    required this.textPrimary,
    required this.textSub,
    required this.cardBg,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final totalMoves = movements.length;
    final totalEntrada = movements
        .where((m) => m.type == MovementType.entrada)
        .fold<int>(0, (sum, m) => sum + m.quantity);
    final totalSaida = movements
        .where((m) => m.type == MovementType.saida)
        .fold<int>(0, (sum, m) => sum + m.quantity);
    final totalDescarte =
        movements.where((m) => m.type == MovementType.descarte).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SummaryMini(
              label: 'Registros',
              value: '$totalMoves',
              icon: Icons.list_rounded,
              color: AppColors.brandPrimary600,
              textPrimary: textPrimary,
              textSub: textSub,
            ),
            _SummaryMini(
              label: 'Entradas',
              value: '$totalEntrada un.',
              icon: Icons.add_circle_outline_rounded,
              color: AppColors.success600,
              textPrimary: textPrimary,
              textSub: textSub,
            ),
            _SummaryMini(
              label: 'Saídas',
              value: '$totalSaida un.',
              icon: Icons.outbound_rounded,
              color: AppColors.secondaryBlue600,
              textPrimary: textPrimary,
              textSub: textSub,
            ),
            _SummaryMini(
              label: 'Descartes',
              value: '$totalDescarte',
              icon: Icons.delete_outline_rounded,
              color: AppColors.danger600,
              textPrimary: textPrimary,
              textSub: textSub,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color textPrimary;
  final Color textSub;

  const _SummaryMini({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.textPrimary,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(label,
                    style: TextStyle(color: textSub, fontSize: 10)),
              ],
            ),
          ],
        ),
      );
}
