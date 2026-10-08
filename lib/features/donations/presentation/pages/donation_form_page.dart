import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/utils/auth_error_mapper.dart';
import '../../../products/domain/entities/product.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../domain/donation_validators.dart';
import '../../domain/entities/donation.dart';
import '../../domain/entities/donation_item.dart';
import '../../domain/entities/donation_need.dart';
import '../../domain/entities/donation_point.dart';
import '../../domain/entities/donation_rules.dart';
import '../controllers/donation_draft_notifier.dart';
import '../controllers/donation_needs_provider.dart';
import '../controllers/donation_submit_notifier.dart';
import '../controllers/donations_provider.dart';
import '../widgets/donor_header.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/step_progress_bar.dart';

final _dateFormat = DateFormat('dd/MM/yyyy');

String _two(int n) => n.toString().padLeft(2, '0');
String _timeLabel(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// D06–D07 — Registrar doação. Um único `PageController` conduz os 4 passos
/// (sem rotas separadas, evitando conflito de GlobalKey do ShellRoute):
///   0 O que doar · 1 Quantidade e validade · 2 Entrega · 3 Revisão e termos.
class DonationFormPage extends ConsumerStatefulWidget {
  /// Necessidade pré-selecionada (vem de D04/D05); abre direto no passo 2.
  final String? needId;

  const DonationFormPage({super.key, this.needId});

  @override
  ConsumerState<DonationFormPage> createState() => _DonationFormPageState();
}

class _DonationFormPageState extends ConsumerState<DonationFormPage> {
  static const _stepTitles = [
    'O que doar',
    'Quantidade e validade',
    'Entrega',
    'Revisão e termos',
  ];

  final PageController _controller = PageController();
  // Estado apenas de navegação/UI; as regras de negócio ficam no draft notifier.
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final notifier = ref.read(donationDraftProvider.notifier);
    await notifier.restore();
    if (!mounted) return;

    final needId = widget.needId;
    if (needId != null && needId.isNotEmpty) {
      final need = await ref.read(needByIdProvider(needId).future);
      if (!mounted) return;
      if (need != null && !need.isCovered) {
        notifier.startFromNeed(need);
        _goTo(1, animate: false);
      }
    }
  }

  void _goTo(int step, {bool animate = true}) {
    if (!_controller.hasClients) return;
    setState(() => _step = step);
    if (animate) {
      _controller.animateToPage(
        step,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _controller.jumpToPage(step);
    }
  }

  void _back() {
    if (_step == 1) {
      ref.read(donationDraftProvider.notifier).cancelEditing();
      _goTo(0);
    } else if (_step > 0) {
      _goTo(_step - 1);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.donorHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Column(
          children: [
            DonorHeader(
              title: 'Registrar doação',
              subtitle: 'Passo ${_step + 1} de 4 · ${_stepTitles[_step]}',
              onBack: _back,
            ),
            Container(
              color: cs.surfaceContainerLow,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: StepProgressBar(total: 4, current: _step),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepOrigin(onGoTo: _goTo, onExit: _back),
                  _StepItem(onGoTo: _goTo),
                  _StepDelivery(onGoTo: _goTo),
                  _StepReview(onGoTo: _goTo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Rodapé fixo com as ações do passo ───────────────────────────────────────

class _FooterBar extends StatelessWidget {
  final List<Widget> children;

  const _FooterBar({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Passo 1: o que doar ─────────────────────────────────────────────────────

class _StepOrigin extends ConsumerWidget {
  final void Function(int step, {bool animate}) onGoTo;
  final VoidCallback onExit;

  const _StepOrigin({required this.onGoTo, required this.onExit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final draft = ref.watch(donationDraftProvider);
    final needs = ref.watch(openNeedsProvider);
    final notifier = ref.read(donationDraftProvider.notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (draft.items.isNotEmpty) ...[
                CasaSectionHeader(title: 'Itens da doação', count: draft.items.length),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < draft.items.length; i++) ...[
                  _ItemTile(
                    item: draft.items[i],
                    onEdit: () {
                      notifier.editItem(i);
                      onGoTo(1);
                    },
                    onRemove: () => notifier.removeItem(i),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
              CasaSectionHeader(
                title: draft.items.isEmpty
                    ? 'Escolha o que a ONG precisa'
                    : 'Adicionar outro item',
              ),
              const SizedBox(height: AppSpacing.sm),
              needs.when(
                loading: () => const Column(
                  children: [
                    CasaCardSkeleton(),
                    SizedBox(height: AppSpacing.md),
                    CasaCardSkeleton(),
                  ],
                ),
                error: (_, __) => Text(
                  'Não foi possível carregar as necessidades. '
                  'Você ainda pode oferecer um item livre abaixo.',
                  style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Text(
                      'Nenhuma necessidade aberta agora. '
                      'Você pode oferecer um item livre abaixo.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: cs.onSurfaceVariant),
                    );
                  }
                  return Column(
                    children: [
                      for (final need in list) ...[
                        _NeedPickTile(
                          need: need,
                          onTap: () {
                            notifier.startFromNeed(need);
                            onGoTo(1);
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              CasaButton(
                label: 'Oferecer outro item (fora da lista)',
                variant: CasaButtonVariant.ghost,
                icon: Icons.add_rounded,
                onPressed: () {
                  notifier.startCustom();
                  onGoTo(1);
                },
              ),
            ],
          ),
        ),
        _FooterBar(
          children: [
            CasaButton(
              label: 'Sair',
              variant: CasaButtonVariant.secondary,
              onPressed: onExit,
            ),
            CasaButton(
              label: 'Continuar',
              onPressed: draft.items.isEmpty ? null : () => onGoTo(2),
            ),
          ],
        ),
      ],
    );
  }
}

class _NeedPickTile extends StatelessWidget {
  final DonationNeed need;
  final VoidCallback onTap;

  const _NeedPickTile({required this.need, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(need.title,
                        style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
                    Text(
                      'Restam ${need.remainingQty} ${need.unit} a cobrir · '
                      'prioridade ${need.priority.label.toLowerCase()}',
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final DonationItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _ItemTile({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = [
      '${item.quantity} ${item.unit}',
      if (item.hasExpiry && item.expiryDate != null)
        'validade ${_dateFormat.format(item.expiryDate!)}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description,
                    style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
                Text(details,
                    style:
                        AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                if (item.subjectToReview)
                  Text(
                    'Sujeito a avaliação da equipe',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.warning600),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar item',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Remover item',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger600),
          ),
        ],
      ),
    );
  }
}

// ─── Passo 2: quantidade e validade ──────────────────────────────────────────

class _StepItem extends ConsumerWidget {
  final void Function(int step, {bool animate}) onGoTo;

  const _StepItem({required this.onGoTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(donationDraftProvider);
    final editing = draft.editing;

    if (editing == null) {
      return CasaEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Nenhum item selecionado',
        description: 'Escolha o que será doado para informar quantidade e validade.',
        ctaLabel: 'Escolher item',
        onCta: () => onGoTo(0),
      );
    }

    // Chave por sessão de edição: recria os controllers ao trocar de item.
    return _ItemEditor(
      key: ValueKey('${draft.editingIndex}-${editing.needId}-${draft.items.length}'),
      onGoTo: onGoTo,
    );
  }
}

class _ItemEditor extends ConsumerStatefulWidget {
  final void Function(int step, {bool animate}) onGoTo;

  const _ItemEditor({super.key, required this.onGoTo});

  @override
  ConsumerState<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends ConsumerState<_ItemEditor> {
  late final TextEditingController _description;
  late final TextEditingController _expiry;

  static const _units = ['un', 'kg', 'L', 'pacote', 'caixa'];

  @override
  void initState() {
    super.initState();
    final item = ref.read(donationDraftProvider).editing;
    _description = TextEditingController(text: item?.description ?? '');
    _expiry = TextEditingController(
      text: item?.expiryDate == null ? '' : _dateFormat.format(item!.expiryDate!),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    _expiry.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry(DonationItem item) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.expiryDate ?? now.add(const Duration(days: 90)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365 * 10)),
      helpText: 'Validade do item',
    );
    if (picked == null) return;
    _expiry.text = _dateFormat.format(picked);
    ref
        .read(donationDraftProvider.notifier)
        .updateEditing(item.copyWith(expiryDate: picked));
  }

  void _add(DonationRules rules, DonationNeed? need) {
    final error = ref
        .read(donationDraftProvider.notifier)
        .commitEditing(rules, need: need);
    if (error != null) {
      showCasaSnackbar(context, message: error, isError: true);
      return;
    }
    showCasaSnackbar(context, message: 'Item adicionado à doação.', isSuccess: true);
    widget.onGoTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final draft = ref.watch(donationDraftProvider);
    final item = draft.editing;
    if (item == null) return const SizedBox.shrink();

    final notifier = ref.read(donationDraftProvider.notifier);
    final rules = ref.watch(donationRulesProvider).valueOrNull ?? const DonationRules();
    final need = ref.watch(editingNeedProvider);
    final fromNeed = item.needId != null;

    final validation = validateDonationItem(
      item,
      rules: rules,
      need: need,
      referenceDate: draft.window?.from,
    );

    final categories = ProductCategory.values
        .where((c) => !rules.isCategoryBlocked(c.name))
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (fromNeed)
                Text(
                  item.description,
                  style: AppTypography.headingMedium.copyWith(color: cs.onSurface),
                )
              else ...[
                CasaTextField(
                  label: 'O que você vai doar',
                  hint: 'Ex.: Arroz tipo 1, 5 kg',
                  controller: _description,
                  textInputAction: TextInputAction.next,
                  onChanged: (v) => notifier.updateEditing(item.copyWith(description: v)),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: categories.any((c) => c.name == item.category)
                      ? item.category
                      : null,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c.name,
                        child: Text(defaultCategoryLabel(c)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    notifier.updateEditing(item.copyWith(
                      category: value,
                      hasExpiry: categoryUsuallyPerishable(value),
                      clearExpiry: !categoryUsuallyPerishable(value),
                    ));
                    if (!categoryUsuallyPerishable(value)) _expiry.clear();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _units.contains(item.unit) ? item.unit : 'un',
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: [
                    for (final u in _units) DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (value) {
                    if (value != null) notifier.updateEditing(item.copyWith(unit: value));
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              Text('Quantidade (${item.unit})', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              QuantityStepper(
                value: item.quantity,
                onChanged: (v) => notifier.updateEditing(item.copyWith(quantity: v)),
              ),
              if (need != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Restam ${need.remainingQty} ${need.unit} a cobrir.',
                    style: AppTypography.bodySmall.copyWith(
                      color: item.quantity > need.remainingQty
                          ? AppColors.warning600
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('O item tem data de validade'),
                value: item.hasExpiry,
                onChanged: (value) {
                  notifier.updateEditing(item.copyWith(
                    hasExpiry: value,
                    clearExpiry: !value,
                  ));
                  if (!value) _expiry.clear();
                },
              ),
              if (item.hasExpiry) ...[
                const SizedBox(height: AppSpacing.sm),
                CasaTextField(
                  label: 'Validade',
                  hint: 'dd/mm/aaaa',
                  controller: _expiry,
                  readOnly: true,
                  onTap: () => _pickExpiry(item),
                  prefixIcon: const Icon(Icons.event_rounded, size: 20),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ShelfLifeHint(item: item, validation: validation),
              ],
              const SizedBox(height: AppSpacing.xl),

              Text('Estado do item', style: AppTypography.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final c in ItemCondition.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: item.condition == c,
                      onSelected: (_) =>
                          notifier.updateEditing(item.copyWith(condition: c)),
                    ),
                ],
              ),
            ],
          ),
        ),
        _FooterBar(
          children: [
            CasaButton(
              label: 'Cancelar item',
              variant: CasaButtonVariant.secondary,
              onPressed: () {
                notifier.cancelEditing();
                widget.onGoTo(0);
              },
            ),
            CasaButton(
              label: 'Adicionar à lista',
              onPressed: () => _add(rules, need),
            ),
          ],
        ),
      ],
    );
  }
}

/// Feedback em tempo real da regra RN-D03 (validade mínima).
class _ShelfLifeHint extends StatelessWidget {
  final DonationItem item;
  final ItemValidation validation;

  const _ShelfLifeHint({required this.item, required this.validation});

  @override
  Widget build(BuildContext context) {
    if (item.expiryDate == null) {
      return Text(
        'Mínimo recomendado: ${validation.minShelfLifeDays} dias.',
        style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
      );
    }
    if (!validation.isValid) {
      return Text(validation.error!,
          style: AppTypography.bodySmall.copyWith(color: AppColors.danger600));
    }
    final days = validation.daysToExpiry ?? 0;
    final min = validation.minShelfLifeDays;
    final below = days < min;
    return Text(
      below
          ? 'Validade de $days dias, abaixo do mínimo de $min. '
              'O item segue sujeito a avaliação da equipe.'
          : 'Mínimo recomendado: $min dias (você: $days dias — OK)',
      style: AppTypography.bodySmall.copyWith(
        color: below ? AppColors.warning600 : AppColors.success600,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─── Passo 3: entrega ────────────────────────────────────────────────────────

class _StepDelivery extends ConsumerStatefulWidget {
  final void Function(int step, {bool animate}) onGoTo;

  const _StepDelivery({required this.onGoTo});

  @override
  ConsumerState<_StepDelivery> createState() => _StepDeliveryState();
}

class _StepDeliveryState extends ConsumerState<_StepDelivery> {
  // Seleção de data/horas (UI); a janela resultante vai para o draft notifier.
  DateTime? _day;
  TimeOfDay? _start;
  TimeOfDay? _end;

  @override
  void initState() {
    super.initState();
    final window = ref.read(donationDraftProvider).window;
    if (window != null) {
      _day = DateTime(window.from.year, window.from.month, window.from.day);
      _start = TimeOfDay(hour: window.from.hour, minute: window.from.minute);
      _end = TimeOfDay(hour: window.to.hour, minute: window.to.minute);
    }
  }

  void _syncWindow() {
    final day = _day;
    final start = _start;
    final end = _end;
    final notifier = ref.read(donationDraftProvider.notifier);
    if (day == null || start == null || end == null) {
      notifier.setWindow(null);
      return;
    }
    notifier.setWindow(DonationWindow(
      from: DateTime(day.year, day.month, day.day, start.hour, start.minute),
      to: DateTime(day.year, day.month, day.day, end.hour, end.minute),
    ));
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Dia da entrega',
    );
    if (picked == null) return;
    setState(() => _day = picked);
    _syncWindow();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _start : _end) ??
          TimeOfDay(hour: isStart ? 9 : 11, minute: 0),
      helpText: isStart ? 'Horário inicial' : 'Horário final',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
    _syncWindow();
  }

  /// Mensagem de erro da janela (null quando válida ou ainda incompleta).
  String? _windowError(DonationWindow? window, DonationPoint? point) {
    if (window == null || point == null) return null;
    if (!window.to.isAfter(window.from)) {
      return 'O horário final deve ser depois do inicial.';
    }
    if (window.from.isBefore(DateTime.now())) {
      return 'A janela de entrega precisa ser no futuro.';
    }
    if (!point.acceptsWindow(window.from, window.to)) {
      return 'Fora do horário do ponto (${point.hoursSummary}).';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final draft = ref.watch(donationDraftProvider);
    final points = ref.watch(donationPointsProvider);
    final notifier = ref.read(donationDraftProvider.notifier);
    final point = draft.pointId == null
        ? null
        : ref.watch(donationPointByIdProvider(draft.pointId!));
    final windowError = _windowError(draft.window, point);
    final canContinue = point != null && draft.window != null && windowError == null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const CasaSectionHeader(title: 'Onde entregar'),
              const SizedBox(height: AppSpacing.sm),
              points.when(
                loading: () => const CasaCardSkeleton(),
                error: (_, __) => Text(
                  'Não foi possível carregar os pontos de recebimento.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.danger600),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Text(
                      'A ONG ainda não cadastrou um ponto de recebimento. '
                      'Tente novamente mais tarde.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: cs.onSurfaceVariant),
                    );
                  }
                  // Ponto único: já vem selecionado (simplificação do MVP, RF22).
                  if (list.length == 1 && draft.pointId == null) {
                    Future.microtask(() => notifier.setPoint(list.first.id));
                  }
                  return Column(
                    children: [
                      for (final p in list) ...[
                        _PointCard(
                          point: p,
                          selected: draft.pointId == p.id,
                          onTap: () => notifier.setPoint(p.id),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              const CasaSectionHeader(title: 'Quando entregar'),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.event_rounded),
                label: Text(
                  _day == null ? 'Escolher o dia' : _dateFormat.format(_day!),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isStart: true),
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(_start == null ? 'Das' : 'Das ${_start!.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(isStart: false),
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(_end == null ? 'Até' : 'Até ${_end!.format(context)}'),
                    ),
                  ),
                ],
              ),
              if (windowError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    windowError,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.danger600),
                  ),
                ),
            ],
          ),
        ),
        _FooterBar(
          children: [
            CasaButton(
              label: 'Voltar',
              variant: CasaButtonVariant.secondary,
              onPressed: () => widget.onGoTo(0),
            ),
            CasaButton(
              label: 'Continuar',
              onPressed: canContinue ? () => widget.onGoTo(3) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _PointCard extends StatelessWidget {
  final DonationPoint point;
  final bool selected;
  final VoidCallback onTap;

  const _PointCard({
    required this.point,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: 'Ponto de entrega ${point.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandPrimary600.withValues(alpha: 0.08)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? AppColors.brandPrimary600 : cs.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.brandPrimary600 : cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(point.name,
                        style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
                    Text(point.address,
                        style: AppTypography.bodyMedium
                            .copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(point.hoursSummary,
                        style: AppTypography.bodySmall
                            .copyWith(color: cs.onSurfaceVariant)),
                    if (point.instructions != null &&
                        point.instructions!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(point.instructions!,
                            style: AppTypography.bodySmall
                                .copyWith(color: cs.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Passo 4: revisão e confirmação ──────────────────────────────────────────

class _StepReview extends ConsumerWidget {
  final void Function(int step, {bool animate}) onGoTo;

  const _StepReview({required this.onGoTo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final draft = ref.watch(donationDraftProvider);
    final rules = ref.watch(donationRulesProvider).valueOrNull ?? const DonationRules();
    final submit = ref.watch(donationSubmitProvider);
    final point = draft.pointId == null
        ? null
        : ref.watch(donationPointByIdProvider(draft.pointId!));

    // Sucesso → vai para o acompanhamento; erro → mensagem em linguagem simples.
    ref.listen<AsyncValue<String?>>(donationSubmitProvider, (previous, next) {
      next.whenOrNull(
        data: (id) {
          if (id == null) return;
          showCasaSnackbar(
            context,
            message: 'Doação registrada! Acompanhe o status por aqui.',
            isSuccess: true,
          );
          ref.read(donationSubmitProvider.notifier).reset();
          context.go(AppRoutes.donorDonationDetailPath(id));
        },
        error: (error, _) {
          final message = error is DonationSubmitException
              ? error.message
              : mapAuthError(error,
                  fallback: 'Não foi possível registrar a doação. Seu rascunho foi mantido.');
          showCasaSnackbar(context, message: message, isError: true);
        },
      );
    });

    final errors = validateDonationDraft(
      items: draft.items,
      rules: rules,
      needsById: ref.watch(needsByIdProvider),
      point: point,
      windowFrom: draft.window?.from,
      windowTo: draft.window?.to,
      termsAccepted: draft.termsAccepted,
      openDonationsCount: ref.watch(openDonationsCountProvider),
    );
    final hasReview = draft.items.any((i) => i.subjectToReview);
    final window = draft.window;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              CasaSectionHeader(title: 'Resumo da doação', count: draft.items.length),
              const SizedBox(height: AppSpacing.sm),
              for (final item in draft.items) ...[
                _ReviewItemRow(item: item),
                const SizedBox(height: AppSpacing.xs),
              ],
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Entrega',
                        style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(point?.name ?? 'Ponto não escolhido',
                        style: AppTypography.bodyMedium),
                    if (point != null)
                      Text(point.address,
                          style: AppTypography.bodySmall
                              .copyWith(color: cs.onSurfaceVariant)),
                    if (window != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          '${_dateFormat.format(window.from)} · '
                          '${_timeLabel(window.from)} às ${_timeLabel(window.to)}',
                          style: AppTypography.bodyMedium
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasReview) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning600.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Text(
                    'Alguns itens têm validade abaixo do mínimo ou quantidade acima '
                    'do que falta. Eles seguem sujeitos à avaliação da equipe.',
                    style: AppTypography.bodySmall.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: draft.termsAccepted,
                onChanged: (v) => ref
                    .read(donationDraftProvider.notifier)
                    .setTermsAccepted(v ?? false),
                title: Text(
                  'Li e aceito os Termos de Uso e a Política de Privacidade (LGPD) '
                  'e confirmo que as informações são verdadeiras.',
                  style: AppTypography.bodySmall.copyWith(color: cs.onSurface),
                ),
              ),
              if (errors.isNotEmpty && draft.termsAccepted)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    errors.first,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.danger600),
                  ),
                ),
            ],
          ),
        ),
        _FooterBar(
          children: [
            CasaButton(
              label: 'Voltar',
              variant: CasaButtonVariant.secondary,
              onPressed: submit.isLoading ? null : () => onGoTo(2),
            ),
            CasaButton(
              label: 'Confirmar doação',
              icon: Icons.check_rounded,
              isLoading: submit.isLoading,
              onPressed: errors.isNotEmpty
                  ? null
                  : () => ref.read(donationSubmitProvider.notifier).submit(),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewItemRow extends StatelessWidget {
  final DonationItem item;

  const _ReviewItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final validity = item.hasExpiry && item.expiryDate != null
        ? ' · validade ${_dateFormat.format(item.expiryDate!)}'
        : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_outline_rounded,
              size: 18, color: AppColors.success600),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '${item.quantity} ${item.unit} · ${item.description}$validity',
            style: AppTypography.bodyMedium.copyWith(color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
