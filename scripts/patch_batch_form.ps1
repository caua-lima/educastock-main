$src = 'lib/features/batches/presentation/pages/batch_form_page.dart'
$lines = Get-Content $src -Encoding UTF8

# head: everything up to and including @override (index 370 = line 371)
$head = $lines[0..370]

# tail: starting from the // Seletor de localização comment (index 671 = line 672)
$tail = $lines[671..($lines.Count-1)]

$newMiddle = @'
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM/yyyy');
    final formState = ref.watch(batchFormProvider);
    final locationsState = ref.watch(activeLocationsProvider);
    final isLoading = formState is AsyncLoading;
    final productAsync = ref.watch(productByIdProvider(widget.productId));
    final productName = productAsync.valueOrNull?.name;
    if (!_prefilledProductName && productName != null) {
      _productNameController.text = productName;
      _prefilledProductName = true;
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Cadastrar Lote',
        subtitle: productName != null ? 'Produto: $productName' : 'Adicionar ao estoque',
        showBackButton: true,
      ),
      floatingActionButton: _BatchSaveFab(isLoading: isLoading, onSave: _submit),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
            children: [

              // ─── Seção 1: Número do lote + Quantidade ─────────────
              _BatchSection(
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
                      prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
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
                              onTap: () => _setQuantity(_quantity + add),
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
                          Row(
                            children: [
                              _QtyBtn(
                                icon: Icons.remove_rounded,
                                enabled: _quantity > 1,
                                onTap: () => _setQuantity(_quantity - 1),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '$_quantity',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.headingSmall.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              _QtyBtn(
                                icon: Icons.add_rounded,
                                enabled: true,
                                onTap: () => _setQuantity(_quantity + 1),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Seção 2: Validade ─────────────────────────────────
              _BatchSection(
                icon: Icons.event_rounded,
                iconColor: _expiryDate != null
                    ? AppColors.success600
                    : _noExpiry
                        ? AppColors.neutral500
                        : AppColors.warning600,
                title: 'Validade',
                cs: cs,
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _ToggleBtn(
                            label: 'Com validade',
                            icon: Icons.event_available_rounded,
                            selected: !_noExpiry,
                            onTap: () => setState(() => _noExpiry = false),
                            cs: cs,
                          ),
                          _ToggleBtn(
                            label: 'Sem validade',
                            icon: Icons.all_inclusive_rounded,
                            selected: _noExpiry,
                            onTap: () => setState(() {
                              _noExpiry = true;
                              _expiryDate = null;
                            }),
                            cs: cs,
                          ),
                        ],
                      ),
                    ),
                    if (!_noExpiry) ...[
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: _pickExpiryDate,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: _expiryDate != null
                                ? AppColors.success600.withValues(alpha: 0.06)
                                : cs.surfaceContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadius.input),
                            border: Border.all(
                              color: _expiryDate != null
                                  ? AppColors.success600
                                      .withValues(alpha: 0.4)
                                  : cs.outlineVariant
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_month_rounded,
                                  size: 20,
                                  color: _expiryDate != null
                                      ? AppColors.success600
                                      : cs.onSurfaceVariant),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Data de Validade',
                                      style: AppTypography.labelSmall
                                          .copyWith(
                                              color: cs.onSurfaceVariant,
                                              fontSize: 10),
                                    ),
                                    Text(
                                      _expiryDate != null
                                          ? fmt.format(_expiryDate!)
                                          : 'Toque para selecionar',
                                      style: AppTypography.labelMedium
                                          .copyWith(
                                        color: _expiryDate != null
                                            ? cs.onSurface
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  size: 18, color: cs.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ─── Seção 3: Origem ───────────────────────────────────
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
                          onTap: () => setState(() => _origin = 'doacao'),
                          cs: cs,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _OriginCard(
                          originKey: 'compra',
                          label: 'Compra',
                          icon: Icons.shopping_cart_rounded,
                          color: AppColors.brandPrimary600,
                          selected: _origin == 'compra',
                          onTap: () => setState(() => _origin = 'compra'),
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
                        keyboardType:
                            const TextInputType.numberWithOptions(
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
              const SizedBox(height: AppSpacing.md),

              // ─── Seção 4: Localização ──────────────────────────────
              locationsState.when(
                data: (locations) => _LocationPicker(
                  locations: locations,
                  selectedLabel:
                      _manualLocation ? null : _selectedLocationLabel,
                  onChanged: (label) => setState(() {
                    _selectedLocationLabel = label;
                    _manualLocation = false;
                  }),
                  onManual: () => setState(() {
                    _manualLocation = !_manualLocation;
                    if (_manualLocation) _selectedLocationLabel = null;
                  }),
                  onManageLocations: () =>
                      context.push(AppRoutes.locations),
                ),
                loading: () => const CasaCardSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              if (_manualLocation) ...[
                const SizedBox(height: AppSpacing.sm),
                CasaTextField(
                  label: 'Localização manual (Sala/Prateleira/Nível)',
                  controller: _locationController,
                  prefixIcon:
                      const Icon(Icons.location_on_outlined, size: 20),
                  hint: 'Ex: Dep-A / P3 / N2',
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // ─── Seção 5: Observações ──────────────────────────────
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
      ),
    );
  }
}

// ─── FAB de confirmação ────────────────────────────────────────────────────

class _BatchSaveFab extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSave;
  const _BatchSaveFab({required this.isLoading, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
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
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.add_box_rounded,
                    size: 20, color: Colors.white),
            label: const Text(
              'Adicionar ao Estoque',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Seção de card do formulário ──────────────────────────────────────────

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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: AppTypography.labelLarge.copyWith(
                    color: cs.onSurface, fontWeight: FontWeight.w700),
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

// ─── Botão de quantidade ──────────────────────────────────────────────────

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
            color:
                enabled ? AppColors.brandPrimary600 : cs.onSurfaceVariant),
      ),
    );
  }
}

// ─── Toggle com/sem validade ──────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _ToggleBtn(
      {required this.label,
      required this.icon,
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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ])
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? Colors.white : cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Card de origem ────────────────────────────────────────────────────────

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
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? color : cs.onSurfaceVariant,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

'@

$combined = $head + ($newMiddle -split '\r?\n') + $tail
$combined | Set-Content $src -Encoding UTF8
Write-Host "Done. New line count: $(($combined).Count)"
