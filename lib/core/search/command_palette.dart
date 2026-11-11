import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/controllers/auth_provider.dart';
import '../../features/products/domain/entities/product.dart';
import '../../features/products/presentation/controllers/products_provider.dart';
import '../design_system/tokens/color_tokens.dart';
import '../design_system/tokens/typography_tokens.dart';
import '../router/app_router.dart';

/// Tipo de resultado da busca.
enum PaletteKind { page, action, product }

/// Um resultado da busca global: uma tela, uma ação ou um produto.
class PaletteEntry {
  final PaletteKind kind;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  /// Palavras extras que também encontram este item (sinônimos, termos do dia a dia).
  final String keywords;
  final String route;

  /// `true` abre por cima (formulários de tela cheia, voltar retorna); `false` troca de aba.
  final bool push;

  const PaletteEntry({
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.route,
    this.keywords = '',
    this.push = false,
  });
}

/// Remove acentos e deixa minúsculo, para "acucar" achar "Açúcar".
String normalizeSearch(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString();
}

/// Telas e ações que a busca conhece, filtradas pelo papel do usuário.
List<PaletteEntry> paletteActionsFor(AppUser? user) {
  final role = user?.role;
  final isAdmin = role == UserRole.admin;
  final canOps = role == UserRole.admin || role == UserRole.estoquista;
  final canWrite = canOps || role == UserRole.voluntario;
  return [
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.home_rounded, color: AppColors.brandPrimary600,
        title: 'Início', subtitle: 'Painel com resumo do estoque', route: AppRoutes.dashboard,
        keywords: 'dashboard painel resumo home'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.inventory_2_rounded, color: AppColors.secondaryBlue600,
        title: 'Estoque', subtitle: 'Produtos e lotes', route: AppRoutes.productList,
        keywords: 'produtos lotes itens lista'),
    if (canWrite)
      const PaletteEntry(
          kind: PaletteKind.action, icon: Icons.outbound_rounded, color: AppColors.danger600,
          title: 'Registrar saída', subtitle: 'Baixa de estoque (consumo, doação, perda)',
          route: AppRoutes.movement, keywords: 'saida baixa consumo retirada uso'),
    if (canWrite)
      const PaletteEntry(
          kind: PaletteKind.action, icon: Icons.qr_code_scanner_rounded, color: AppColors.brandPrimary600,
          title: 'Escanear código de barras', subtitle: 'Entrada de produto pelo código',
          route: AppRoutes.scanner, push: true, keywords: 'scanner camera entrada leitor barcode'),
    if (canWrite)
      const PaletteEntry(
          kind: PaletteKind.action, icon: Icons.add_box_rounded, color: AppColors.secondaryBlue600,
          title: 'Novo produto', subtitle: 'Cadastrar um produto', route: AppRoutes.productForm,
          push: true, keywords: 'cadastrar criar adicionar produto'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.history_rounded, color: Color(0xFF7C3AED),
        title: 'Histórico', subtitle: 'Todas as entradas e saídas', route: AppRoutes.history,
        keywords: 'movimentacoes entradas saidas historico'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.bar_chart_rounded, color: AppColors.success600,
        title: 'Relatórios', subtitle: 'Gráficos, previsões e exportação PDF/Excel',
        route: AppRoutes.reports, keywords: 'graficos exportar pdf excel csv indicadores'),
    if (canOps)
      const PaletteEntry(
          kind: PaletteKind.page, icon: Icons.volunteer_activism_rounded, color: Color(0xFFB7791F),
          title: 'Doações recebidas', subtitle: 'Fila do Portal do Doador',
          route: AppRoutes.opsDonations, keywords: 'doacoes portal doador fila aprovar receber'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.notifications_active_rounded, color: AppColors.warning600,
        title: 'Alertas de validade', subtitle: 'Lotes vencendo e vencidos', route: AppRoutes.alerts,
        keywords: 'alertas vencimento validade vencidos'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.menu_book_rounded, color: AppColors.brandPrimary600,
        title: 'Receitas', subtitle: 'Saída automática por cardápio', route: AppRoutes.recipes,
        keywords: 'receitas cardapio refeicao merenda'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.insights_rounded, color: Color(0xFF0E7490),
        title: 'Risco de vencimento (IA)', subtitle: 'Lotes classificados por risco',
        route: AppRoutes.mlInsights, keywords: 'ml ia inteligencia artificial risco random forest'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.trending_up_rounded, color: Color(0xFF0E7490),
        title: 'Previsão de consumo', subtitle: 'Quanto comprar nos próximos 30 dias',
        route: AppRoutes.mlForecast, keywords: 'previsao consumo compras prophet reposicao'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.place_rounded, color: AppColors.secondaryBlue600,
        title: 'Locais de armazenamento', subtitle: 'Despensa, geladeira, almoxarifado',
        route: AppRoutes.locations, keywords: 'locais armazenamento despensa geladeira prateleira'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.fact_check_rounded, color: Color(0xFF475569),
        title: 'Auditoria', subtitle: 'Quem fez o quê e quando', route: AppRoutes.audit,
        keywords: 'auditoria log registro acoes'),
    if (isAdmin)
      const PaletteEntry(
          kind: PaletteKind.page, icon: Icons.rule_rounded, color: AppColors.warning600,
          title: 'Aprovar ajustes', subtitle: 'Ajustes de estoque pendentes',
          route: AppRoutes.adjustmentApprovals, keywords: 'aprovacao ajuste pendente'),
    const PaletteEntry(
        kind: PaletteKind.page, icon: Icons.settings_rounded, color: Color(0xFF475569),
        title: 'Configurações', subtitle: 'Conta, tema e preferências', route: AppRoutes.settings,
        keywords: 'configuracoes ajustes tema escuro conta'),
    if (isAdmin)
      const PaletteEntry(
          kind: PaletteKind.page, icon: Icons.group_rounded, color: Color(0xFF475569),
          title: 'Usuários', subtitle: 'Equipe e permissões', route: AppRoutes.usersManagement,
          keywords: 'usuarios equipe permissoes papeis voluntarios'),
    if (isAdmin)
      const PaletteEntry(
          kind: PaletteKind.page, icon: Icons.category_rounded, color: Color(0xFF475569),
          title: 'Categorias', subtitle: 'Categorias de produtos', route: AppRoutes.categoriesSettings,
          keywords: 'categorias tipos'),
    if (isAdmin)
      const PaletteEntry(
          kind: PaletteKind.page, icon: Icons.tune_rounded, color: Color(0xFF475569),
          title: 'Configurar alertas', subtitle: 'Prazos e notificações de validade',
          route: AppRoutes.alertsSettings, keywords: 'configurar alertas prazos notificacoes'),
  ];
}

/// Busca pura (testável): telas/ações primeiro, depois até [maxProducts] produtos.
/// Cada palavra digitada precisa aparecer no título, descrição, sinônimos ou código.
List<PaletteEntry> searchPalette(
  String query,
  List<PaletteEntry> actions,
  List<Product> products, {
  int maxProducts = 8,
}) {
  final tokens = normalizeSearch(query).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return actions;

  bool matches(String haystack) => tokens.every(haystack.contains);

  final pages = actions
      .where((a) => matches(normalizeSearch('${a.title} ${a.subtitle} ${a.keywords}')))
      .toList();

  final productHits = <PaletteEntry>[];
  for (final p in products) {
    if (!p.isActive) continue;
    final hay = normalizeSearch('${p.name} ${p.brand ?? ''} ${p.categoryLabel} ${p.barcode ?? ''}');
    if (!matches(hay)) continue;
    productHits.add(PaletteEntry(
      kind: PaletteKind.product,
      icon: Icons.inventory_2_outlined,
      color: AppColors.secondaryBlue600,
      title: p.name,
      subtitle: [p.categoryLabel, if ((p.brand ?? '').isNotEmpty) p.brand!, if ((p.barcode ?? '').isNotEmpty) p.barcode!]
          .join(' · '),
      route: '/products/${p.id}',
      push: true,
    ));
    if (productHits.length >= maxProducts) break;
  }
  // Nomes que começam com o termo vêm antes.
  final first = tokens.first;
  productHits.sort((a, b) {
    final sa = normalizeSearch(a.title).startsWith(first) ? 0 : 1;
    final sb = normalizeSearch(b.title).startsWith(first) ? 0 : 1;
    return sa != sb ? sa - sb : a.title.compareTo(b.title);
  });
  return [...pages, ...productHits];
}

/// Abre a busca global (atalho Ctrl+K no computador, botão "Buscar" no celular).
Future<void> showCommandPalette(BuildContext context) {
  final router = GoRouter.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => CommandPalette(router: router),
  );
}

class CommandPalette extends ConsumerStatefulWidget {
  final GoRouter router;
  const CommandPalette({super.key, required this.router});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  int _selected = 0;
  static const _itemExtent = 60.0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _open(PaletteEntry e) {
    Navigator.of(context).pop();
    if (e.push) {
      widget.router.push(e.route);
    } else {
      widget.router.go(e.route);
    }
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + delta) % count);
    if (_selected < 0) _selected += count;
    if (!_scroll.hasClients) return;
    final top = _selected * _itemExtent;
    final view = _scroll.position.viewportDimension;
    if (top < _scroll.offset) {
      _scroll.jumpTo(top);
    } else if (top + _itemExtent > _scroll.offset + view) {
      _scroll.jumpTo(top + _itemExtent - view);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final produtosAsync = ref.watch(productsProvider);
    final products = produtosAsync.valueOrNull ?? const <Product>[];
    // Logo depois de abrir o app a lista ainda está chegando: dizer "nada encontrado"
    // nessa hora engana.
    final carregandoProdutos = produtosAsync.isLoading && !produtosAsync.hasValue;
    final results = searchPalette(_controller.text, paletteActionsFor(user), products);
    if (_selected >= results.length) _selected = results.isEmpty ? 0 : results.length - 1;

    final size = MediaQuery.sizeOf(context);
    final maxHeight = (size.height * 0.72).clamp(260.0, 620.0);

    return Dialog(
      alignment: size.width >= 600 ? const Alignment(0, -0.55) : Alignment.topCenter,
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: size.width >= 600 ? 40 : 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1, results.length),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1, results.length),
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        textInputAction: TextInputAction.go,
                        decoration: const InputDecoration(
                          hintText: 'Buscar produto, código de barras ou tela…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() => _selected = 0),
                        onSubmitted: (_) {
                          if (results.isNotEmpty) _open(results[_selected]);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar (Esc)',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
              Flexible(
                child: results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          carregandoProdutos
                              ? 'Carregando os produtos…'
                              : 'Nada encontrado para “${_controller.text.trim()}”.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemExtent: _itemExtent,
                        itemCount: results.length,
                        itemBuilder: (_, i) => _PaletteTile(
                          entry: results[i],
                          selected: i == _selected,
                          onTap: () => _open(results[i]),
                        ),
                      ),
              ),
              if (size.width >= 600)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: cs.surfaceContainerLow,
                  child: Text(
                    'Setas para navegar · Enter para abrir · Esc para fechar',
                    style: AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  final PaletteEntry entry;
  final bool selected;
  final VoidCallback onTap;
  const _PaletteTile({required this.entry, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tag = switch (entry.kind) {
      PaletteKind.page => 'Tela',
      PaletteKind.action => 'Ação',
      PaletteKind.product => 'Produto',
    };
    return Material(
      color: selected ? cs.primary.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(entry.icon, size: 20, color: entry.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                    if (entry.subtitle.isNotEmpty)
                      Text(entry.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant, height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(tag, style: AppTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
