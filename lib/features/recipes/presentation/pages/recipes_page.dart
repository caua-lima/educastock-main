import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../controllers/recipes_provider.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  String _search = '';
  final _keyRecipeHeader = GlobalKey();
  final _keyRecipeSearch = GlobalKey();
  final _keyRecipeCard = GlobalKey();
  final _keyRecipeFab = GlobalKey();

  static const _gradients = [
    [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    [Color(0xFF0F766E), Color(0xFF0891B2)],
    [Color(0xFFDC2626), Color(0xFFDB2777)],
    [Color(0xFF059669), Color(0xFF2563EB)],
    [Color(0xFFD97706), Color(0xFFEA580C)],
    [Color(0xFF2563EB), Color(0xFF0F766E)],
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recipesNotifierProvider.notifier).ensureSeed();
    });
  }

  void _openCreateRecipeSheet() => context.push(AppRoutes.recipeCreate);

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final actionState = ref.watch(recipesNotifierProvider);
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
        title: 'Receitas',
        subtitle: 'Modelos de distribuição rápida',
        pageIcon: Icons.menu_book_rounded,
        iconColor: const Color(0xFFA78BFA),
        showBackButton: true,
        extraContent: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Card de resumo de receitas
            KeyedSubtree(
              key: _keyRecipeHeader,
              child: recipesAsync.maybeWhen(
                data: (recipes) => Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.menu_book_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${recipes.length} receita${recipes.length == 1 ? '' : 's'} ativa${recipes.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Modelos prontos para distribuição rápida',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                orElse: () => const SizedBox(height: 64),
              ),
            ),
            const SizedBox(height: 10),
            // ── Busca
            Container(
              key: _keyRecipeSearch,
              height: 42,
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
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: 'Buscar receita…',
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
                              color: Colors.white.withValues(alpha: 0.7)),
                          onPressed: () => setState(() => _search = ''),
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
          ],
        ),
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyRecipeHeader,
                  title: 'Painel de Receitas',
                  description: 'Este banner roxo mostra o resumo das suas receitas cadastradas. Receitas são modelos prontos que dão baixa em vários produtos de uma só vez — ideais para cozinhas que preparam refeições padrão (kit lanche, cesta básica, mochila escolar).',
                  icon: Icons.menu_book_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'O número grande mostra quantas receitas estão ativas',
                    'Cada receita = um modelo de distribuição reutilizável',
                    'Crie receitas para refeições recorrentes da ONG',
                    'Economiza tempo no dia-a-dia da distribuição',
                  ],
                ),
                TutorialStep(
                  key: _keyRecipeSearch,
                  title: 'Buscar Receita',
                  description: 'Digite o nome da receita para localizá-la rapidamente na lista. A busca também procura nas descrições — então palavras como "lanche", "café" ou "almoço" funcionam mesmo sem estar no nome.',
                  icon: Icons.search_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Busca em tempo real enquanto você digita',
                    'Ignora maiúsculas e acentos',
                    'Procura no nome E na descrição da receita',
                    'Toque no X para limpar e ver todas novamente',
                  ],
                ),
                TutorialStep(
                  key: _keyRecipeCard,
                  title: 'Cartão de Receita',
                  description: 'Cada cartão mostra uma receita com sua faixa colorida no topo, ícone, nome, descrição e badge com total de ingredientes. Toque no cartão para ver os detalhes completos ou nos ícones de ação (editar/excluir) à direita.',
                  icon: Icons.restaurant_menu_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'A faixa colorida no topo é só visual — cada receita tem uma cor',
                    'O badge mostra: quantidade de produtos · total de unidades',
                    'Toque longo: ações rápidas (executar, duplicar, excluir)',
                    'Receitas podem ser executadas na tela de Distribuição/Saída',
                  ],
                ),
                TutorialStep(
                  key: _keyRecipeFab,
                  title: 'Criar Nova Receita',
                  description: 'Toque no botão roxo "+" para abrir o assistente de criação. Você dá um nome (ex: "Kit Lanche da Tarde"), uma descrição opcional e adiciona os produtos com suas quantidades. A receita fica pronta para ser executada quantas vezes quiser.',
                  icon: Icons.add_circle_outline_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Use nomes claros que toda a equipe entenda',
                    'Adicione apenas produtos que tenham estoque ativo',
                    'A descrição ajuda a lembrar quando usar a receita',
                    'Receitas podem ser editadas a qualquer momento',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: recipesAsync.when(
        data: (recipes) {
          final filtered = recipes.where((r) {
            final q = _search.trim().toLowerCase();
            if (q.isEmpty) return true;
            return r.name.toLowerCase().contains(q) ||
                (r.description?.toLowerCase().contains(q) ?? false);
          }).toList();

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(Icons.menu_book_rounded,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text('Nenhuma receita encontrada',
                            style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 17)),
                        const SizedBox(height: 6),
                        Text('Crie modelos para baixa rápida de estoque',
                            style: TextStyle(color: textSub, fontSize: 13)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _openCreateRecipeSheet,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Criar receita'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final r = filtered[i];
                        final totalQty = r.items.fold<int>(
                            0, (acc, item) => acc + item.quantity);
                        final gradColors =
                            _gradients[i % _gradients.length];

                        final card = Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: borderColor),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black
                                          .withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Column(
                            children: [
                              // Colorful top bar
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradColors,
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: gradColors,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(13),
                                          ),
                                          child: const Icon(
                                              Icons.menu_book_rounded,
                                              color: Colors.white,
                                              size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      r.name,
                                                      style: TextStyle(
                                                        color: textPrimary,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 16,
                                                        letterSpacing: -0.3,
                                                      ),
                                                    ),
                                                  ),
                                                  if (r.isPredefined)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 8,
                                                          vertical: 3),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: gradColors[0]
                                                            .withValues(
                                                                alpha: 0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .bolt_rounded,
                                                              size: 12,
                                                              color: gradColors[
                                                                  0]),
                                                          const SizedBox(
                                                              width: 3),
                                                          Text('Modelo',
                                                              style: TextStyle(
                                                                  color:
                                                                      gradColors[
                                                                          0],
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700)),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${r.items.length} ${r.items.length == 1 ? 'item' : 'itens'} • $totalQty unid. total',
                                                style: TextStyle(
                                                    color: textSub,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (r.description != null &&
                                        r.description!.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        r.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            color: textSub, fontSize: 13),
                                      ),
                                    ],
                                    if (r.items.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: r.items
                                            .take(4)
                                            .map((item) => Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF1F2937)
                                                        : const Color(
                                                            0xFFF1F5F9),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                        color: borderColor),
                                                  ),
                                                  child: Text(
                                                    '${item.productName} ×${item.quantity}',
                                                    style: TextStyle(
                                                        color: textSub,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                                ))
                                            .toList()
                                          ..addAll(
                                            r.items.length > 4
                                                ? [
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10,
                                                          vertical: 4),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: gradColors[0]
                                                            .withValues(
                                                                alpha: 0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Text(
                                                        '+${r.items.length - 4} mais',
                                                        style: TextStyle(
                                                            color: gradColors[
                                                                0],
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                      ),
                                                    )
                                                  ]
                                                : [],
                                          ),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: actionState.isLoading
                                                ? null
                                                : () => _showExecuteSheet(
                                                    context,
                                                    r,
                                                    gradColors),
                                            child: Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                gradient: actionState.isLoading
                                                    ? null
                                                    : LinearGradient(
                                                        colors: gradColors),
                                                color: actionState.isLoading
                                                    ? (isDark
                                                        ? const Color(
                                                            0xFF1F2937)
                                                        : const Color(
                                                            0xFFE5E7EB))
                                                    : null,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (actionState.isLoading)
                                                    const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white),
                                                    )
                                                  else
                                                    const Icon(
                                                        Icons
                                                            .play_arrow_rounded,
                                                        color: Colors.white,
                                                        size: 18),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    actionState.isLoading
                                                        ? 'Executando…'
                                                        : 'Executar',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: actionState.isLoading
                                              ? null
                                              : () => context.push(
                                                  AppRoutes.recipeCreate,
                                                  extra: r),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1E3A5F)
                                                  : const Color(0xFFEFF6FF),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF1E40AF)
                                                    : const Color(0xFFBFDBFE),
                                              ),
                                            ),
                                            child: const Icon(
                                                Icons.edit_outlined,
                                                color: Color(0xFF2563EB),
                                                size: 20),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: actionState.isLoading
                                              ? null
                                              : () => _confirmDelete(
                                                  context,
                                                  r.id,
                                                  r.name,
                                                  isDark,
                                                  textPrimary,
                                                  textSub,
                                                  cardBg,
                                                  borderColor),
                                          child: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF2D1515)
                                                  : const Color(0xFFFFF1F2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isDark
                                                    ? const Color(0xFF5C2020)
                                                    : const Color(0xFFFFCDD2),
                                              ),
                                            ),
                                            child: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFFDC2626),
                                                size: 20),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                        if (i == 0) {
                          return KeyedSubtree(key: _keyRecipeCard, child: card);
                        }
                        return card;
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, __) => _RecipeSkeleton(isDark: Theme.of(context).brightness == Brightness.dark),
        ),
        error: (e, _) => Center(
          child: Text('Erro: $e',
              style: const TextStyle(color: Color(0xFFDC2626))),
        ),
      )),
      ]),
      floatingActionButton: _buildFab(),
    );
  }

  void _confirmDelete(
    BuildContext context,
    String id,
    String name,
    bool isDark,
    Color textPrimary,
    Color textSub,
    Color cardBg,
    Color borderColor,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2D1515)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFDC2626), size: 26),
            ),
            const SizedBox(height: 14),
            Text('Desativar receita?',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 6),
            Text('"$name" será removida da lista.',
                style: TextStyle(color: textSub, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: borderColor),
                    ),
                    child:
                        Text('Cancelar', style: TextStyle(color: textSub)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref
                          .read(recipesNotifierProvider.notifier)
                          .deactivateRecipe(id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Desativar',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      key: _keyRecipeFab,
      onPressed: _openCreateRecipeSheet,
      backgroundColor: const Color(0xFF7C3AED),
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Nova receita',
          style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  void _showExecuteSheet(
    BuildContext context,
    dynamic recipe,
    List<Color> gradColors,
  ) {
    final batches = ref.read(allAvailableBatchesProvider).valueOrNull ?? [];
    // Group available stock by productId
    final Map<String, int> available = {};
    for (final b in batches) {
      final pid = b.productId;
      available[pid] = (available[pid] ?? 0) + (b.quantity);
    }

    final items = recipe.items as List;
    final checks = items.map((item) {
      final pid = item.productId as String;
      final required = item.quantity as int;
      final avail = available[pid] ?? 0;
      return (
        name: item.productName as String,
        required: required,
        available: avail,
        ok: avail >= required,
      );
    }).toList();

    final allOk = checks.every((c) => c.ok);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
        final textPrimary =
            isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
        final textSub =
            isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          expand: false,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSub.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradColors),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.checklist_rtl_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(recipe.name as String,
                                style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                            Text(
                              allOk
                                  ? 'Estoque suficiente para executar'
                                  : 'Estoque insuficiente em alguns itens',
                              style: TextStyle(
                                color: allOk
                                    ? AppColors.success600
                                    : AppColors.danger600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: textSub.withValues(alpha: 0.15)),
                Expanded(
                  child: ListView.separated(
                    controller: sc,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    itemCount: checks.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = checks[i];
                      final color = c.ok
                          ? AppColors.success600
                          : AppColors.danger600;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: color.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              c.ok
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: color,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(c.name,
                                      style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Necessário: ${c.required}  •  Disponível: ${c.available}',
                                    style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(
                            allOk
                                ? Icons.play_arrow_rounded
                                : Icons.warning_amber_rounded,
                            size: 18,
                          ),
                          label: Text(
                            allOk ? 'Executar' : 'Executar mesmo assim',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: allOk
                                ? gradColors.first
                                : AppColors.warning600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await ref
                                  .read(recipesNotifierProvider
                                      .notifier)
                                  .executeRecipe(recipe);
                              if (!context.mounted) return;
                              showCasaSnackbar(context,
                                  message:
                                      'Receita executada com sucesso!',
                                  isSuccess: true);
                            } catch (e) {
                              if (!context.mounted) return;
                              showCasaSnackbar(context,
                                  message: e
                                      .toString()
                                      .replaceFirst('Exception: ', ''),
                                  isError: true);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

// ─── Skeleton de carregamento ───────────────────────────────────────────────

class _RecipeSkeleton extends StatelessWidget {
  final bool isDark;
  const _RecipeSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: c,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration:
                          BoxDecoration(color: c, borderRadius: BorderRadius.circular(13))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 140, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: 90, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
                  ]),
                ]),
                const SizedBox(height: 14),
                Container(width: double.infinity, height: 44, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
