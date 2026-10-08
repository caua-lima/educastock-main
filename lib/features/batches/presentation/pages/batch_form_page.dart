import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../locations/presentation/controllers/locations_provider.dart';
import '../../../locations/domain/entities/storage_location.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../../ml/presentation/widgets/risk_widgets.dart';
import '../../../stock/domain/entities/stock_movement.dart';
import '../../../stock/presentation/pages/movement_page.dart' show stockDatasourceProvider;
import '../../domain/entities/batch.dart';
import '../controllers/batches_provider.dart';

class BatchFormPage extends ConsumerStatefulWidget {
  final String productId;
  final String batchId;
  const BatchFormPage({super.key, required this.productId, this.batchId = ''});

  @override
  ConsumerState<BatchFormPage> createState() => _BatchFormPageState();
}

class _BatchFormPageState extends ConsumerState<BatchFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _keyBatchQty = GlobalKey();
  final _keyBatchExpiry = GlobalKey();
  final _keyBatchLocation = GlobalKey();
  final _productNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _donorController = TextEditingController();
  final _notesController = TextEditingController();
  final _batchNumberController = TextEditingController();

  DateTime? _expiryDate;
  final DateTime _entryDate = DateTime.now();
  bool _noExpiry = false;
  String _origin = 'doacao';
  String? _selectedLocationLabel;
  bool _prefilledProductName = false;
  bool _prefilledBatch = false;
  int _quantity = 1;

  // Imagem local
  File? _pickedImageFile;
  String? _existingImagePath;

  bool get _isEdit => widget.batchId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _quantityController.text = '1';
  }

  void _setQuantity(int value) {
    final normalized = value < 1 ? 1 : value;
    setState(() {
      _quantity = normalized;
      _quantityController.text = normalized.toString();
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _donorController.dispose();
    _notesController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }

  void _prefillFromBatch(Batch batch) {
    if (!mounted) return;
    setState(() {
      _batchNumberController.text = batch.batchNumber ?? '';
      _quantity = batch.quantity;
      _quantityController.text = batch.quantity.toString();
      _expiryDate = batch.expiryDate;
      _noExpiry = batch.noExpiry;
      _origin = batch.origin;
      _donorController.text = batch.donor ?? batch.supplier ?? '';
      _unitPriceController.text =
          batch.unitPrice != null ? batch.unitPrice!.toStringAsFixed(2) : '';
      _selectedLocationLabel = batch.shelfLocation;
      _notesController.text = batch.notes ?? '';
      _existingImagePath = batch.imageUrl;
    });
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Data de validade do lote',
      confirmText: 'CONFIRMAR',
      cancelText: 'CANCELAR',
      fieldLabelText: 'Data',
      fieldHintText: 'dd/mm/aaaa',
      errorFormatText: 'Formato inválido (dd/mm/aaaa)',
      errorInvalidText: 'Data fora do intervalo permitido',
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final existingProductId = widget.productId.trim();
    Product? linkedProduct;
    if (existingProductId.isNotEmpty) {
      linkedProduct = await ref
          .read(productsDatasourceProvider)
          .getProductById(existingProductId);
    }
    if (!mounted) return;
    final isPerishable = linkedProduct?.isPerishable ?? true;

    if (!isPerishable) {
      _noExpiry = true;
      _expiryDate = null;
    }

    if (isPerishable && !_noExpiry && _expiryDate == null) {
      showCasaSnackbar(context,
          message: 'Informe a data de validade do lote.', isError: true);
      return;
    }

    if (_expiryDate != null && _expiryDate!.isBefore(DateTime.now())) {
      final confirm = await CasaDialogConfirmacao.show(
        context: context,
        title: 'Produto Vencido',
        message:
            'A data de validade informada é anterior à data atual. Deseja registrar como descarte?',
        confirmLabel: 'Registrar Descarte',
        cancelLabel: 'Corrigir Data',
        isDanger: true,
      );
      if (confirm != true) return;
    }

    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (_selectedLocationLabel == null || _selectedLocationLabel!.isEmpty) {
      showCasaSnackbar(context,
          message: 'Selecione uma localização.', isError: true);
      return;
    }

    final qty = int.tryParse(_quantityController.text) ?? _quantity;
    if (qty <= 0) {
      showCasaSnackbar(context,
          message: 'Informe uma quantidade maior que zero.', isError: true);
      return;
    }

    final productName = _productNameController.text.trim();
    if (productName.isEmpty) {
      showCasaSnackbar(context,
          message: 'Informe o nome do produto.', isError: true);
      return;
    }

    final unitPrice = _origin == 'compra'
        ? double.tryParse(
            _unitPriceController.text.replaceAll(',', '.'))
        : null;

    if (_origin == 'compra' && (unitPrice == null || unitPrice < 0)) {
      showCasaSnackbar(context,
          message: 'Informe um preço unitário válido para compras.',
          isError: true);
      return;
    }

    var effectiveProductId = existingProductId;
    if (linkedProduct == null) {
      final activeCategories = ref.read(activeProductCategoriesProvider);
      final fallbackCategory =
          activeCategories.contains(ProductCategory.outro)
              ? ProductCategory.outro
              : activeCategories.first;
      final created = Product(
        id: '',
        name: productName,
        brand: null,
        category: fallbackCategory,
        unit: 'un',
        isPerishable: !_noExpiry,
        minimumStock: 0,
        createdAt: DateTime.now(),
        createdBy: user.id,
      );
      effectiveProductId =
          await ref.read(productsDatasourceProvider).saveProduct(created);
    }

    final batch = Batch(
      id: _isEdit ? widget.batchId : '',
      productId: effectiveProductId,
      productName: productName,
      quantity: qty,
      initialQuantity:
          _isEdit ? (qty) : qty, // mantém initialQuantity ao editar
      expiryDate: _noExpiry ? null : _expiryDate,
      noExpiry: _noExpiry,
      entryDate: _entryDate,
      origin: _origin,
      donor: _donorController.text.trim().isEmpty
          ? null
          : _donorController.text.trim(),
      batchNumber: _batchNumberController.text.trim().isEmpty
          ? null
          : _batchNumberController.text.trim(),
      supplier:
          _origin == 'compra' ? _donorController.text.trim() : null,
      unitPrice: unitPrice,
      shelfLocation: _selectedLocationLabel,
      imageUrl: _existingImagePath,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdBy: user.id,
      createdAt: DateTime.now(),
    );

    await ref
        .read(batchFormProvider.notifier)
        .saveBatch(batch, imageFile: _pickedImageFile);

    final state = ref.read(batchFormProvider);

    // Registra ENTRADA no histórico (somente novos lotes) — aparece como
    // card de entrada na aba Histórico.
    if (!_isEdit) {
      final newId = state.valueOrNull;
      if (newId != null && newId.isNotEmpty) {
        try {
          await ref.read(stockDatasourceProvider).logEntryMovement(
                StockMovement(
                  id: '',
                  productId: effectiveProductId,
                  productName: productName,
                  batchId: newId,
                  type: MovementType.entrada,
                  quantity: qty,
                  reasonCode: _origin,
                  reason: 'Cadastro de lote',
                  performedBy: user.id,
                  performedByName: user.name,
                  performedAt: DateTime.now(),
                  auditAfter: {'quantity': qty},
                ),
              );
        } catch (_) {
          // Histórico é best-effort; não bloqueia o cadastro.
        }
      }
    }

    if (!mounted) return;
    state.when(
      data: (id) {
        if (id != null) {
          showCasaSnackbar(
            context,
            message: _isEdit
                ? 'Lote atualizado com sucesso!'
                : 'Produto adicionado ao estoque!',
            isSuccess: true,
          );
          context.go('/products/$effectiveProductId');
        }
      },
      error: (e, _) => showCasaSnackbar(context,
          message: 'Erro ao salvar lote.', isError: true),
      loading: () {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM/yyyy');
    final formState = ref.watch(batchFormProvider);
    final locationsState = ref.watch(activeLocationsProvider);
    final isLoading = formState is AsyncLoading;
    final productAsync = ref.watch(productByIdProvider(widget.productId));
    final productName = productAsync.valueOrNull?.name;

    // Pré-preenche nome do produto
    if (!_prefilledProductName && productName != null) {
      _prefilledProductName = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _productNameController.text = productName;
      });
    }

    // Pré-preenche campos do lote em modo edição
    if (_isEdit && !_prefilledBatch) {
      final batchAsync = ref.watch(batchByIdProvider(widget.batchId));
      batchAsync.whenData((batch) {
        if (batch != null && !_prefilledBatch) {
          _prefilledBatch = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _prefillFromBatch(batch);
          });
        }
      });
    }

    return Scaffold(
      body: Column(children: [
      ModernProfileAppBar(
        title: _isEdit ? 'Editar Lote' : 'Cadastrar Lote',
        pageIcon: Icons.inventory_rounded,
        iconColor: const Color(0xFF38BDF8),
        subtitle: productName != null
            ? 'Produto: $productName'
            : 'Adicionar ao estoque',
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyBatchQty,
                  title: 'Identificação do Lote',
                  description: 'Preencha o número que identifica este lote (geralmente impresso na embalagem como "LOT" + código) e a quantidade total de unidades recebidas. Cada lote representa UMA entrada com mesma origem e validade.',
                  icon: Icons.tag_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🏷️ Use o código LOT impresso pelo fornecedor',
                    '📦 1 lote = 1 entrada com mesma validade',
                    '🔢 Quantidade em unidades (kg, un, L conforme produto)',
                    'Lotes diferentes do mesmo produto = entradas separadas',
                  ],
                ),
                TutorialStep(
                  key: _keyBatchExpiry,
                  title: 'Validade e Origem',
                  description: 'Informe a data de validade EXATA da embalagem (campo só aparece se o produto for perecível) e a origem do lote: Doação, Compra, Parceiro ou Transferência. Estes dados alimentam alertas e relatórios.',
                  icon: Icons.event_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '📅 Validade alimenta o sistema de alertas automaticamente',
                    '🎁 Doação: itens recebidos sem custo',
                    '🛒 Compra: itens adquiridos pela ONG',
                    '🤝 Parceiro: vindos de organizações parceiras',
                  ],
                ),
                TutorialStep(
                  key: _keyBatchLocation,
                  title: 'Localização Física',
                  description: 'Selecione onde este lote será guardado fisicamente no depósito. Escolha a prateleira e o nível na lista suspensa. Esta informação ajuda a equipe a encontrar rapidamente o lote na hora da distribuição.',
                  icon: Icons.shelves,
                  align: ContentAlign.bottom,
                  hints: const [
                    '📍 Padrão: "Prateleira A · Nível 1"',
                    '➕ Não tem a localização? Crie em Configurações → Depósito',
                    '🥶 Use nomes especiais para áreas (geladeira, freezer)',
                    'Localização correta acelera distribuição em 70%',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
            children: [
              // ── 1. Número do lote + Quantidade ──────────────────────
              KeyedSubtree(
                key: _keyBatchQty,
                child: _BatchSection(
                  icon: Icons.tag_rounded,
                  iconColor: AppColors.brandPrimary600,
                  title: 'Informações do Lote',
                  cs: cs,
                  child: Column(
                    children: [
                      CasaTextField(
                        label: 'Número do Lote (embalagem)',
                        hint: 'Ex: LOT20251201, L4578',
                        controller: _batchNumberController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        prefixIcon:
                            const Icon(Icons.tag_rounded, size: 20),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _QuantityRow(
                        quantity: _quantity,
                        cs: cs,
                        onAdd: (add) => _setQuantity(_quantity + add),
                        onDecrement: () => _setQuantity(_quantity - 1),
                        onIncrement: () => _setQuantity(_quantity + 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── 2. Validade ──────────────────────────────────────────
              Builder(builder: (_) {
                final isPerishable =
                    productAsync.valueOrNull?.isPerishable ?? true;
                if (!isPerishable) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_noExpiry) {
                      setState(() {
                        _noExpiry = true;
                        _expiryDate = null;
                      });
                    }
                  });
                  return KeyedSubtree(
                    key: _keyBatchExpiry,
                    child: _BatchSection(
                      icon: Icons.all_inclusive_rounded,
                      iconColor: AppColors.neutral500,
                      title: 'Validade',
                      cs: cs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.neutral500
                              .withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                              color: AppColors.neutral500
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined,
                                size: 18,
                                color: AppColors.neutral500),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Produto não perecível — sem data de validade',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return KeyedSubtree(
                  key: _keyBatchExpiry,
                  child: _BatchSection(
                    icon: Icons.event_rounded,
                    iconColor: _expiryDate != null
                        ? AppColors.success600
                        : AppColors.warning600,
                    title: 'Validade',
                    cs: cs,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _pickExpiryDate,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: _expiryDate != null
                                  ? LinearGradient(colors: [
                                      AppColors.success600
                                          .withValues(alpha: 0.1),
                                      AppColors.brandPrimary600
                                          .withValues(alpha: 0.04),
                                    ])
                                  : null,
                              color: _expiryDate == null
                                  ? cs.surfaceContainer
                                  : null,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.input),
                              border: Border.all(
                                color: _expiryDate != null
                                    ? AppColors.success600
                                        .withValues(alpha: 0.55)
                                    : cs.outlineVariant
                                        .withValues(alpha: 0.5),
                                width: _expiryDate != null ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _expiryDate != null
                                          ? [
                                              AppColors.success600,
                                              const Color(0xFF22C55E)
                                            ]
                                          : [
                                              AppColors.warning600,
                                              AppColors.brandPrimary600
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(
                                      Icons.calendar_month_rounded,
                                      size: 20,
                                      color: Colors.white),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _expiryDate != null
                                            ? 'Data de validade'
                                            : 'Toque para selecionar',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _expiryDate != null
                                              ? AppColors.success600
                                                  .withValues(alpha: 0.85)
                                              : cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _expiryDate != null
                                            ? fmt.format(_expiryDate!)
                                            : 'dd/mm/aaaa',
                                        style: TextStyle(
                                          fontSize:
                                              _expiryDate != null ? 19 : 14,
                                          fontWeight: _expiryDate != null
                                              ? FontWeight.w800
                                              : FontWeight.w400,
                                          color: _expiryDate != null
                                              ? cs.onSurface
                                              : cs.onSurfaceVariant
                                                  .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_expiryDate != null)
                                  GestureDetector(
                                    onTap: () => setState(
                                        () => _expiryDate = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: cs.outlineVariant
                                            .withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.close_rounded,
                                          size: 15,
                                          color: cs.onSurfaceVariant),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandPrimary600
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16,
                                        color: AppColors.brandPrimary600),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // OCR fica embaixo, alinhado à direita
                        Align(
                          alignment: Alignment.centerRight,
                          child: ExpiryOcrButton(
                            onDateSuggested: (date) {
                              setState(() => _expiryDate = date);
                              showCasaSnackbar(
                                context,
                                message:
                                    'Data lida: ${DateFormat('dd/MM/yyyy').format(date)} — confirme se está correta',
                                isSuccess: true,
                              );
                            },
                          ),
                        ),
                        // Preview ML em tempo real (assim que a data é definida)
                        if (_noExpiry || _expiryDate != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          RiskPreviewBanner(
                            expiryDate: _expiryDate,
                            noExpiry: _noExpiry,
                            quantity: _quantity,
                            entryDate: _entryDate,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.lg),

              // ── 3. Origem ────────────────────────────────────────────
              _BatchSection(
                icon: Icons.source_outlined,
                iconColor: AppColors.secondaryBlue600,
                title: 'Origem',
                cs: cs,
                child: Column(
                  children: [
                    Row(
                      children: [
                        _OriginCard(
                          originKey: 'doacao',
                          label: 'Doação',
                          icon: Icons.volunteer_activism_rounded,
                          color: AppColors.success600,
                          selected: _origin == 'doacao',
                          onTap: () =>
                              setState(() => _origin = 'doacao'),
                          cs: cs,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _OriginCard(
                          originKey: 'compra',
                          label: 'Compra',
                          icon: Icons.shopping_cart_rounded,
                          color: AppColors.brandPrimary600,
                          selected: _origin == 'compra',
                          onTap: () =>
                              setState(() => _origin = 'compra'),
                          cs: cs,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _OriginCard(
                          originKey: 'parceiro',
                          label: 'Parceiro',
                          icon: Icons.handshake_rounded,
                          color: AppColors.warning600,
                          selected: _origin == 'parceiro',
                          onTap: () =>
                              setState(() => _origin = 'parceiro'),
                          cs: cs,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _OriginCard(
                          originKey: 'transferencia',
                          label: 'Transfer.',
                          icon: Icons.swap_horiz_rounded,
                          color: AppColors.secondaryBlue600,
                          selected: _origin == 'transferencia',
                          onTap: () =>
                              setState(() => _origin = 'transferencia'),
                          cs: cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: _origin == 'compra'
                          ? 'Fornecedor'
                          : 'Doador / Parceiro',
                      controller: _donorController,
                      prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20),
                    ),
                    if (_origin == 'compra') ...[
                      const SizedBox(height: AppSpacing.md),
                      CasaTextField(
                        label: 'Preço unitário (R\$) *',
                        hint: 'Ex: 12,50',
                        controller: _unitPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        prefixIcon: const Icon(Icons.attach_money_rounded,
                            size: 20),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total: R\$ ${((double.tryParse(_unitPriceController.text.replaceAll(',', '.')) ?? 0) * _quantity).toStringAsFixed(2)}',
                          style: AppTypography.labelSmall
                              .copyWith(color: AppColors.success600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── 4. Localização ───────────────────────────────────────
              locationsState.when(
                data: (locations) => KeyedSubtree(
                  key: _keyBatchLocation,
                  child: _LocationPicker(
                    locations: locations,
                    selectedLabel: _selectedLocationLabel,
                    onChanged: (label) =>
                        setState(() => _selectedLocationLabel = label),
                    onManageLocations: () =>
                        context.push(AppRoutes.locations),
                  ),
                ),
                loading: () => const CasaCardSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── 5. Observações ───────────────────────────────────────
              _BatchSection(
                icon: Icons.notes_rounded,
                iconColor: AppColors.neutral500,
                title: 'Observações (opcional)',
                cs: cs,
                child: CasaTextField(
                  label: '',
                  hint: 'Informações adicionais sobre este lote...',
                  controller: _notesController,
                  maxLines: 3,
                ),
              ),
            ],
          ),
        ),
      )),
      ]),
      floatingActionButton: _BatchSaveFab(
          isLoading: isLoading,
          isEdit: _isEdit,
          onSave: _submit),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─── FAB ──────────────────────────────────────────────────────────────────────

class _BatchSaveFab extends StatelessWidget {
  final bool isLoading;
  final bool isEdit;
  final VoidCallback onSave;
  const _BatchSaveFab(
      {required this.isLoading,
      required this.isEdit,
      required this.onSave});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isLoading
            ? null
            : const LinearGradient(colors: [
                AppColors.brandPrimary600,
                AppColors.secondaryBlue600
              ]),
        color: isLoading ? AppColors.neutral500 : null,
        borderRadius: BorderRadius.circular(AppRadius.button),
        boxShadow: [
          BoxShadow(
              color: AppColors.brandPrimary600.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(180, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button)),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Icon(
                isEdit
                    ? Icons.save_rounded
                    : Icons.inventory_2_rounded,
                size: 18,
                color: Colors.white),
        label: Text(
          isEdit ? 'Salvar Alterações' : 'Cadastrar',
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Section wrapper ──────────────────────────────────────────────────────────

class _BatchSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;
  final ColorScheme cs;
  const _BatchSection(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.child,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [iconColor, Color.lerp(iconColor, Colors.black, 0.18)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.productName(
                    size: 16,
                    weight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

// ─── Quantity row ─────────────────────────────────────────────────────────────

class _QuantityRow extends StatelessWidget {
  final int quantity;
  final ColorScheme cs;
  final void Function(int) onAdd;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityRow({
    required this.quantity,
    required this.cs,
    required this.onAdd,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_rounded,
              size: 18, color: AppColors.brandPrimary600),
          const SizedBox(width: AppSpacing.sm),
          Text('Quantidade',
              style: AppTypography.labelMedium
                  .copyWith(color: cs.onSurface)),
          const Spacer(),
          for (final add in [5, 10, 20])
            GestureDetector(
              onTap: () => onAdd(add),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary600
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                      color: AppColors.brandPrimary600
                          .withValues(alpha: 0.25)),
                ),
                child: Text('+$add',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.brandPrimary600,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          const SizedBox(width: 4),
          _QtyBtn(
              icon: Icons.remove_rounded,
              enabled: quantity > 1,
              onTap: onDecrement),
          SizedBox(
            width: 44,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTypography.headingSmall.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w800),
            ),
          ),
          _QtyBtn(
              icon: Icons.add_rounded,
              enabled: true,
              onTap: onIncrement),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _QtyBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.brandPrimary600.withValues(alpha: 0.1)
              : cs.surfaceContainer,
          shape: BoxShape.circle,
          border: Border.all(
              color: enabled
                  ? AppColors.brandPrimary600.withValues(alpha: 0.3)
                  : cs.outlineVariant),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled
                ? AppColors.brandPrimary600
                : cs.onSurfaceVariant),
      ),
    );
  }
}

// ─── Origin Card ──────────────────────────────────────────────────────────────

class _OriginCard extends StatelessWidget {
  final String originKey;
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _OriginCard(
      {required this.originKey,
      required this.label,
      required this.icon,
      required this.color,
      required this.selected,
      required this.onTap,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.15)
                : cs.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected
                  ? color
                  : cs.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? color : cs.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 10,
                    color: selected ? color : cs.onSurfaceVariant,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Location Picker ──────────────────────────────────────────────────────────
// Seletor de 2 etapas: Prateleira → Nível

class _LocationPicker extends ConsumerStatefulWidget {
  final List<StorageLocation> locations;
  final String? selectedLabel;
  final ValueChanged<String?> onChanged;
  final VoidCallback onManageLocations;

  const _LocationPicker({
    required this.locations,
    required this.selectedLabel,
    required this.onChanged,
    required this.onManageLocations,
  });

  @override
  ConsumerState<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<_LocationPicker> {
  String? _shelfGroup; // groupKey selecionado (ex: "A")

  @override
  void didUpdateWidget(covariant _LocationPicker old) {
    super.didUpdateWidget(old);
    // Quando pai limpa a seleção, reseta o picker
    if (widget.selectedLabel == null && old.selectedLabel != null) {
      setState(() => _shelfGroup = null);
    }
  }

  List<String> get _shelfGroups {
    final s = widget.locations.map((l) => l.groupKey).toSet().toList();
    s.sort();
    return s;
  }

  List<StorageLocation> get _locsInGroup =>
      widget.locations.where((l) => l.groupKey == _shelfGroup).toList()
        ..sort((a, b) =>
            (a.level ?? '').compareTo(b.level ?? ''));

  void _pickShelf(String group) {
    setState(() => _shelfGroup = group);
    widget.onChanged(null);
  }

  void _pickLocation(StorageLocation loc) {
    widget.onChanged(loc.label);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.locations.isEmpty) {
      return _EmptyLocations(
          onManageLocations: widget.onManageLocations, cs: cs);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ],
                ),
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.shelves, size: 15, color: Colors.white),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Localização no Depósito',
              style: AppTypography.labelLarge.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.onManageLocations,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary600,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Gerenciar'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Etapa 1: Prateleira
        _StepLabel(
            label: '1. Prateleira', done: _shelfGroup != null),
        const SizedBox(height: AppSpacing.xs),
        _ShelfChipRow(
          groups: _shelfGroups,
          selected: _shelfGroup,
          locations: widget.locations,
          onTap: _pickShelf,
        ),

        // Etapa 2: Nível
        if (_shelfGroup != null) ...[
          const SizedBox(height: AppSpacing.md),
          _StepLabel(
              label: '2. Nível',
              done: widget.selectedLabel != null),
          const SizedBox(height: AppSpacing.xs),
          _buildLevels(cs, isDark),
        ],

        // Confirmação
        if (widget.selectedLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.success600.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(
                  color: AppColors.success600.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.success600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.selectedLabel!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.success600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _shelfGroup = null);
                    widget.onChanged(null);
                  },
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: AppColors.success600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLevels(ColorScheme cs, bool isDark) {
    final allBatches =
        ref.watch(allAvailableBatchesProvider).valueOrNull ?? [];

    if (_locsInGroup.isEmpty) {
      return Text(
        'Nenhum nível cadastrado para esta prateleira.',
        style: TextStyle(
            fontSize: 12, color: cs.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _locsInGroup.map((loc) {
        final lv = loc.level ?? '—';
        final isSelected = widget.selectedLabel == loc.label;
        final limit = loc.productsPerLevel;
        final count = limit != null
            ? allBatches
                .where((b) => b.shelfLocation == loc.label)
                .length
            : null;
        final isFull =
            limit != null && count != null && count >= limit;

        return GestureDetector(
          onTap: isFull ? null : () => _pickLocation(loc),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(colors: [
                      AppColors.brandPrimary600,
                      AppColors.secondaryBlue600,
                    ])
                  : null,
              color: isSelected
                  ? null
                  : isFull
                      ? AppColors.danger600.withValues(alpha: 0.08)
                      : cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : isFull
                        ? AppColors.danger600.withValues(alpha: 0.45)
                        : cs.outlineVariant,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.brandPrimary600
                            .withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nível $lv',
                      style: AppTypography.labelMedium.copyWith(
                        color: isSelected
                            ? Colors.white
                            : isFull
                                ? AppColors.danger600
                                : cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isFull) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.block_rounded,
                          size: 11, color: AppColors.danger600),
                    ],
                  ],
                ),
                if (limit != null && count != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 52,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: (count / limit).clamp(0.0, 1.0),
                        minHeight: 3,
                        backgroundColor: isSelected
                            ? Colors.white.withValues(alpha: 0.3)
                            : cs.outlineVariant,
                        valueColor: AlwaysStoppedAnimation(
                          isSelected
                              ? Colors.white
                              : isFull
                                  ? AppColors.danger600
                                  : AppColors.success600,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '$count/$limit',
                    style: TextStyle(
                      fontSize: 9,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : isFull
                              ? AppColors.danger600
                              : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Shelf chip row ───────────────────────────────────────────────────────────

class _ShelfChipRow extends StatelessWidget {
  final List<String> groups;
  final String? selected;
  final List<StorageLocation> locations;
  final ValueChanged<String> onTap;

  const _ShelfChipRow({
    required this.groups,
    required this.selected,
    required this.locations,
    required this.onTap,
  });

  Color _colorFor(String g) {
    const colors = [
      AppColors.brandPrimary600,
      AppColors.secondaryBlue600,
      AppColors.success600,
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      AppColors.warning600,
      Color(0xFFDB2777),
      Color(0xFF059669),
    ];
    if (g.isEmpty) return AppColors.brandPrimary600;
    return colors[g.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: groups.map((g) {
          final isSelected = g == selected;
          final color = _colorFor(g);
          final levelCount =
              locations.where((l) => l.groupKey == g).length;
          return GestureDetector(
            onTap: () => onTap(g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [color, Color.lerp(color, Colors.black, 0.18)!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected
                    ? null
                    : color.withValues(alpha: isDark ? 0.10 : 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : color.withValues(alpha: 0.30),
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        g.toUpperCase(),
                        style: AppTypography.productName(
                          size: 16,
                          weight: FontWeight.w900,
                          color: isSelected ? Colors.white : color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Prateleira',
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.78)
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$levelCount nív${levelCount != 1 ? 'eis' : 'el'}',
                        style: AppTypography.labelMedium.copyWith(
                          fontSize: 12,
                          color: isSelected ? Colors.white : color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Empty locations ──────────────────────────────────────────────────────────

class _EmptyLocations extends StatelessWidget {
  final VoidCallback onManageLocations;
  final ColorScheme cs;
  const _EmptyLocations(
      {required this.onManageLocations, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning600.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.warning600.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.warning600, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nenhuma localização cadastrada.',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.warning600)),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: onManageLocations,
                  icon: const Icon(Icons.add_location_alt_outlined,
                      size: 15),
                  label: const Text('Cadastrar prateleira'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary600,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

// ─── Step label ───────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  final String label;
  final bool done;
  const _StepLabel({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: done ? AppColors.success600 : cs.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: done ? AppColors.success600 : cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
