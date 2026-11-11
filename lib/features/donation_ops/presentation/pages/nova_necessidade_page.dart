import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../donations/domain/entities/donation_need.dart';
import '../../../donations/domain/nova_necessidade.dart';
import '../../../donations/presentation/controllers/donation_needs_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../controllers/donation_ops_provider.dart';

/// A equipe publica o que a ONG precisa (ex.: "Leite integral", 120 un, crítica). A
/// necessidade aparece na hora para os doadores, em "Precisa" e nas prioridades.
class NovaNecessidadePage extends ConsumerStatefulWidget {
  const NovaNecessidadePage({super.key});

  @override
  ConsumerState<NovaNecessidadePage> createState() =>
      _NovaNecessidadePageState();
}

class _NovaNecessidadePageState extends ConsumerState<NovaNecessidadePage> {
  static const _unidades = [
    'un',
    'kg',
    'g',
    'L',
    'mL',
    'pacote',
    'caixa',
    'dúzia',
    'fardo'
  ];

  final _titulo = TextEditingController();
  final _quantidade = TextEditingController();
  final _validade = TextEditingController(text: '30');
  final _observacao = TextEditingController();
  ProductCategory _categoria = ProductCategory.alimento;
  String _unidade = 'un';
  NeedPriority _prioridade = NeedPriority.alta;
  Product? _produto;
  bool _salvando = false;
  List<String> _problemas = const [];

  @override
  void dispose() {
    _titulo.dispose();
    _quantidade.dispose();
    _validade.dispose();
    _observacao.dispose();
    super.dispose();
  }

  void _usarProduto(Product p) {
    setState(() {
      _produto = p;
      _titulo.text = p.name;
      _categoria = p.category;
      _unidade = p.unit.trim().isEmpty ? 'un' : p.unit.trim();
      if (!p.isPerishable) _validade.text = '0';
    });
  }

  NovaNecessidade _montar() => NovaNecessidade(
        titulo: _titulo.text,
        categoria: _categoria.name,
        unidade: _unidade,
        quantidade: int.tryParse(_quantidade.text.trim()) ?? 0,
        prioridade: _prioridade,
        validadeMinimaDias: int.tryParse(_validade.text.trim()) ?? 0,
        produtoId: _produto?.id,
        observacao: _observacao.text,
      );

  Future<void> _publicar() async {
    final nova = _montar();
    final problemas = nova.problemas();
    setState(() => _problemas = problemas);
    if (problemas.isNotEmpty) return;
    final usuario = ref.read(currentUserProvider);
    if (!canOperateDonations(usuario)) {
      showCasaSnackbar(context,
          message: 'Só o administrador e o estoquista publicam necessidades.',
          isError: true);
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref
          .read(donationNeedsDatasourceProvider)
          .criarNecessidade(nova, criadoPor: usuario!.id);
      if (!mounted) return;
      showCasaSnackbar(context,
          message:
              '"${nova.titulo.trim()}" publicada: já aparece para os doadores.',
          isSuccess: true);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      showCasaSnackbar(context,
          message:
              'Não foi possível publicar agora. Verifique a conexão e tente de novo.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rotulos = ref.watch(categoryLabelMapProvider);
    final produtos =
        ref.watch(productsProvider).valueOrNull ?? const <Product>[];
    final unidades = {..._unidades, _unidade}.toList();

    InputDecoration campo(String rotulo, {String? ajuda, IconData? icone}) =>
        InputDecoration(
          labelText: rotulo,
          helperText: ajuda,
          helperMaxLines: 2,
          prefixIcon: icone == null ? null : Icon(icone, size: 20),
        );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Nova necessidade')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'O que a Casa da Criança precisa receber. A necessidade aparece na hora para os '
            'doadores, em "Precisa" e nas prioridades da semana.',
            style:
                AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Produto do estoque (opcional): liga o recebimento ao produto certo.
          if (_produto == null)
            Autocomplete<Product>(
              displayStringForOption: (p) => p.name,
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.length < 2) return const Iterable<Product>.empty();
                return produtos
                    .where(
                        (p) => p.isActive && p.name.toLowerCase().contains(q))
                    .take(8);
              },
              onSelected: _usarProduto,
              fieldViewBuilder: (context, controller, focus, onSubmit) =>
                  TextField(
                controller: controller,
                focusNode: focus,
                decoration: campo('Buscar no estoque (opcional)',
                    ajuda:
                        'Escolher um produto já cadastrado preenche o resto e liga o recebimento a ele.',
                    icone: Icons.search_rounded),
              ),
            )
          else
            InputChip(
              avatar: const Icon(Icons.inventory_2_rounded, size: 18),
              label: Text('Ligada ao produto: ${_produto!.name}'),
              onDeleted: () => setState(() => _produto = null),
              deleteButtonTooltipMessage: 'Desligar do produto',
            ),
          const SizedBox(height: AppSpacing.lg),

          TextField(
            controller: _titulo,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 80,
            decoration: campo('Item que a ONG precisa *',
                ajuda: 'Ex.: Leite integral', icone: Icons.label_rounded),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<ProductCategory>(
            initialValue: _categoria,
            isExpanded: true,
            decoration: campo('Categoria', icone: Icons.category_rounded),
            items: [
              for (final c in ProductCategory.values)
                DropdownMenuItem(
                    value: c,
                    child: Text(rotulos[c.name] ?? defaultCategoryLabel(c))),
            ],
            onChanged: (c) => setState(() => _categoria = c ?? _categoria),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _quantidade,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      campo('Quantidade *', icone: Icons.numbers_rounded),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_unidade),
                  initialValue: _unidade,
                  isExpanded: true,
                  decoration: campo('Unidade'),
                  items: [
                    for (final u in unidades)
                      DropdownMenuItem(value: u, child: Text(u))
                  ],
                  onChanged: (u) => setState(() => _unidade = u ?? _unidade),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Prioridade',
              style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<NeedPriority>(
            segments: [
              for (final p in NeedPriority.values)
                ButtonSegment(value: p, label: Text(p.label)),
            ],
            selected: {_prioridade},
            onSelectionChanged: (s) => setState(() => _prioridade = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _validade,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: campo('Validade mínima (dias)',
                ajuda:
                    'Quantos dias o item precisa ter até vencer quando chegar. 0 = sem exigência.',
                icone: Icons.event_available_rounded),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _observacao,
            maxLength: 200,
            maxLines: 2,
            decoration: campo('Observação para o doador (opcional)',
                ajuda: 'Ex.: Preferência por caixas de 1 L.',
                icone: Icons.notes_rounded),
          ),
          if (_problemas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final p in _problemas)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(p,
                    style: AppTypography.bodySmall.copyWith(color: cs.error)),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          CasaButton(
            label: 'Publicar necessidade',
            icon: Icons.campaign_rounded,
            isLoading: _salvando,
            onPressed: _salvando ? null : _publicar,
          ),
        ],
      ),
    );
  }
}
