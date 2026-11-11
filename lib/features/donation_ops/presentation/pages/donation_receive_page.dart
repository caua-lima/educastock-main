import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../donations/domain/entities/donation.dart';
import '../../../donations/domain/entities/donation_item.dart';
import '../../../donations/domain/entities/donation_status.dart';
import '../../../donations/presentation/controllers/donations_provider.dart';
import '../../../donations/presentation/widgets/donor_header.dart';
import '../../../donations/presentation/widgets/quantity_stepper.dart';
import '../../data/donation_ops_repository.dart';
import '../../domain/impact_message.dart';
import '../controllers/donation_ops_provider.dart';

/// S03 — Recebimento e impacto.
///
/// Quando a doação física chega, o estoquista confere item a item (quantidade e
/// validade), o sistema dá a entrada no estoque e a equipe registra o destino e a
/// mensagem de impacto que o doador verá no aplicativo dele.
///
/// Também serve para registrar o destino depois, em doações já recebidas.
class DonationReceivePage extends ConsumerStatefulWidget {
  final String donationId;
  const DonationReceivePage({super.key, required this.donationId});

  @override
  ConsumerState<DonationReceivePage> createState() => _DonationReceivePageState();
}

class _ItemState {
  int qty;
  DateTime? expiry;
  final TextEditingController note = TextEditingController();
  _ItemState({required this.qty, this.expiry});
}

class _DonationReceivePageState extends ConsumerState<DonationReceivePage> {
  final List<_ItemState> _items = [];
  final _impact = TextEditingController();
  String? _sector;
  DateTime _usedAt = DateTime.now();
  bool _impactEdited = false;
  bool _initialized = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final i in _items) {
      i.note.dispose();
    }
    _impact.dispose();
    super.dispose();
  }

  void _init(Donation d) {
    if (_initialized) return;
    _initialized = true;
    for (final item in d.items) {
      _items.add(_ItemState(qty: item.quantity, expiry: item.expiryDate));
    }
    final existing = d.impact;
    if (existing != null) {
      _sector = existing.sector;
      _impact.text = existing.message;
      _impactEdited = true;
      _usedAt = existing.usedAt ?? DateTime.now();
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.opsDonations);
    }
  }

  void _suggestImpact(Donation d) {
    final sector = _sector;
    if (sector == null || _impactEdited) return;
    _impact.text = buildImpactMessage(
      donorName: d.donorSnapshot.displayName,
      itemDescriptions: d.items.map((i) => i.description).toList(),
      sector: sector,
    );
  }

  String _errorText(Object e) => e is DonationOpsException
      ? e.message
      : 'Não foi possível concluir. Verifique a conexão e tente de novo.';

  Future<void> _pickDate({required DateTime initial, required ValueChanged<DateTime> onPicked, DateTime? first}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first ?? DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit(Donation d) async {
    final concluded = d.status.isConcluded;
    final sector = _sector;
    final message = _impact.text.trim();

    if (concluded && (sector == null || message.isEmpty)) {
      showCasaSnackbar(context,
          message: 'Escolha o setor de destino e escreva a mensagem de impacto.', isError: true);
      return;
    }
    if (!concluded && (sector == null) != message.isEmpty) {
      showCasaSnackbar(
        context,
        message: 'Para registrar o impacto agora, preencha o setor e a mensagem. Ou deixe os dois em branco e faça depois.',
        isError: true,
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final actions = ref.read(donationOpsActionsProvider.notifier);
      if (concluded) {
        await actions.saveImpact(donation: d, sector: sector!, message: message, usedAt: _usedAt);
      } else {
        await actions.receive(
          donation: d,
          received: [
            for (var i = 0; i < _items.length; i++)
              ReceivedItemInput(
                index: i,
                receivedQty: _items[i].qty,
                expiryDate: _items[i].expiry,
                note: _items[i].note.text,
              ),
          ],
          sector: sector,
          impactMessage: message,
          usedAt: _usedAt,
        );
      }
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: concluded
            ? 'Destino registrado. O doador recebeu o relatório de impacto.'
            : 'Recebimento confirmado e estoque atualizado.',
        isSuccess: true,
      );
      _back();
    } catch (e) {
      if (mounted) showCasaSnackbar(context, message: _errorText(e), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final donation = ref.watch(donationByIdProvider(widget.donationId));

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          DonorHeader(
            title: 'Recebimento e impacto',
            subtitle: donation.valueOrNull?.displayProtocol,
            onBack: _back,
          ),
          Expanded(
            child: donation.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [CasaCardSkeleton(), SizedBox(height: AppSpacing.md), CasaCardSkeleton()],
              ),
              error: (_, __) => CasaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Não foi possível carregar a doação',
                ctaLabel: 'Tentar de novo',
                onCta: () => ref.invalidate(donationByIdProvider(widget.donationId)),
              ),
              data: (d) {
                if (d == null) {
                  return const CasaEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Doação não encontrada',
                  );
                }
                final canReceive = d.status == DonationStatus.aprovada;
                final canDestinate = d.status.isConcluded;
                if (!canReceive && !canDestinate) {
                  return CasaEmptyState(
                    icon: Icons.info_outline_rounded,
                    title: d.status == DonationStatus.pendente
                        ? 'Esta doação ainda precisa ser aprovada'
                        : 'Esta doação está "${d.status.label}"',
                    description: 'O recebimento só vale para doações aprovadas.',
                    ctaLabel: d.status == DonationStatus.pendente ? 'Avaliar doação' : null,
                    onCta: d.status == DonationStatus.pendente
                        ? () => context.pushReplacement(AppRoutes.opsDonationPath(d.id))
                        : null,
                  );
                }
                _init(d);
                return _buildForm(context, d, canReceive);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, Donation d, bool receiving) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.success600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: AppColors.success600.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volunteer_activism_rounded, color: AppColors.success600),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '${d.donorSnapshot.displayName} · ${d.resumoQuantidade}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (receiving) ...[
                Text('1. Conferir os itens',
                    style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Ajuste a quantidade que realmente chegou. Se for diferente do prometido, explique no campo de nota.',
                  style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < d.items.length; i++) _itemCard(context, d.items[i], _items[i], fmt),
                const SizedBox(height: AppSpacing.lg),
              ] else
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text(
                    'Itens já recebidos e lançados no estoque. Falta registrar para onde foram.',
                    style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              Text(receiving ? '2. Destino e impacto (opcional agora)' : 'Destino e impacto',
                  style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'A mensagem abaixo é enviada ao aplicativo do doador, junto do relatório de impacto.',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _sector,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Setor de destino',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
                ),
                items: [
                  for (final s in kDonationSectors) DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (value) => setState(() {
                  _sector = value;
                  _suggestImpact(d);
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _impact,
                minLines: 4,
                maxLines: 7,
                maxLength: 600,
                onChanged: (_) => _impactEdited = true,
                decoration: InputDecoration(
                  labelText: 'Mensagem de impacto',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _pickDate(
                  initial: _usedAt,
                  onPicked: (date) => setState(() => _usedAt = date),
                ),
                icon: const Icon(Icons.event_rounded),
                label: Text('Data de utilização: ${fmt.format(_usedAt)}'),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md + MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
          ),
          child: CasaButton(
            label: receiving ? 'Confirmar recebimento' : 'Salvar e notificar o doador',
            icon: receiving ? Icons.move_to_inbox_rounded : Icons.send_rounded,
            isLoading: _busy,
            onPressed: _busy ? null : () => _submit(d),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(BuildContext context, DonationItem item, _ItemState state, DateFormat fmt) {
    final cs = Theme.of(context).colorScheme;
    final diverges = state.qty != item.quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: diverges
              ? AppColors.warning600.withValues(alpha: 0.6)
              : cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.description,
              style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
          Text('Prometido: ${item.quantity} ${item.unit}',
              style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          QuantityStepper(
            value: state.qty,
            min: 0,
            max: item.quantity * 2 + 10,
            onChanged: (value) => setState(() => state.qty = value),
          ),
          if (item.hasExpiry && state.qty > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _pickDate(
                initial: state.expiry ?? DateTime.now().add(const Duration(days: 30)),
                first: DateTime.now().subtract(const Duration(days: 1)),
                onPicked: (date) => setState(() => state.expiry = date),
              ),
              icon: const Icon(Icons.event_available_rounded),
              label: Text(state.expiry == null
                  ? 'Informar a validade'
                  : 'Validade: ${fmt.format(state.expiry!)}'),
            ),
          ],
          if (diverges) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: state.note,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Nota da divergência (obrigatória)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.input)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
