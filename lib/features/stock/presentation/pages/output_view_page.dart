import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';

// ─── Helpers de localização ───────────────────────────────────────────────────

Map<String, String?> _parseLocation(String? raw) {
  if (raw == null || raw.trim().isEmpty) return {};
  final parts = raw.split('•').map((p) => p.trim()).where((p) => p.isNotEmpty);
  String? name, section, shelf, level, room;
  for (final p in parts) {
    if (p.startsWith('Secao ')) {
      section = p.substring(6).trim();
    } else if (p.startsWith('Prateleira ')) {
      shelf = p.substring(11).trim();
    } else if (p.startsWith('Nivel ')) {
      level = p.substring(6).trim();
    } else if (p.startsWith('Sala ')) {
      room = p.substring(5).trim();
    } else {
      name ??= p;
    }
  }
  return {'name': name, 'section': section, 'shelf': shelf, 'level': level, 'room': room};
}

Color _sectionColor(String? section) {
  if (section == null || section.isEmpty) return const Color(0xFF64748B);
  const palette = [
    Color(0xFF2563EB), Color(0xFF059669), Color(0xFFD97706),
    Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFF0891B2), Color(0xFFDC2626),
  ];
  return palette[section.codeUnitAt(0) % palette.length];
}

const _reasonLabels = <String, String>{
  'uso': 'Uso / Distribuição',
  'receita': 'Receita',
  'validade': 'Vencimento',
  'avaria': 'Avaria / Perda',
  'doacao': 'Doação',
  'outro': 'Outro',
};

// ─── Tema helpers ─────────────────────────────────────────────────────────────

extension _Ctx on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get pageBg => isDark ? const Color(0xFF09111F) : const Color(0xFFF0F4FA);
  Color get cardBg => isDark ? const Color(0xFF111C2D) : Colors.white;
  Color get onCard => isDark ? const Color(0xFFF1F5FB) : const Color(0xFF0F172A);
  Color get sub => isDark ? const Color(0xFF8FA3BF) : const Color(0xFF64748B);
  Color get border => isDark ? const Color(0xFF1E2D42) : const Color(0xFFE2E8F0);
}

const _kNavy = LinearGradient(
  colors: [Color(0xFF0A1929), Color(0xFF0D2545), Color(0xFF123270)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);


// ─── Steps de progresso ───────────────────────────────────────────────────────

const _kProgressSteps = [
  (Icons.search_rounded,        'Verificando estoque disponível'),
  (Icons.swap_vert_rounded,     'Aplicando critério FEFO'),
  (Icons.layers_outlined,       'Selecionando lotes por vencimento'),
  (Icons.edit_note_rounded,     'Registrando movimentações'),
  (Icons.cloud_done_outlined,   'Salvando no histórico'),
];

// ─── Página principal ─────────────────────────────────────────────────────────

class OutputViewPage extends StatefulWidget {
  /// Usado ao abrir o relatório de uma saída já concluída (histórico).
  final Map<String, dynamic>? output;

  /// Usado logo após confirmar uma nova saída: a página navega imediatamente
  /// e mostra a tela de progresso enquanto o Future resolve.
  final Future<Map<String, dynamic>>? pending;

  const OutputViewPage({super.key, this.output, this.pending})
      : assert(output != null || pending != null,
            'Forneça output ou pending.');

  @override
  State<OutputViewPage> createState() => _OutputViewPageState();
}

class _OutputViewPageState extends State<OutputViewPage>
    with TickerProviderStateMixin {
  // Resultado da operação
  Map<String, dynamic>? _result;
  Object? _error;

  // Animações do relatório (após concluir)
  late final AnimationController _ctrl;

  // Tutorial
  final _keyStats  = GlobalKey();
  final _keyFefo   = GlobalKey();
  final _keyItems  = GlobalKey();

  List<Map<String, dynamic>> get _movements =>
      (_result?['movements'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
      [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    if (widget.output != null) {
      // Relatório direto (histórico) — pula loading
      _result = widget.output;
      _ctrl.forward();
    } else {
      // Saída nova: resolve o future e atualiza estado
      widget.pending!.then((result) {
        if (!mounted) return;
        setState(() => _result = result);
        _ctrl.forward();
      }).catchError((e) {
        if (mounted) setState(() => _error = e);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _anim(double start, double end,
          {Curve curve = Curves.easeOutCubic}) =>
      CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start.clamp(0, 1), end.clamp(0, 1), curve: curve));

  void _showTutorial() {
    showCasaTutorial(
      context: context,
      steps: [
        TutorialStep(
          key: _keyStats,
          title: 'Resumo Visual da Saída',
          description: 'Os 3 cards no topo mostram os números desta saída: total de produtos diferentes, total de lotes consumidos e total de unidades distribuídas. Use estes números para conferência ao final da retirada física.',
          icon: Icons.summarize_rounded,
          align: ContentAlign.bottom,
          hints: const [
            '🏷️ Produtos: itens distintos no carrinho',
            '📦 Lotes: quantos lotes diferentes foram tocados',
            '🔢 Unidades: soma de todas as quantidades',
            'Useses números para conferir após retirada física',
          ],
        ),
        TutorialStep(
          key: _keyFefo,
          title: 'Critério FEFO Automático',
          description: 'O sistema aplica automaticamente o critério FEFO (First Expired, First Out — primeiro a vencer, primeiro a sair). Quando você seleciona um produto, ele consome dos lotes mais próximos do vencimento primeiro, reduzindo desperdício.',
          icon: Icons.swap_vert_rounded,
          align: ContentAlign.bottom,
          hints: const [
            '📅 FEFO = "First Expired, First Out"',
            '♻️ Reduz desperdício automaticamente',
            '🧠 Você não precisa pensar — o sistema escolhe',
            'A ordem dos cards abaixo já segue o FEFO',
          ],
        ),
        TutorialStep(
          key: _keyItems,
          title: 'Lista de Retirada Numerada',
          description: 'Cada card é UM lote a ser retirado, em ordem numerada (1, 2, 3...). Mostra: número da etapa, produto, validade do lote, localização física (prateleira + nível) e quantidade exata a retirar. Siga a ordem para retirada eficiente.',
          icon: Icons.inventory_2_outlined,
          align: ContentAlign.top,
          hints: const [
            '🔢 Retire NA ORDEM dos números (otimiza caminho)',
            '📍 A localização aponta exatamente onde está',
            '📊 Barra de progresso = % consumido daquele lote',
            '✓ Confira a validade antes de retirar',
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    // ── Estado de erro ──
    if (_error != null) {
      return _ErrorView(
        error: _error!,
        isDark: isDark,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    // ── Tela de progresso (aguardando future) ──
    if (_result == null) {
      return _LoadingView(isDark: isDark);
    }

    // ── Relatório completo ──
    return _buildReport(context, isDark);
  }

  Widget _buildReport(BuildContext context, bool isDark) {
    final movements = _movements;
    final createdAtRaw = _result!['createdAt'] as String?;
    final createdAt = createdAtRaw != null ? DateTime.tryParse(createdAtRaw) : null;
    final totalConsumed =
        movements.fold<int>(0, (s, m) => s + ((m['consumed'] as num?)?.toInt() ?? 0));
    final distinctProducts = <String>{};
    for (final m in movements) {
      if (m['productId'] != null) distinctProducts.add(m['productId'] as String);
    }
    final reasonCode = _result!['reasonCode'] as String? ?? 'outro';

    // Tipo do movimento → define a identidade do relatório (entrada/saída/descarte)
    final movementType = _result!['movementType'] as String?;
    final isInbound = (_result!['isInbound'] as bool?) ??
        (movementType == 'entrada' || movementType == 'ajustePositivo');
    final isDiscard = movementType == 'descarte' ||
        reasonCode == 'validade' ||
        reasonCode == 'avaria';

    final ({String title, String reasonLabel, IconData icon, Color color})
        kind = isInbound
            ? (
                title: 'Entrada registrada',
                reasonLabel: 'Cadastro de lote',
                icon: Icons.add_box_rounded,
                color: const Color(0xFF16A34A),
              )
            : isDiscard
                ? (
                    title: 'Descarte registrado',
                    reasonLabel: _reasonLabels[reasonCode] ?? 'Descarte',
                    icon: Icons.delete_sweep_rounded,
                    color: const Color(0xFFD97706),
                  )
                : (
                    title: 'Saída registrada',
                    reasonLabel: _reasonLabels[reasonCode] ??
                        (_result!['reason'] as String? ?? 'Distribuição'),
                    icon: Icons.outbound_rounded,
                    color: const Color(0xFF2563EB),
                  );
    final reasonLabel = kind.reasonLabel;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.pageBg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HeroHeader(
                outputId: _result!['outputId'] as String? ?? '-',
                performedByName: _result!['performedByName'] as String? ?? '-',
                reasonLabel: reasonLabel,
                titleText: kind.title,
                headerIcon: kind.icon,
                accentColor: kind.color,
                createdAt: createdAt,
                checkAnim: _anim(0.0, 0.30, curve: Curves.elasticOut),
                fadeAnim: _anim(0.08, 0.40),
                onHelp: _showTutorial,
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _anim(0.22, 0.52),
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
                      .animate(_anim(0.22, 0.52)),
                  child: _StatsRow(
                    key: _keyStats,
                    products: distinctProducts.length,
                    batches: movements.length,
                    units: totalConsumed,
                    unitsLabel: isInbound ? 'Entraram' : 'Unidades',
                    accentColor: kind.color,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
            if (!isInbound)
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _anim(0.32, 0.58),
                  child: _FefoNotice(key: _keyFefo, isDark: isDark),
                ),
              ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _anim(0.40, 0.64),
                child: Padding(
                  key: _keyItems,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 18,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1648A0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${movements.length} item${movements.length != 1 ? 'ns' : ''} '
                        '${isInbound ? 'nesta entrada' : isDiscard ? 'neste descarte' : 'nesta saída'}',
                        style: AppTypography.labelLarge.copyWith(
                          color: context.onCard,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final m = movements[i];
                  final total = movements.length;
                  final startFrac = 0.44 + i * (0.46 / max(total, 1));
                  final endFrac = (startFrac + 0.34).clamp(0.0, 1.0);
                  final itemAnim = _anim(startFrac, endFrac);
                  return FadeTransition(
                    opacity: itemAnim,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
                          .animate(itemAnim),
                      child: _ItemCard(
                        movement: m,
                        index: i + 1,
                        isDark: isDark,
                        isInbound: isInbound,
                        accentColor: kind.color,
                        cardBg: ctx.cardBg,
                        onCard: ctx.onCard,
                        sub: ctx.sub,
                        borderCol: ctx.border,
                      ),
                    ),
                  );
                },
                childCount: movements.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
        bottomNavigationBar: _BottomBar(isDark: isDark),
      ),
    );
  }
}

// ─── Tela de progresso ────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  final bool isDark;
  const _LoadingView({required this.isDark});

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _visibleSteps = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _ctrl.forward();
    // Avança um step a cada 700ms
    _timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_visibleSteps < _kProgressSteps.length) {
        setState(() => _visibleSteps++);
      } else {
        t.cancel();
      }
    });
    // Mostra primeiro step imediatamente
    Future.microtask(() { if (mounted) setState(() => _visibleSteps = 1); });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF111C2D) : Colors.white;
    final sub = isDark ? const Color(0xFF8FA3BF) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF1E2D42) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09111F) : const Color(0xFFF0F4FA),
      body: Column(
        children: [
          ModernProfileAppBar(
            title: 'Registrando saída…',
            subtitle: 'Processando movimentação',
            pageIcon: Icons.hourglass_top_rounded,
            iconColor: const Color(0xFF38BDF8),
            showBackButton: true,
          ),
          // ── Gradiente superior com spinner ──
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: _kNavy),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
            child: Column(
              children: [
                // Spinner animado
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.25)),
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
                        ),
                      ),
                      const Icon(Icons.output_rounded, color: Colors.white, size: 24),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Processando sua saída',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Aguarde enquanto o sistema registra\nao estoque com critério FEFO.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Steps ──
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF09111F) : const Color(0xFFF0F4FA),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      children: List.generate(_kProgressSteps.length, (i) {
                        final isVisible = i < _visibleSteps;
                        final isLast = i == _kProgressSteps.length - 1;
                        final isDone = isVisible;
                        final (icon, label) = _kProgressSteps[i];

                        return AnimatedOpacity(
                          opacity: isVisible ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          child: AnimatedSlide(
                            offset: isVisible ? Offset.zero : const Offset(0, 0.3),
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      // Ícone de status
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isDone
                                              ? const Color(0xFF16A34A).withValues(alpha: isDark ? 0.20 : 0.10)
                                              : sub.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDone
                                                ? const Color(0xFF16A34A).withValues(alpha: 0.35)
                                                : sub.withValues(alpha: 0.15),
                                          ),
                                        ),
                                        child: Icon(
                                          isDone ? Icons.check_rounded : icon,
                                          color: isDone ? const Color(0xFF16A34A) : sub,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              label,
                                              style: TextStyle(
                                                color: isDone
                                                    ? (isDark ? const Color(0xFFF1F5FB) : const Color(0xFF0F172A))
                                                    : sub,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (isDone)
                                              Text(
                                                'Concluído',
                                                style: TextStyle(
                                                  color: const Color(0xFF16A34A).withValues(alpha: 0.80),
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Spinner no step atual (último visível)
                                      if (isVisible && i == _visibleSteps - 1 &&
                                          _visibleSteps < _kProgressSteps.length)
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                                const Color(0xFF2563EB).withValues(alpha: 0.70)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!isLast)
                                  Divider(height: 1, indent: 16, endIndent: 16, color: borderCol),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dica informativa
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.10 : 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline_rounded,
                              color: Color(0xFF2563EB), size: 14),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'O sistema seleciona automaticamente os lotes com vencimento mais próximo (FEFO) para reduzir desperdício.',
                            style: TextStyle(
                              color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.85 : 0.80),
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tela de erro ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final Object error;
  final bool isDark;
  final VoidCallback onBack;
  const _ErrorView({required this.error, required this.isDark, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09111F) : const Color(0xFFF0F4FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.15 : 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFDC2626), size: 48),
              ),
              const SizedBox(height: 20),
              Text('Erro ao registrar saída',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  )),
              const SizedBox(height: 10),
              Text(
                error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF8FA3BF) : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Voltar e tentar novamente',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
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

// ─── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool isDark;
  const _BottomBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(top: BorderSide(color: context.border)),
        boxShadow: isDark
            ? []
            : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('Concluir e fechar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero header ─────────────────────────────────────────────────────────────

class _HeroHeader extends ConsumerWidget {
  final String outputId;
  final String performedByName;
  final String reasonLabel;
  final String titleText;
  final IconData headerIcon;
  final Color accentColor;
  final DateTime? createdAt;
  final Animation<double> checkAnim;
  final Animation<double> fadeAnim;
  final VoidCallback onHelp;

  const _HeroHeader({
    required this.outputId,
    required this.performedByName,
    required this.reasonLabel,
    required this.titleText,
    required this.headerIcon,
    required this.accentColor,
    required this.createdAt,
    required this.checkAnim,
    required this.fadeAnim,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd/MM/yyyy  •  HH:mm');
    final shortId = outputId.length > 16 ? '${outputId.substring(0, 16)}…' : outputId;
    final alertCount = ref.watch(allAvailableBatchesProvider).when(
          data: (list) => list
              .where((b) =>
                  !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30))
              .length,
          loading: () => 0,
          error: (_, __) => 0,
        );

    return Container(
      decoration: const BoxDecoration(gradient: _kNavy),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barra superior com ações ──
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  buildHelpButton(context: context, onPressed: onHelp),
                  CasaAlertsBellButton(
                    alertCount: alertCount,
                    onDarkBg: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: CasaThemeToggleButton(),
                  ),
                ],
              ),
            ),
          ),
          // ── Hero content ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: FadeTransition(
              opacity: fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // ── Título com ícone ao lado ──
            ScaleTransition(
              scale: checkAnim,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Ícone do tipo (entrada/saída/descarte)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.50),
                          width: 1.5),
                    ),
                    child: Icon(headerIcon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  // Texto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: -0.4,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: Text(
                            reasonLabel,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Info card ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  _HRow(icon: Icons.tag_rounded, label: 'ID', value: shortId, mono: true),
                  const SizedBox(height: 8),
                  _HRow(icon: Icons.person_outline_rounded, label: 'Responsável', value: performedByName),
                  if (createdAt != null) ...[
                    const SizedBox(height: 8),
                    _HRow(icon: Icons.schedule_rounded, label: 'Data / hora', value: fmt.format(createdAt!)),
                  ],
                ],
              ),
            ),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  const _HRow(
      {required this.icon, required this.label, required this.value, this.mono = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 13, color: Colors.white54),
          const SizedBox(width: 7),
          Text('$label:', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: mono ? 'monospace' : null),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

// ─── Stats row ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int products;
  final int batches;
  final int units;
  final String unitsLabel;
  final Color accentColor;
  final bool isDark;

  const _StatsRow(
      {super.key,
      required this.products,
      required this.batches,
      required this.units,
      this.unitsLabel = 'Unidades',
      this.accentColor = const Color(0xFF16A34A),
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, -16, 20, 16),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
        boxShadow: isDark
            ? []
            : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(child: _Stat(icon: Icons.inventory_2_outlined, label: 'Produtos', value: '$products', color: const Color(0xFF2563EB))),
          _SDivider(isDark: isDark),
          Expanded(child: _Stat(icon: Icons.layers_outlined, label: 'Lotes', value: '$batches', color: const Color(0xFF7C3AED))),
          _SDivider(isDark: isDark),
          Expanded(child: _Stat(icon: Icons.numbers_rounded, label: unitsLabel, value: '$units', color: accentColor)),
        ],
      ),
    );
  }
}

class _SDivider extends StatelessWidget {
  final bool isDark;
  const _SDivider({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 36,
        color: isDark ? const Color(0xFF1E2D42) : const Color(0xFFE2E8F0),
      );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Stat(
      {required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration:
                BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 18, height: 1)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.labelSmall.copyWith(color: context.sub, fontSize: 10)),
        ],
      );
}

// ─── FEFO notice ─────────────────────────────────────────────────────────────

class _FefoNotice extends StatelessWidget {
  final bool isDark;
  const _FefoNotice({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFB45309);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: amber.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.swap_vert_rounded, color: amber, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Critério FEFO aplicado',
                    style: TextStyle(
                        color: amber, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  'Lotes selecionados por ordem de vencimento — retire na sequência indicada.',
                  style: TextStyle(
                      color: amber.withValues(alpha: 0.85), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Item card ───────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> movement;
  final int index;
  final bool isDark;
  final bool isInbound;
  final Color accentColor;
  final Color cardBg;
  final Color onCard;
  final Color sub;
  final Color borderCol;

  const _ItemCard({
    required this.movement,
    required this.index,
    required this.isDark,
    this.isInbound = false,
    this.accentColor = const Color(0xFF2563EB),
    required this.cardBg,
    required this.onCard,
    required this.sub,
    required this.borderCol,
  });

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final productName = m['productName'] as String? ?? '-';
    final batchId     = m['batchId']     as String? ?? '-';
    final consumed    = (m['consumed']   as num?)?.toInt() ?? 0;
    final imageUrl    = m['imageUrl']    as String?;
    final unit        = m['unit']        as String? ?? 'un';

    final expiryStr = m['expiryDate'] as String?;
    final expiryDt  = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
    final daysLeft  = expiryDt?.difference(DateTime.now()).inDays;

    final locationRaw = m['shelfLocation'] as String?;
    final loc    = _parseLocation(locationRaw);
    final hasLoc = loc.isNotEmpty && loc.values.any((v) => v != null);

    final expiryColor = daysLeft == null
        ? sub
        : daysLeft <= 0
            ? const Color(0xFFDC2626)
            : daysLeft <= 7
                ? const Color(0xFFDC2626)
                : daysLeft <= 30
                    ? const Color(0xFFD97706)
                    : const Color(0xFF16A34A);

    final expiryLabel = daysLeft == null
        ? 'Sem validade'
        : daysLeft <= 0
            ? 'Vencido'
            : daysLeft == 1
                ? '1 dia'
                : '$daysLeft dias';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: isDark
            ? []
            : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(
            index: index,
            productName: productName,
            consumed: consumed,
            unit: unit,
            imageUrl: imageUrl,
            isInbound: isInbound,
            accentColor: accentColor,
            isDark: isDark,
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.qr_code_2_rounded,
                    label: 'Lote',
                    value: batchId,
                    isDark: isDark,
                    mono: true,
                    valueColor: onCard,
                    borderCol: borderCol,
                    sub: sub,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.event_rounded,
                    label: 'Validade',
                    value: expiryDt != null
                        ? DateFormat('dd/MM/yyyy').format(expiryDt)
                        : 'Sem validade',
                    isDark: isDark,
                    valueColor: expiryColor,
                    borderCol: expiryColor.withValues(alpha: 0.25),
                    sub: sub,
                    bg: expiryColor.withValues(alpha: isDark ? 0.11 : 0.06),
                    badge: expiryDt != null ? expiryLabel : null,
                    badgeColor: expiryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (hasLoc) ...[
            _LocationSection(loc: loc, isDark: isDark, sub: sub, onCard: onCard),
            const SizedBox(height: 14),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sub.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off_rounded, size: 14, color: sub),
                    const SizedBox(width: 8),
                    Text('Localização não informada',
                        style: TextStyle(color: sub, fontSize: 12)),
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

class _CardHeader extends StatelessWidget {
  final int index;
  final String productName;
  final int consumed;
  final String unit;
  final String? imageUrl;
  final bool isInbound;
  final Color accentColor;
  final bool isDark;
  const _CardHeader({
    required this.index,
    required this.productName,
    required this.consumed,
    required this.unit,
    required this.imageUrl,
    required this.isInbound,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF142140), const Color(0xFF111C2D)]
              : [const Color(0xFFEFF6FF), const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
      ),
      child: Row(
        children: [
          // Badge numerado (etapa)
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, Color.lerp(accentColor, Colors.black, 0.2)!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text('$index',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          // Imagem do produto (ou ícone fallback)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.inventory_2_rounded,
                        color: accentColor,
                        size: 22),
                  )
                : Icon(Icons.inventory_2_rounded,
                    color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              productName,
              style: AppTypography.productName(
                size: 14,
                weight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFFF1F5FB)
                    : const Color(0xFF0F172A),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.20 : 0.10),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: accentColor.withValues(alpha: 0.30)),
            ),
            child: Text(
              '${isInbound ? '+' : '−'}$consumed $unit',
              style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final bool mono;
  final Color valueColor;
  final Color borderCol;
  final Color sub;
  final Color? bg;
  final String? badge;
  final Color? badgeColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.mono = false,
    required this.valueColor,
    required this.borderCol,
    required this.sub,
    this.bg,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = bg ?? (isDark ? const Color(0xFF1A2A3F) : const Color(0xFFF8FAFC));
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: sub),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: sub, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (badge != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? sub).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge!,
                  style: TextStyle(
                      color: badgeColor ?? sub,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  final Map<String, String?> loc;
  final bool isDark;
  final Color sub;
  final Color onCard;

  const _LocationSection(
      {required this.loc,
      required this.isDark,
      required this.sub,
      required this.onCard});

  @override
  Widget build(BuildContext context) {
    final section     = loc['section'];
    final shelf       = loc['shelf'];
    final level       = loc['level'];
    final room        = loc['room'];
    final name        = loc['name'];
    final sectionColor = _sectionColor(section);
    final levelNum     = level != null ? int.tryParse(level) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sectionColor.withValues(alpha: 0.25)),
          color: sectionColor.withValues(alpha: isDark ? 0.07 : 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: isDark ? 0.20 : 0.11),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: sectionColor.withValues(alpha: isDark ? 0.35 : 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.place_rounded, color: sectionColor, size: 13),
                  ),
                  const SizedBox(width: 8),
                  Text('LOCALIZAÇÃO',
                      style: TextStyle(
                          color: sectionColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sectionColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Retire aqui',
                        style: TextStyle(
                            color: sectionColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (name != null) ...[
                          Text(name,
                              style: TextStyle(
                                  color: onCard,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          const SizedBox(height: 8),
                        ],
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (section != null)
                              _LocChip(label: section, prefix: 'Seção', color: sectionColor, icon: Icons.grid_view_rounded),
                            if (shelf != null)
                              _LocChip(label: shelf, prefix: 'Prateleira', color: const Color(0xFF0891B2), icon: Icons.view_week_outlined),
                            if (level != null)
                              _LocChip(label: level, prefix: 'Nível', color: const Color(0xFF7C3AED), icon: Icons.layers_rounded),
                            if (room != null)
                              _LocChip(label: room, prefix: 'Sala', color: const Color(0xFF059669), icon: Icons.meeting_room_outlined),
                          ],
                        ),
                        if (shelf != null || level != null) ...[
                          const SizedBox(height: 10),
                          _AddressPath(
                              section: section, shelf: shelf, level: level, sectionColor: sectionColor),
                        ],
                      ],
                    ),
                  ),
                  if (levelNum != null && levelNum >= 1 && levelNum <= 6) ...[
                    const SizedBox(width: 12),
                    _LevelDiagram(
                        targetLevel: levelNum,
                        totalLevels: 4,
                        color: const Color(0xFF7C3AED),
                        isDark: isDark),
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

class _LocChip extends StatelessWidget {
  final String label;
  final String prefix;
  final Color color;
  final IconData icon;
  const _LocChip({required this.label, required this.prefix, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text('$prefix $label',
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
          ],
        ),
      );
}

class _AddressPath extends StatelessWidget {
  final String? section;
  final String? shelf;
  final String? level;
  final Color sectionColor;
  const _AddressPath(
      {required this.section, required this.shelf, required this.level, required this.sectionColor});

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    if (section != null) parts.add(_PathStep(color: sectionColor, icon: Icons.grid_view_rounded, label: section!));
    if (shelf != null) {
      if (parts.isNotEmpty) parts.add(_arrow());
      parts.add(_PathStep(color: const Color(0xFF0891B2), icon: Icons.view_week_outlined, label: 'P$shelf'));
    }
    if (level != null) {
      if (parts.isNotEmpty) parts.add(_arrow());
      parts.add(_PathStep(color: const Color(0xFF7C3AED), icon: Icons.layers_rounded, label: 'N$level', highlight: true));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }

  Widget _arrow() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Icon(Icons.east_rounded, size: 11, color: Color(0xFF94A3B8)),
      );
}

class _PathStep extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool highlight;
  const _PathStep({required this.color, required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: highlight ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: highlight ? 1.0 : 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: highlight ? Colors.white : color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    color: highlight ? Colors.white : color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _LevelDiagram extends StatelessWidget {
  final int targetLevel;
  final int totalLevels;
  final Color color;
  final bool isDark;
  const _LevelDiagram(
      {required this.targetLevel, required this.totalLevels, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Nível',
              style: TextStyle(color: context.sub, fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (int lvl = totalLevels; lvl >= 1; lvl--)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: lvl == targetLevel
                    ? color
                    : color.withValues(alpha: isDark ? 0.08 : 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: lvl == targetLevel ? color : color.withValues(alpha: 0.20),
                    width: lvl == targetLevel ? 1.5 : 1),
                boxShadow: lvl == targetLevel
                    ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lvl == targetLevel)
                    const Padding(
                      padding: EdgeInsets.only(right: 3),
                      child: Icon(Icons.arrow_right_rounded, size: 12, color: Colors.white),
                    ),
                  Text('N$lvl',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: lvl == targetLevel ? Colors.white : color.withValues(alpha: 0.35))),
                ],
              ),
            ),
        ],
      );
}
