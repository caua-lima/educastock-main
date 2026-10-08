import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../ml/data/repositories/rule_based_risk_classifier.dart';
import '../../../ml/domain/entities/risk_prediction.dart';
import '../../../ml/presentation/controllers/consumption_forecast_provider.dart';
import '../../../ml/presentation/widgets/risk_widgets.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../../recipes/domain/entities/stock_recipe.dart';
import '../../../recipes/presentation/controllers/recipes_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../domain/entities/stock_movement.dart';
import 'output_view_page.dart';

// Helper local: pior nível de risco entre os lotes disponíveis de um produto.
RiskLevel? _worstRisk(String productId, List<Batch> batches) {
  final classifier = RuleBasedRiskClassifier();
  var worst = RiskLevel.verde;
  var found = false;
  for (final b in batches) {
    if (b.productId != productId) continue;
    if (b.status != BatchStatus.disponivel) continue;
    found = true;
    final lvl = classifier.classifySync(b).level;
    if (lvl == RiskLevel.vermelho) return RiskLevel.vermelho;
    if (lvl == RiskLevel.amarelo && worst == RiskLevel.verde) {
      worst = RiskLevel.amarelo;
    }
  }
  return found ? worst : null;
}

enum _OutputMode { products, recipes }

/// Filtro de validade dos lotes disponíveis do produto.
enum _ExpiryFilter {
  todos,
  vencidos, // já vencidos
  criticos, // vence em ≤7 dias
  atencao, // vence em 8–30 dias
  seguros, // >30 dias ou sem validade
}

extension _ExpiryFilterX on _ExpiryFilter {
  String get label => switch (this) {
        _ExpiryFilter.todos => 'Todos',
        _ExpiryFilter.vencidos => 'Vencidos',
        _ExpiryFilter.criticos => 'Vence em 7 dias',
        _ExpiryFilter.atencao => 'Vence em 30 dias',
        _ExpiryFilter.seguros => 'Validade segura',
      };

  IconData get icon => switch (this) {
        _ExpiryFilter.todos => Icons.all_inclusive_rounded,
        _ExpiryFilter.vencidos => Icons.cancel_rounded,
        _ExpiryFilter.criticos => Icons.warning_amber_rounded,
        _ExpiryFilter.atencao => Icons.schedule_rounded,
        _ExpiryFilter.seguros => Icons.check_circle_rounded,
      };

  Color get color => switch (this) {
        _ExpiryFilter.todos => const Color(0xFF1D5FA8),
        _ExpiryFilter.vencidos => const Color(0xFFDC2626),
        _ExpiryFilter.criticos => const Color(0xFFEF4444),
        _ExpiryFilter.atencao => const Color(0xFFD97706),
        _ExpiryFilter.seguros => const Color(0xFF059669),
      };
}

// Mesmo mapeamento usado na página Estoque, para manter o estilo visual
// consistente entre as duas telas.
IconData _categoryIcon(ProductCategory cat) => switch (cat) {
      ProductCategory.alimento => Icons.restaurant_rounded,
      ProductCategory.bebida => Icons.local_drink_rounded,
      ProductCategory.limpeza => Icons.cleaning_services_rounded,
      ProductCategory.higienePessoal => Icons.soap_rounded,
      ProductCategory.escolar => Icons.auto_stories_rounded,
      ProductCategory.roupas => Icons.checkroom_rounded,
      ProductCategory.outro => Icons.category_rounded,
    };

final stockDatasourceProvider = Provider<StockRemoteDatasource>(
  (_) => StockRemoteDatasource(),
);

class MovementPage extends ConsumerStatefulWidget {
  final String batchId;
  final String? prefillProductId;
  final String? prefillReason; // 'uso' | 'validade' | 'avaria' | 'outro'

  const MovementPage({
    super.key,
    required this.batchId,
    this.prefillProductId,
    this.prefillReason,
  });

  @override
  ConsumerState<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends ConsumerState<MovementPage> {
  final _searchController = TextEditingController();

  _OutputMode _mode = _OutputMode.products;
  String _search = '';
  String? _categoryKey;
  _ExpiryFilter _expiryFilter = _ExpiryFilter.todos;
  String _reasonCode = MovementReasonCode.uso.name;
  String? _selectedRecipeId;
  final Map<String, int> _selectedQtyByProduct = {};
  bool _isLoading = false;
  final _keyConfirmFab = GlobalKey();
  final _keySearchBar = GlobalKey();
  final _keyModeTabs = GlobalKey();
  final _keyProductGrid = GlobalKey();
  final _keyRecipeGrid = GlobalKey();

  static const _reasonLabels = {
    'uso': 'Uso/Distribuição',
    'validade': 'Vencimento',
    'avaria': 'Avaria/Perda',
    'outro': 'Outro',
  };

  @override
  void initState() {
    super.initState();
    // Pré-seleciona o motivo (sync — fast path)
    if (widget.prefillReason != null && widget.prefillReason!.isNotEmpty) {
      final valid = MovementReasonCode.values
          .firstWhere((r) => r.name == widget.prefillReason,
              orElse: () => MovementReasonCode.uso);
      _reasonCode = valid.name;
    }

    // Pré-seleciona produto vindo de URL (ex.: alerta crítico).
    // Para flows normais (uso): 1 unidade.
    final pid = widget.prefillProductId;
    if (pid != null && pid.isNotEmpty) {
      _selectedQtyByProduct[pid] = 1;
    }

    // Se vier batchId (descarte/saída de lote específico): carrega o lote
    // e pré-seleciona a QUANTIDADE TOTAL do lote — útil para registrar
    // baixa de lote vencido em um único toque.
    if (widget.batchId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final batch =
              await ref.read(batchByIdProvider(widget.batchId).future);
          if (!mounted || batch == null) return;
          setState(() {
            // Sobrescreve a quantidade 1 da pré-seleção sync com o total
            _selectedQtyByProduct[batch.productId] = batch.quantity;
          });
        } catch (_) {
          // Se falhar (offline, lote inexistente), mantém o que estiver
          // pré-selecionado.
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _availableForProduct(String productId, List<Batch> batches) {
    return batches
        .where((b) => b.productId == productId && b.status == BatchStatus.disponivel)
        .fold<int>(0, (acc, b) => acc + b.quantity);
  }

  /// Verifica se o produto possui ao menos um lote disponível que satisfaz
  /// o filtro de validade selecionado.
  bool _matchesExpiryFilter(String productId, List<Batch> batches) {
    if (_expiryFilter == _ExpiryFilter.todos) return true;
    final now = DateTime.now();
    final available = batches.where(
        (b) => b.productId == productId && b.status == BatchStatus.disponivel);
    for (final b in available) {
      if (b.expiryDate == null || b.noExpiry) {
        if (_expiryFilter == _ExpiryFilter.seguros) return true;
        continue;
      }
      final d = b.expiryDate!.difference(now).inDays;
      final isExpired = b.expiryDate!.isBefore(now);
      switch (_expiryFilter) {
        case _ExpiryFilter.vencidos:
          if (isExpired) return true;
        case _ExpiryFilter.criticos:
          if (!isExpired && d <= 7) return true;
        case _ExpiryFilter.atencao:
          if (!isExpired && d > 7 && d <= 30) return true;
        case _ExpiryFilter.seguros:
          if (!isExpired && d > 30) return true;
        case _ExpiryFilter.todos:
          return true;
      }
    }
    return false;
  }

  Future<void> _openFilterModal({
    required List<String> categoryKeys,
    required Map<String, String> categoryLabelMap,
  }) async {
    String? draftCategory = _categoryKey;
    String draftReason = _reasonCode;
    _ExpiryFilter draftExpiry = _expiryFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Handle + header gradiente ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F2444), Color(0xFF1D5FA8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: const Icon(Icons.tune_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Filtros de Saída',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      )),
                                  Text('Refine os produtos exibidos',
                                      style: TextStyle(
                                        color: Color(0xFFBFD7F2),
                                        fontSize: 12,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Corpo scrollável ──
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Validade ──
                          _FilterSectionLabel(
                            icon: Icons.event_busy_rounded,
                            label: 'Validade',
                            color: const Color(0xFFD97706),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _ExpiryFilter.values.map((f) {
                              return _ModernFilterChip(
                                label: f.label,
                                icon: f.icon,
                                color: f.color,
                                selected: draftExpiry == f,
                                isDark: isDark,
                                onTap: () =>
                                    setSheetState(() => draftExpiry = f),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),

                          // ── Categoria ──
                          _FilterSectionLabel(
                            icon: Icons.category_rounded,
                            label: 'Categoria',
                            color: const Color(0xFF1D5FA8),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ModernFilterChip(
                                label: 'Todas',
                                icon: Icons.apps_rounded,
                                color: const Color(0xFF1D5FA8),
                                selected: draftCategory == null,
                                isDark: isDark,
                                onTap: () =>
                                    setSheetState(() => draftCategory = null),
                              ),
                              ...categoryKeys.map(
                                (key) => _ModernFilterChip(
                                  label: categoryLabelMap[key] ?? key,
                                  icon: Icons.label_rounded,
                                  color: const Color(0xFF1D5FA8),
                                  selected: draftCategory == key,
                                  isDark: isDark,
                                  onTap: () => setSheetState(
                                      () => draftCategory = key),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Motivo ──
                          _FilterSectionLabel(
                            icon: Icons.assignment_rounded,
                            label: 'Motivo da saída',
                            color: const Color(0xFF7C3AED),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _reasonLabels.entries.map((e) {
                              return _ModernFilterChip(
                                label: e.value,
                                icon: _reasonIcon(e.key),
                                color: const Color(0xFF7C3AED),
                                selected: draftReason == e.key,
                                isDark: isDark,
                                onTap: () =>
                                    setSheetState(() => draftReason = e.key),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // ── Botões fixos ──
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20,
                        MediaQuery.of(ctx).viewInsets.bottom +
                            MediaQuery.of(ctx).padding.bottom +
                            14),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _categoryKey = null;
                                _reasonCode = MovementReasonCode.uso.name;
                                _expiryFilter = _ExpiryFilter.todos;
                              });
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Limpar'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: CasaButton(
                            label: 'Aplicar filtros',
                            icon: Icons.check_rounded,
                            onPressed: () {
                              setState(() {
                                _categoryKey = draftCategory;
                                _reasonCode = draftReason;
                                _expiryFilter = draftExpiry;
                              });
                              Navigator.pop(ctx);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _reasonIcon(String key) => switch (key) {
        'uso' => Icons.outbound_rounded,
        'validade' => Icons.event_busy_rounded,
        'avaria' => Icons.report_problem_rounded,
        'outro' => Icons.more_horiz_rounded,
        _ => Icons.label_rounded,
      };

  Future<void> _openSummary(List<Product> products) async {
    if (_selectedQtyByProduct.isEmpty ||
        _selectedQtyByProduct.values.every((v) => v <= 0)) {
      showCasaSnackbar(context,
          message: 'Selecione ao menos um produto com quantidade.',
          isError: true);
      return;
    }
    final items = _selectedQtyByProduct.entries
        .where((e) => e.value > 0)
        .map((e) {
      final p = products.firstWhere((p) => p.id == e.key,
          orElse: () => Product(
                id: e.key,
                name: e.key,
                category: ProductCategory.outro,
                unit: 'un',
                isPerishable: false,
                createdAt: DateTime.now(),
                createdBy: '',
              ));
      return _SummaryItem(product: p, qty: e.value);
    }).toList();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SummarySheet(
        items: items,
        reasonLabel: _reasonLabels[_reasonCode] ?? 'Uso/Distribuição',
      ),
    );
    if (confirmed == true) {
      await _submitProducts(products);
    }
  }

  Future<void> _submitProducts(List<Product> products) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final requests = <ProductOutputRequest>[];
    for (final entry in _selectedQtyByProduct.entries) {
      if (entry.value <= 0) continue;
      final product = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => Product(
          id: entry.key,
          name: 'Produto',
          category: ProductCategory.outro,
          unit: 'un',
          isPerishable: true,
          createdAt: DateTime.now(),
          createdBy: user.id,
        ),
      );
      requests.add(
        ProductOutputRequest(
          productId: product.id,
          productName: product.name,
          quantity: entry.value,
        ),
      );
    }

    if (requests.isEmpty) {
      showCasaSnackbar(
        context,
        message: 'Selecione ao menos um produto com quantidade.',
        isError: true,
      );
      return;
    }

    setState(() => _selectedQtyByProduct.clear());

    final pendingFuture = ref.read(stockDatasourceProvider).registerBulkOutputFefo(
      items: requests,
      performedBy: user.id,
      performedByName: user.name,
      reasonCode: _reasonCode,
      reason: _reasonLabels[_reasonCode],
      activity: null,
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => OutputViewPage(pending: pendingFuture)),
    );
  }

  Future<void> _submitRecipe(StockRecipe recipe) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(recipesNotifierProvider.notifier).executeRecipe(recipe);
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Saída por receita registrada com sucesso!',
        isSuccess: true,
      );
      context.go('/dashboard');
    } catch (error) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final batchesAsync = ref.watch(allAvailableBatchesProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final categoryLabelMap = ref.watch(categoryLabelMapProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Distribuição',
        subtitle: 'Produtos avulsos ou por receita',
        pageIcon: Icons.outbound_rounded,
        iconColor: const Color(0xFFEF4444),
        showBackButton: true,
        extraContent: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Tabs de modo (dark style, compactas)
            Container(
              key: _keyModeTabs,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                children: [
                  _HeaderModeTab(
                    label: 'Avulso',
                    icon: Icons.inventory_2_rounded,
                    selected: _mode == _OutputMode.products,
                    onTap: () =>
                        setState(() => _mode = _OutputMode.products),
                  ),
                  _HeaderModeTab(
                    label: 'Receita',
                    icon: Icons.menu_book_rounded,
                    selected: _mode == _OutputMode.recipes,
                    onTap: () =>
                        setState(() => _mode = _OutputMode.recipes),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // ── Search + filter (dark style, compacto)
            Row(
              key: _keySearchBar,
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
                      controller: _searchController,
                      onChanged: (v) => setState(() => _search = v),
                      cursorColor: Colors.white,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        filled: false,
                        fillColor: Colors.transparent,
                        hintText: 'Buscar produto ou receita…',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.8)),
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
                Builder(builder: (ctx) {
                  final categories = productsAsync.valueOrNull
                          ?.map((e) => e.category.name)
                          .toSet()
                          .toList() ??
                      [];
                  categories.sort();
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF1D5FA8),
                        Color(0xFF38BDF8),
                      ]),
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF38BDF8).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _openFilterModal(
                        categoryKeys: categories,
                        categoryLabelMap: categoryLabelMap,
                      ),
                      icon: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 18),
                      tooltip: 'Filtros',
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () {
              final steps = <TutorialStep>[
                TutorialStep(
                  key: _keyModeTabs,
                  title: 'Modo de Distribuição',
                  description: 'Escolha entre dois modos: "Produto Avulso" (você seleciona itens individualmente) ou "Receita Ativa" (usa um modelo pronto que distribui múltiplos itens de uma vez). A aba selecionada fica destacada em azul.',
                  icon: Icons.swap_horiz_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '📦 Avulso: você escolhe item por item',
                    '📋 Receita: kit pronto (ex: Kit Lanche)',
                    '🚀 Receitas são mais rápidas para distribuições padrão',
                    'Pode alternar entre modos sem perder seleções',
                  ],
                ),
                TutorialStep(
                  key: _keySearchBar,
                  title: 'Buscar Itens',
                  description: 'Digite no campo de busca para encontrar produtos ou receitas pelo nome. A busca acontece em tempo real e mostra apenas itens com estoque disponível. Use também os chips de categoria para filtrar visualmente.',
                  icon: Icons.search_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '⌨️ Busca em tempo real, sem precisar enter',
                    '🏷️ Mostra apenas produtos COM estoque',
                    '🎨 Use chips de categoria para refinar',
                    '🔴/🟡 As cores indicam validade próxima',
                  ],
                ),
                if (_mode == _OutputMode.products)
                  TutorialStep(
                    key: _keyProductGrid,
                    title: 'Selecionar Produtos',
                    description: 'Cada card é um produto disponível. Mostra nome, marca, quantidade total em estoque e badge colorido de validade do lote mais próximo do vencimento. Use os botões + e - para ajustar quanto vai distribuir. O sistema aplica FEFO automaticamente.',
                    icon: Icons.inventory_2_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      '🔴 Vermelho: lote vencido — confira antes de distribuir',
                      '🟡 Amarelo: vence em 30 dias — prioridade alta',
                      '🟢 Verde: validade segura — distribuição normal',
                      '➕➖ Use +/- para ajustar quantidade',
                      '🔢 Badge no canto = quantidade selecionada',
                    ],
                  )
                else
                  TutorialStep(
                    key: _keyRecipeGrid,
                    title: 'Selecionar Receita',
                    description: 'Lista de receitas ativas (modelos prontos com múltiplos produtos). Toque em uma receita para selecionar — o sistema calcula automaticamente todas as quantidades necessárias e verifica se há estoque suficiente.',
                    icon: Icons.menu_book_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      '📋 Cada receita = vários produtos de uma vez',
                      '✅ Sistema verifica estoque antes de executar',
                      '👆 Toque uma vez para selecionar',
                      '🔙 Pode voltar para Avulso a qualquer momento',
                    ],
                  ),
                if (_mode == _OutputMode.products ||
                    (_mode == _OutputMode.recipes &&
                        _selectedRecipeId != null))
                  TutorialStep(
                    key: _keyConfirmFab,
                    title: 'Confirmar Distribuição',
                    description: 'Quando estiver com a seleção pronta, toque no botão azul para revisar e confirmar. Você verá uma tela de resumo com todos os itens, quantidades e lotes que serão baixados. A saída fica registrada com seu nome, hora e motivo.',
                    icon: Icons.send_rounded,
                    align: ContentAlign.top,
                    hints: const [
                      '👀 Tela de revisão antes de confirmar definitivo',
                      '📉 Estoque é deduzido AUTOMATICAMENTE',
                      '📜 Aparece no Histórico imediatamente',
                      '⚠️ Saída confirmada NÃO pode ser desfeita',
                    ],
                  ),
              ];
              showCasaTutorial(
                context: context,
                steps: steps,
              );
            },
          ),
        ],
      ),
      Expanded(child: SafeArea(
        top: false,
        child: batchesAsync.when(
          data: (batches) => productsAsync.when(
            data: (products) {
              final filteredProducts = products.where((p) {
                // Saída só lista produtos com estoque disponível
                final hasStock = _availableForProduct(p.id, batches) > 0;
                if (!hasStock) return false;
                final q = _search.trim().toLowerCase();
                final searchOk = q.isEmpty ||
                    p.name.toLowerCase().contains(q) ||
                    (p.brand?.toLowerCase().contains(q) ?? false);
                final categoryOk = _categoryKey == null || p.category.name == _categoryKey;
                final expiryOk = _matchesExpiryFilter(p.id, batches);
                return searchOk && categoryOk && expiryOk;
              }).toList();

              // Ordena por risco ML: vermelho → amarelo → verde → outros.
              // A IA orienta o usuário a tirar os críticos antes.
              const riskOrder = {
                RiskLevel.vermelho: 0,
                RiskLevel.amarelo: 1,
                RiskLevel.verde: 2,
              };
              filteredProducts.sort((a, b) {
                final ra = _worstRisk(a.id, batches);
                final rb = _worstRisk(b.id, batches);
                final oa = ra == null ? 3 : riskOrder[ra]!;
                final ob = rb == null ? 3 : riskOrder[rb]!;
                if (oa != ob) return oa.compareTo(ob);
                return a.name.compareTo(b.name);
              });

              final width = MediaQuery.of(context).size.width;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
                children: [
                  // Chips de filtros ativos
                  if (_categoryKey != null ||
                      _reasonCode != MovementReasonCode.uso.name ||
                      _expiryFilter != _ExpiryFilter.todos)
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (_expiryFilter != _ExpiryFilter.todos)
                          Chip(
                            avatar: Icon(_expiryFilter.icon,
                                size: 15, color: _expiryFilter.color),
                            label: Text(_expiryFilter.label),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(
                                () => _expiryFilter = _ExpiryFilter.todos),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(
                                color: _expiryFilter.color
                                    .withValues(alpha: 0.4)),
                          ),
                        if (_categoryKey != null)
                          Chip(
                            label: Text(
                                categoryLabelMap[_categoryKey] ??
                                    _categoryKey!),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () =>
                                setState(() => _categoryKey = null),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (_reasonCode != MovementReasonCode.uso.name)
                          Chip(
                            label: Text(
                                _reasonLabels[_reasonCode] ??
                                    'Uso/Distribuição'),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() =>
                                _reasonCode = MovementReasonCode.uso.name),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_mode == _OutputMode.products && filteredProducts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxl),
                      child: CasaEmptyState(
                        icon: _expiryFilter != _ExpiryFilter.todos
                            ? _expiryFilter.icon
                            : Icons.search_off_rounded,
                        title: 'Nenhum produto encontrado',
                        description: _expiryFilter != _ExpiryFilter.todos
                            ? 'Nenhum lote disponível em "${_expiryFilter.label}". Tente outro filtro.'
                            : 'Ajuste a busca ou os filtros para ver produtos.',
                        ctaLabel: 'Limpar filtros',
                        onCta: () => setState(() {
                          _categoryKey = null;
                          _reasonCode = MovementReasonCode.uso.name;
                          _expiryFilter = _ExpiryFilter.todos;
                          _search = '';
                          _searchController.clear();
                        }),
                      ),
                    )
                  else if (_mode == _OutputMode.products) ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredProducts.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (_, i) {
                          final p = filteredProducts[i];
                          final available = _availableForProduct(p.id, batches);
                          final qty = _selectedQtyByProduct[p.id] ?? 0;

                          final now = DateTime.now();
                          // Crítico: lote vence em até 7 dias (mas ainda não venceu)
                          final criticalBatch = batches.any((b) =>
                              b.productId == p.id &&
                              b.status == BatchStatus.disponivel &&
                              b.expiryDate != null &&
                              !b.expiryDate!.isBefore(now) &&
                              b.expiryDate!.difference(now).inDays <= 7);
                          // Atenção: lote vence entre 8 e 30 dias
                          final nearExpiry = batches.any((b) =>
                              b.productId == p.id &&
                              b.status == BatchStatus.disponivel &&
                              b.expiryDate != null &&
                              !b.expiryDate!.isBefore(now) &&
                              b.expiryDate!.difference(now).inDays > 7 &&
                              b.expiryDate!.difference(now).inDays <= 30);
                          // Vencido: lote no passado
                          final expiredBatch = batches.any((b) =>
                              b.productId == p.id &&
                              b.status == BatchStatus.disponivel &&
                              b.expiryDate != null &&
                              b.expiryDate!.isBefore(now));

                          final mlRisk = _worstRisk(p.id, batches);
                          // Paleta + badge de validade
                          List<Color> palette;
                          String? expLabel;
                          Color expColor = AppColors.brandPrimary600;
                          IconData expIcon = Icons.event_rounded;
                          if (expiredBatch) {
                            palette = CasaProductCard.paletteRed;
                            expLabel = 'VENCIDO';
                            expColor = const Color(0xFFFCA5A5);
                            expIcon = Icons.cancel_rounded;
                          } else if (criticalBatch) {
                            palette = CasaProductCard.paletteRed;
                            expLabel = 'VENCE BREVE';
                            expColor = const Color(0xFFFCA5A5);
                            expIcon = Icons.warning_amber_rounded;
                          } else if (nearExpiry) {
                            palette = CasaProductCard.paletteYellow;
                            expLabel = 'ATENÇÃO';
                            expColor = const Color(0xFFFDE68A);
                            expIcon = Icons.schedule_rounded;
                          } else {
                            palette = CasaProductCard.paletteGreen;
                          }
                          final card = CasaProductCard(
                            name: p.name,
                            imageUrl: p.imageUrl,
                            fallbackIcon: _categoryIcon(p.category),
                            palette: palette,
                            animationIndex: i,
                            // Tap no card: incrementa qty (se ainda houver disponível)
                            onTap: available > qty
                                ? () => setState(() =>
                                    _selectedQtyByProduct[p.id] = qty + 1)
                                : null,
                            headerBadgeLeft: mlRisk != null
                                ? Tooltip(
                                    message: 'Risco ML: ${mlRisk.label}',
                                    child: RiskBadge(
                                        level: mlRisk, compact: true),
                                  )
                                : null,
                            headerBadgeRight: expLabel != null
                                ? CasaProductBadge(
                                    icon: expIcon,
                                    label: expLabel,
                                    accent: expColor,
                                  )
                                : null,
                            footer: Text(
                              'Disp.: $available ${p.unit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.labelSmall.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            actionFooter: CasaProductStepper(
                              qty: qty,
                              max: available,
                              accent: palette[0],
                              onDecrement: qty > 0
                                  ? () => setState(() {
                                        final next = qty - 1;
                                        if (next <= 0) {
                                          _selectedQtyByProduct.remove(p.id);
                                        } else {
                                          _selectedQtyByProduct[p.id] = next;
                                        }
                                      })
                                  : null,
                              onIncrement: available > qty
                                  ? () => setState(() =>
                                      _selectedQtyByProduct[p.id] = qty + 1)
                                  : null,
                            ),
                          );
                          // Spotlight do tutorial só no PRIMEIRO card
                          if (i == 0) {
                            return KeyedSubtree(
                                key: _keyProductGrid, child: card);
                          }
                          return card;
                        },
                      ),
                  ] else ...[
                    recipesAsync.when(
                      data: (recipes) {
                        final filtered = recipes.where((r) {
                          final q = _search.trim().toLowerCase();
                          if (q.isEmpty) return true;
                          return r.name.toLowerCase().contains(q) ||
                              (r.description?.toLowerCase().contains(q) ?? false);
                        }).toList();

                        if (filtered.isEmpty) {
                          return const CasaEmptyState(
                            icon: Icons.menu_book_outlined,
                            title: 'Nenhuma receita ativa encontrada',
                          );
                        }

                        return KeyedSubtree(
                          key: _keyRecipeGrid,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Cabeçalho da seção ──
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${filtered.length} receita${filtered.length != 1 ? 's' : ''} disponível${filtered.length != 1 ? 'is' : ''}',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.neutral700,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (_selectedRecipeId != null)
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedRecipeId = null),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.neutral100,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.close_rounded, size: 12, color: AppColors.neutral500),
                                              const SizedBox(width: 3),
                                              Text('Limpar', style: AppTypography.labelSmall.copyWith(color: AppColors.neutral500, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // ── Grid de receitas ──
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: width >= 700 ? 4 : 2,
                                  mainAxisSpacing: AppSpacing.sm,
                                  crossAxisSpacing: AppSpacing.sm,
                                  childAspectRatio: 0.88,
                                ),
                                itemBuilder: (_, i) {
                                  final r = filtered[i];
                                  final selected = _selectedRecipeId == r.id;
                                  return _RecipeCard(
                                    recipe: r,
                                    index: i,
                                    selected: selected,
                                    onTap: () => setState(() => _selectedRecipeId = selected ? null : r.id),
                                  );
                                },
                              ),
                              // Banner Prophet — projeção do estoque ao executar
                              if (_selectedRecipeId != null)
                                _RecipeForecastBanner(
                                  recipe: filtered.firstWhere(
                                      (r) => r.id == _selectedRecipeId),
                                ),
                            ],
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => CasaEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Erro ao carregar receitas',
                        description: e.toString(),
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
        ),
      )),
      ]),
      floatingActionButton: _mode == _OutputMode.products
          ? KeyedSubtree(
              key: _keyConfirmFab,
              child: _ConfirmFabWithSummary(
                isLoading: _isLoading,
                selectedCount: _selectedQtyByProduct.values
                    .where((v) => v > 0)
                    .length,
                onPressed: () => _openSummary(productsAsync.valueOrNull ?? []),
              ),
            )
          : recipesAsync.valueOrNull?.any((r) => r.id == _selectedRecipeId) == true
              ? KeyedSubtree(
                  key: _keyConfirmFab,
                  child: _ConfirmFabWithSummary(
                    isLoading: _isLoading,
                    selectedCount: 1,
                    onPressed: () {
                      final recipe = recipesAsync.valueOrNull!
                          .firstWhere((r) => r.id == _selectedRecipeId);
                      _submitRecipe(recipe);
                    },
                  ),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─── FAB unificado: carrinho + confirmar num só botão ─────────────────────

class _ConfirmFabWithSummary extends StatelessWidget {
  final bool isLoading;
  final int selectedCount;
  final VoidCallback? onPressed;

  const _ConfirmFabWithSummary({
    required this.isLoading,
    required this.selectedCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final hasItems = selectedCount > 0;
    final enabled = hasItems && !isLoading;

    // FAB circular único — SEMPRE o mesmo ícone de carrinho.
    // Vazio = cinza; com itens = colorido (gradient brand) + badge de qty.
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: enabled ? onPressed : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: enabled
                        ? const [
                            Color(0xFF1E40AF),
                            Color(0xFF2563EB),
                            Color(0xFF0EA5E9),
                          ]
                        : const [Color(0xFFCBD5E1), Color(0xFF94A3B8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (enabled
                              ? const Color(0xFF2563EB)
                              : Colors.black)
                          .withValues(alpha: enabled ? 0.45 : 0.18),
                      blurRadius: enabled ? 16 : 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.white,
                          size: 27,
                        ),
                ),
              ),
            ),
            if (enabled)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    '$selectedCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      height: 1.1,
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

// ─── Tab selector moderno ─────────────────────────────────────────────────

/// Variante do _ModeTab para uso dentro do header (fundo gradiente escuro)
class _HeaderModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _HeaderModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [
                    Color(0xFF1D5FA8),
                    Color(0xFF38BDF8),
                  ])
                : null,
            borderRadius: BorderRadius.circular(AppRadius.small),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.65)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Label de seção do modal de filtro ─────────────────────────────────────

class _FilterSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FilterSectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─── Chip moderno selecionável do modal de filtro ───────────────────────────

class _ModernFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _ModernFilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color, color.withValues(alpha: 0.78)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : color.withValues(alpha: isDark ? 0.30 : 0.22),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white : cs.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Dados para o resumo ───────────────────────────────────────────────────

class _SummaryItem {
  final Product product;
  final int qty;
  const _SummaryItem({required this.product, required this.qty});
}

// ─── Tela de resumo (bottom sheet) ────────────────────────────────────────

class _SummarySheet extends StatelessWidget {
  final List<_SummaryItem> items;
  final String reasonLabel;
  const _SummarySheet({required this.items, required this.reasonLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final onBg = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A);
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final totalItems = items.fold<int>(0, (s, e) => s + e.qty);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: isDark
              ? Border.all(
                  color: const Color(0xFF1F2937).withValues(alpha: 0.6))
              : null,
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: sub.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.outbound_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo da Distribuição',
                          style: AppTypography.productName(
                            size: 19,
                            weight: FontWeight.w900,
                            color: onBg,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$reasonLabel  ·  ${items.length} produto${items.length != 1 ? 's' : ''}  ·  $totalItems ${totalItems != 1 ? 'unidades' : 'unidade'}',
                          style: TextStyle(
                              color: sub,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: sub.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 18, color: sub),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Divisor ───────────────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: sub.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
            const SizedBox(height: 10),

            // ── Lista de itens ────────────────────────────────────
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sub.withValues(alpha: isDark ? 0.12 : 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.15 : 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: isDark ? 0.25 : 0.15)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: item.product.imageUrl != null &&
                                  item.product.imageUrl!.isNotEmpty
                              ? Image.network(item.product.imageUrl!,
                                  fit: BoxFit.cover)
                              : const Icon(Icons.inventory_2_rounded,
                                  color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: AppTypography.productName(
                                  size: 15,
                                  weight: FontWeight.w800,
                                  color: onBg,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.product.category.name,
                                style: TextStyle(
                                    color: sub,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quantidade
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: isDark ? 0.3 : 0.2)),
                          ),
                          child: Text(
                            '${item.qty} ${item.product.unit}',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Botões ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 16),
              child: Column(
                children: [
                  // Aviso
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB)
                          .withValues(alpha: isDark ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2563EB)
                            .withValues(alpha: isDark ? 0.2 : 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'O sistema aplicará a regra FEFO — os lotes mais próximos do vencimento sairão primeiro.',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF1D4ED8),
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(false),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1F2937)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'Voltar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: sub,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(true),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF1D4ED8)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.outbound_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Confirmar Saída',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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

// ─── Card moderno de receita ───────────────────────────────────────────────

// ─── Banner Prophet — projeção ao executar receita ────────────────────────
class _RecipeForecastBanner extends ConsumerWidget {
  final StockRecipe recipe;
  const _RecipeForecastBanner({required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final forecasts =
        ref.watch(liveForecastsProvider).valueOrNull ?? const [];
    if (forecasts.isEmpty) return const SizedBox.shrink();

    final byPid = {for (final f in forecasts) f.productId: f};
    final problems = <String>[];
    for (final item in recipe.items) {
      final f = byPid[item.productId];
      if (f == null) continue;
      // Estoque ao vivo já está embutido em f.currentStock (liveForecastsProvider)
      final projected = f.currentStock - item.quantity;
      // Se sobra menos do que o consumo previsto de 7 dias, alerta.
      if (projected < f.forecastWeekly.round()) {
        problems.add(
          '${item.productName}: sobraria $projected un. '
          '(consumo previsto: ~${f.forecastWeekly.toStringAsFixed(0)}/sem)',
        );
      }
    }

    if (problems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning600.withValues(alpha: isDark ? 0.20 : 0.10),
            AppColors.warning600.withValues(alpha: isDark ? 0.10 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border:
            Border.all(color: AppColors.warning600.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_rounded,
                  color: AppColors.warning600, size: 18),
              const SizedBox(width: 6),
              Text(
                'Aviso Prophet',
                style: AppTypography.labelMedium.copyWith(
                    color: AppColors.warning600,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.warning600.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${problems.length}',
                  style: const TextStyle(
                    color: AppColors.warning600,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Executar esta receita pode deixar estoque insuficiente para o consumo previsto:',
            style: AppTypography.bodySmall
                .copyWith(color: cs.onSurface, fontSize: 11),
          ),
          const SizedBox(height: 6),
          ...problems.map((p) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ',
                        style: TextStyle(
                            color: AppColors.warning600,
                            fontWeight: FontWeight.w900)),
                    Expanded(
                      child: Text(p,
                          style: AppTypography.bodySmall
                              .copyWith(color: cs.onSurface, fontSize: 10.5)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final StockRecipe recipe;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  static const _gradients = [
    [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    [Color(0xFF064E3B), Color(0xFF059669)],
    [Color(0xFF4C1D95), Color(0xFF7C3AED)],
    [Color(0xFF7C2D12), Color(0xFFD97706)],
    [Color(0xFF831843), Color(0xFFDB2777)],
    [Color(0xFF0C4A6E), Color(0xFF0891B2)],
  ];

  static const _icons = [
    Icons.restaurant_rounded,
    Icons.inventory_2_rounded,
    Icons.volunteer_activism_rounded,
    Icons.shopping_bag_rounded,
    Icons.favorite_rounded,
    Icons.local_grocery_store_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _gradients[index % _gradients.length];
    final iconData = _icons[index % _icons.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? palette[1] : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? palette[1].withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header colorido ──
            Container(
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: palette,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Stack(
                children: [
                  // Círculo decorativo
                  Positioned(
                    right: -12,
                    top: -12,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: -14,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  // Ícone
                  Center(
                    child: Icon(iconData, color: Colors.white.withValues(alpha: 0.90), size: 26),
                  ),
                  // Check de selecionado
                  if (selected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
                          ],
                        ),
                        child: Icon(Icons.check_rounded, size: 14, color: palette[1]),
                      ),
                    ),
                  // Badge de itens
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${recipe.items.length} ${recipe.items.length == 1 ? 'item' : 'itens'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Corpo ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        recipe.description ?? 'Kit de distribuição',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ),
                    // ── Rodapé ──
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette[1].withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_outlined, size: 10, color: palette[1]),
                          const SizedBox(width: 3),
                          Text(
                            '${recipe.items.length} produto${recipe.items.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: palette[1],
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
