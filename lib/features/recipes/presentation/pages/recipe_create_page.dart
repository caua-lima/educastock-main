import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../ml/presentation/controllers/consumption_forecast_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../domain/entities/stock_recipe.dart';
import '../controllers/recipes_provider.dart';

const _kPurple = Color(0xFF7C3AED);
const _kPurpleDark = Color(0xFF4C1D95);

class RecipeCreatePage extends ConsumerStatefulWidget {
  final StockRecipe? editRecipe;
  const RecipeCreatePage({super.key, this.editRecipe});

  @override
  ConsumerState<RecipeCreatePage> createState() => _RecipeCreatePageState();
}

class _RecipeCreatePageState extends ConsumerState<RecipeCreatePage>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Map<String, int> _selectedQty = {};
  String _search = '';
  String? _categoryFilter;
  bool _saving = false;
  late final AnimationController _fabAnim;

  bool get _isEditing => widget.editRecipe != null;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (_isEditing) {
      final r = widget.editRecipe!;
      _nameCtrl.text = r.name;
      _descCtrl.text = r.description ?? '';
      for (final item in r.items) {
        _selectedQty[item.productId] = item.quantity;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    _fabAnim.dispose();
    super.dispose();
  }

  int get _selectedCount => _selectedQty.values.where((v) => v > 0).length;
  int get _totalQty => _selectedQty.values.fold(0, (a, b) => a + b);

  Future<void> _save(List<Product> products) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showCasaSnackbar(context, message: 'Informe o nome da receita.', isError: true);
      return;
    }
    final items = <RecipeItem>[];
    for (final e in _selectedQty.entries) {
      if (e.value <= 0) continue;
      final p = products.firstWhere((x) => x.id == e.key,
          orElse: () => Product(
                id: e.key,
                name: e.key,
                category: ProductCategory.outro,
                unit: 'un',
                isPerishable: false,
                createdAt: DateTime.now(),
                createdBy: '',
              ));
      items.add(RecipeItem(productId: p.id, productName: p.name, quantity: e.value));
    }
    if (items.isEmpty) {
      showCasaSnackbar(context, message: 'Selecione ao menos um produto.', isError: true);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(recipesNotifierProvider.notifier).saveRecipe(
            StockRecipe(
              id: widget.editRecipe?.id ?? '',
              name: name,
              description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
              items: items,
              createdAt: widget.editRecipe?.createdAt ?? DateTime.now(),
              createdBy: widget.editRecipe?.createdBy ?? user.id,
            ),
          );
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: _isEditing ? 'Receita atualizada!' : 'Receita criada com sucesso!',
        isSuccess: true,
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showCasaSnackbar(context, message: e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final stockMap = ref.watch(productAvailableQtyMapProvider);
    final labelMap = ref.watch(categoryLabelMapProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
      ModernProfileAppBar(
        title: _isEditing ? 'Editar Receita' : 'Nova Receita',
        pageIcon: Icons.restaurant_menu_rounded,
        iconColor: const Color(0xFFA78BFA),
        subtitle: _isEditing
            ? 'Altere os dados e salve'
            : 'Monte um modelo de distribuição',
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaHelpModal(
              context: context,
              pageTitle: _isEditing ? 'Editar receita' : 'Nova receita',
              pageDescription:
                  'Receitas são modelos para baixa rápida de vários produtos de uma só vez.',
              accentColor: _kPurple,
              headerIcon: Icons.restaurant_menu_rounded,
              tips: const [
                HelpTip(
                  icon: Icons.label_rounded,
                  title: 'Dê um nome claro',
                  description:
                      'Use nomes como "Kit Lanche", "Cesta Básica", "Mochila Escolar" — fáceis de reconhecer na hora da distribuição.',
                ),
                HelpTip(
                  icon: Icons.add_shopping_cart_rounded,
                  title: 'Adicione os ingredientes',
                  description:
                      'Toque nos produtos abaixo e defina a quantidade de cada item que compõe uma execução da receita.',
                ),
                HelpTip(
                  icon: Icons.outbound_rounded,
                  title: 'Use na distribuição',
                  description:
                      'Na tela de Saída, escolha esta receita e o sistema dá baixa em todos os itens automaticamente.',
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: productsAsync.when(
        data: (products) {
          // Receita só pode usar produtos que tenham estoque (ativo).
          // Mantemos itens já selecionados (caso o usuário esteja editando
          // uma receita e o lote tenha acabado posteriormente).
          final inStockProducts = products
              .where((p) =>
                  (stockMap[p.id] ?? 0) > 0 ||
                  (_selectedQty[p.id] ?? 0) > 0)
              .toList();
          final categories = inStockProducts
              .map((p) => p.category.name)
              .toSet()
              .toList()
            ..sort();
          final filtered = inStockProducts.where((p) {
            final q = _search.trim().toLowerCase();
            final ok = q.isEmpty ||
                p.name.toLowerCase().contains(q) ||
                (p.brand?.toLowerCase().contains(q) ?? false);
            final catOk = _categoryFilter == null || p.category.name == _categoryFilter;
            return ok && catOk;
          }).toList();

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // ── Hero preview card ──
                    SliverToBoxAdapter(child: _buildHeroCard(isDark)),

                    // ── Seção 1: informações ──
                    SliverToBoxAdapter(
                      child: _buildSection(
                        step: 1,
                        title: 'INFORMAÇÕES',
                        isDark: isDark,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _nameCtrl,
                              hint: 'Nome da receita  (ex: Kit Lanche)',
                              icon: Icons.label_rounded,
                              cardBg: cardBg,
                              textPrimary: textPrimary,
                              textSub: textSub,
                              borderColor: borderColor,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              controller: _descCtrl,
                              hint: 'Descrição  (opcional)',
                              icon: Icons.notes_rounded,
                              cardBg: cardBg,
                              textPrimary: textPrimary,
                              textSub: textSub,
                              borderColor: borderColor,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Seção 2: ingredientes selecionados ──
                    if (_selectedCount > 0)
                      SliverToBoxAdapter(
                        child: _buildSection(
                          step: 2,
                          title: 'INGREDIENTES  •  $_selectedCount produto${_selectedCount != 1 ? 's' : ''}',
                          isDark: isDark,
                          child: _SelectedIngredientsList(
                            selectedQty: Map.from(_selectedQty),
                            products: inStockProducts,
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textPrimary: textPrimary,
                            textSub: textSub,
                            onRemove: (pid) => setState(() => _selectedQty.remove(pid)),
                            onDecrement: (pid) => setState(() {
                              final next = (_selectedQty[pid] ?? 0) - 1;
                              if (next <= 0) {
                                _selectedQty.remove(pid);
                              } else {
                                _selectedQty[pid] = next;
                              }
                            }),
                            onIncrement: (pid) => setState(() =>
                                _selectedQty[pid] = (_selectedQty[pid] ?? 0) + 1),
                          ),
                        ),
                      ),

                    // ── Seção 3: buscar + adicionar produtos ──
                    SliverToBoxAdapter(
                      child: _buildSection(
                        step: _selectedCount > 0 ? 3 : 2,
                        title: 'ADICIONAR PRODUTOS',
                        isDark: isDark,
                        child: Column(
                          children: [
                            // Busca
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) => setState(() => _search = v),
                                style: TextStyle(color: textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Buscar produto por nome ou marca…',
                                  hintStyle: TextStyle(color: textSub, fontSize: 14),
                                  prefixIcon: Icon(Icons.search_rounded, color: textSub, size: 20),
                                  suffixIcon: _search.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.close_rounded, color: textSub, size: 18),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() => _search = '');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Category chips
                            SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _CatChip(
                                    label: 'Todos',
                                    selected: _categoryFilter == null,
                                    isDark: isDark,
                                    borderColor: borderColor,
                                    onTap: () => setState(() => _categoryFilter = null),
                                  ),
                                  const SizedBox(width: 6),
                                  ...categories.map((key) => Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: _CatChip(
                                          label: labelMap[key] ?? key,
                                          selected: _categoryFilter == key,
                                          isDark: isDark,
                                          borderColor: borderColor,
                                          onTap: () => setState(() => _categoryFilter = key),
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Grid de produtos ──
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: filtered.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 48, color: textSub),
                                      const SizedBox(height: 10),
                                      Text('Nenhum produto encontrado',
                                          style: TextStyle(color: textSub, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.82,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final p = filtered[i];
                                  final qty = _selectedQty[p.id] ?? 0;
                                  return CasaProductCard(
                                    name: p.name,
                                    imageUrl: p.imageUrl,
                                    fallbackIcon: Icons.restaurant_menu_rounded,
                                    palette: const [_kPurple, _kPurpleDark],
                                    animationIndex: i,
                                    onTap: () => setState(
                                        () => _selectedQty[p.id] = qty + 1),
                                    footer: Text(
                                      p.unit,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: textSub,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    actionFooter: CasaProductStepper(
                                      qty: qty,
                                      max: 9999,
                                      accent: _kPurple,
                                      onDecrement: qty > 0
                                          ? () => setState(() {
                                                final next = qty - 1;
                                                if (next <= 0) {
                                                  _selectedQty.remove(p.id);
                                                } else {
                                                  _selectedQty[p.id] = next;
                                                }
                                              })
                                          : null,
                                      onIncrement: () => setState(() =>
                                          _selectedQty[p.id] = qty + 1),
                                    ),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // ── Barra inferior de salvar ──
              _buildBottomBar(context, isDark, cardBg, borderColor, textSub, inStockProducts),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: const TextStyle(color: Color(0xFFDC2626))),
        ),
      )),
      ]),
    );
  }

  // ─── Hero preview card ───────────────────────────────────────────────────

  Widget _buildHeroCard(bool isDark) {
    final name = _nameCtrl.text.trim();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPurpleDark, _kPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withValues(alpha: isDark ? 0.30 : 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? (_isEditing ? 'Editar receita' : 'Nova receita') : name,
                  style: TextStyle(
                    color: name.isEmpty ? Colors.white.withValues(alpha: 0.50) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    fontStyle: name.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _selectedCount == 0
                      ? 'Nenhum ingrediente adicionado'
                      : '$_selectedCount produto${_selectedCount != 1 ? 's' : ''} · $_totalQty unidade${_totalQty != 1 ? 's' : ''} no total',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_selectedCount',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  Text(
                    'itens',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Seção com numeração e título ────────────────────────────────────────

  Widget _buildSection({
    required int step,
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: _kPurple,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  // ─── Text field genérico ─────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color cardBg,
    required Color textPrimary,
    required Color textSub,
    required Color borderColor,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textSub, fontSize: 13, fontWeight: FontWeight.w400),
          prefixIcon: Padding(
            padding: maxLines > 1 ? const EdgeInsets.only(bottom: 22) : EdgeInsets.zero,
            child: Icon(icon, color: _kPurple, size: 20),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  // ─── Barra inferior ──────────────────────────────────────────────────────

  Widget _buildBottomBar(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSub,
    List<Product> products,
  ) {
    final hasItems = _selectedCount > 0;
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final canSave = hasItems && hasName;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Resumo
          if (hasItems) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _kPurple.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kPurple.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_totalQty',
                    style: const TextStyle(color: _kPurple, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  Text(
                    'unid.',
                    style: TextStyle(color: _kPurple.withValues(alpha: 0.75), fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],
          // Botão salvar
          Expanded(
            child: SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: canSave && !_saving
                      ? const LinearGradient(colors: [_kPurpleDark, _kPurple])
                      : null,
                  color: canSave && !_saving ? null : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canSave && !_saving
                      ? [BoxShadow(color: _kPurple.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: _saving || !canSave ? null : () => _save(products),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_saving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      else
                        Icon(
                          _isEditing ? Icons.edit_rounded : Icons.save_rounded,
                          size: 18,
                          color: canSave ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _saving
                            ? 'Salvando…'
                            : !hasName
                                ? 'Informe o nome'
                                : !hasItems
                                    ? 'Adicione produtos'
                                    : _isEditing
                                        ? 'Salvar alterações'
                                        : 'Criar receita',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: canSave || _saving ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (canSave && !_saving) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Lista horizontal de ingredientes selecionados ────────────────────────

class _SelectedIngredientsList extends ConsumerWidget {
  final Map<String, int> selectedQty;
  final List<Product> products;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSub;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onDecrement;
  final ValueChanged<String> onIncrement;

  const _SelectedIngredientsList({
    required this.selectedQty,
    required this.products,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textSub,
    required this.onRemove,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = selectedQty.entries.where((e) => e.value > 0).toList();
    final forecasts =
        ref.watch(liveForecastsProvider).valueOrNull ?? const [];
    final forecastByPid = {for (final f in forecasts) f.productId: f};

    return Column(
      children: selected.map((entry) {
        final p = products.where((x) => x.id == entry.key).firstOrNull;
        final name = p?.name ?? entry.key;
        final unit = p?.unit ?? 'un';
        final qty = entry.value;
        final forecast = forecastByPid[entry.key];
        // Aviso: se o estoque ao vivo não cobre o consumo previsto 7d + a quantidade da receita
        final showWarning = forecast != null &&
            forecast.currentStock <
                (forecast.forecastWeekly + qty).round();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: showWarning
                  ? AppColors.warning600.withValues(alpha: 0.45)
                  : _kPurple.withValues(alpha: 0.25),
            ),
            boxShadow: [
              BoxShadow(
                color: (showWarning ? AppColors.warning600 : _kPurple)
                    .withValues(alpha: isDark ? 0.08 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
            children: [
              // Ícone
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: isDark ? 0.20 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 18, color: _kPurple),
              ),
              const SizedBox(width: 12),
              // Nome
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$qty $unit por execução',
                      style: TextStyle(color: _kPurple.withValues(alpha: 0.80), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Controles de quantidade
              _QtyRow(
                qty: qty,
                isDark: isDark,
                onDecrement: () => onDecrement(entry.key),
                onIncrement: () => onIncrement(entry.key),
              ),
              const SizedBox(width: 6),
              // Remover
              GestureDetector(
                onTap: () => onRemove(entry.key),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D1515) : const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF5C2020) : const Color(0xFFFFCDD2),
                    ),
                  ),
                  child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
          if (showWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warning600
                    .withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: AppColors.warning600.withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology_alt_rounded,
                      size: 13, color: AppColors.warning600),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Prophet: estoque (${forecast.currentStock}) '
                      'pode não cobrir o consumo previsto '
                      '(~${forecast.forecastWeekly.toStringAsFixed(0)}/sem) + receita',
                      style: TextStyle(
                        color: AppColors.warning600,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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
      }).toList(),
    );
  }
}

class _QtyRow extends StatelessWidget {
  final int qty;
  final bool isDark;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _QtyRow({required this.qty, required this.isDark, required this.onDecrement, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: _kPurple.withValues(alpha: isDark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPurple.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Btn(icon: Icons.remove_rounded, onTap: onDecrement, color: _kPurple),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$qty',
              style: const TextStyle(color: _kPurple, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          _Btn(icon: Icons.add_rounded, onTap: onIncrement, color: _kPurple),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _Btn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 30,
        height: 32,
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}

// ─── Category filter chip ─────────────────────────────────────────────────

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final Color borderColor;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _kPurple : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _kPurple : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : (isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151)),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
