import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/donation_status.dart';

enum _StepState { done, current, pending, error }

class _TimelineStep {
  final String label;
  final String hint;
  final _StepState state;
  const _TimelineStep(this.label, this.hint, this.state);
}

/// Linha do tempo do status da doação (D09):
/// Pendente → Aprovada → Recebida, ou o desfecho de encerramento.
class DonationTimeline extends StatelessWidget {
  final DonationStatus status;

  const DonationTimeline({super.key, required this.status});

  List<_TimelineStep> get _steps {
    const waiting = 'Aguardando';
    switch (status) {
      case DonationStatus.pendente:
        return const [
          _TimelineStep('Pendente', 'A equipe vai avaliar sua doação', _StepState.current),
          _TimelineStep('Aprovada', waiting, _StepState.pending),
          _TimelineStep('Recebida', waiting, _StepState.pending),
        ];
      case DonationStatus.aprovada:
        return const [
          _TimelineStep('Pendente', 'Registrada', _StepState.done),
          _TimelineStep('Aprovada', 'Entregue no ponto e horário combinados', _StepState.current),
          _TimelineStep('Recebida', waiting, _StepState.pending),
        ];
      case DonationStatus.recebida:
        return const [
          _TimelineStep('Pendente', 'Registrada', _StepState.done),
          _TimelineStep('Aprovada', 'Confirmada pela equipe', _StepState.done),
          _TimelineStep('Recebida', 'Obrigado por ajudar!', _StepState.done),
        ];
      case DonationStatus.recebidaParcial:
        return const [
          _TimelineStep('Pendente', 'Registrada', _StepState.done),
          _TimelineStep('Aprovada', 'Confirmada pela equipe', _StepState.done),
          _TimelineStep('Recebida parcialmente', 'Parte dos itens foi aceita', _StepState.done),
        ];
      case DonationStatus.recusada:
        return const [
          _TimelineStep('Pendente', 'Registrada', _StepState.done),
          _TimelineStep('Recusada', 'A equipe não pôde aceitar esta doação', _StepState.error),
        ];
      case DonationStatus.cancelada:
        return const [
          _TimelineStep('Pendente', 'Registrada', _StepState.done),
          _TimelineStep('Cancelada', 'A doação foi cancelada', _StepState.error),
        ];
      case DonationStatus.expirada:
        return const [
          _TimelineStep('Pendente', 'Registrada', _StepState.done),
          _TimelineStep('Expirada', 'O prazo terminou sem entrega', _StepState.error),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = _steps;

    return Semantics(
      label: 'Status da doação: ${status.label}',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        _Dot(state: steps[i].state),
                        if (i < steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: steps[i].state == _StepState.done
                                  ? AppColors.success600
                                  : cs.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].label,
                            style: AppTypography.labelLarge.copyWith(
                              color: steps[i].state == _StepState.error
                                  ? AppColors.danger600
                                  : cs.onSurface,
                              fontWeight: steps[i].state == _StepState.pending
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                          Text(
                            steps[i].hint,
                            style: AppTypography.bodySmall
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
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

class _Dot extends StatelessWidget {
  final _StepState state;

  const _Dot({required this.state});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (state) {
      case _StepState.done:
        return const Icon(Icons.check_circle_rounded,
            size: 24, color: AppColors.success600);
      case _StepState.current:
        return const Icon(Icons.radio_button_checked_rounded,
            size: 24, color: AppColors.brandPrimary600);
      case _StepState.error:
        return const Icon(Icons.cancel_rounded, size: 24, color: AppColors.danger600);
      case _StepState.pending:
        return Icon(Icons.radio_button_unchecked_rounded,
            size: 24, color: cs.outlineVariant);
    }
  }
}
