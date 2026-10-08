import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../data/datasources/stock_remote_datasource.dart';

final _keyApprovalCard = GlobalKey();
final _keyApproveBtn = GlobalKey();
final _keyRejectBtn = GlobalKey();
final _keyReasonBox = GlobalKey();

final _stockDatasourceProvider= Provider<StockRemoteDatasource>(
  (_) => StockRemoteDatasource(),
);

final pendingAdjustmentsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(_stockDatasourceProvider).watchPendingAdjustmentApprovals(),
);

class AdjustmentApprovalsPage extends ConsumerWidget {
  const AdjustmentApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null || !currentUser.canApproveAdjustments) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Column(children: [
        ModernProfileAppBar(
          title: 'Aprovações',
          subtitle: 'Acesso restrito',
          pageIcon: Icons.gavel_rounded,
          iconColor: const Color(0xFFEF4444),
          showBackButton: true,
          actions: [
            buildHelpButton(
              context: context,
              onPressed: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyApprovalCard,
                    title: 'Aprovação de Ajustes',
                    description: 'Ajustes de estoque realizados por colaboradores ficam pendentes de aprovação pelo administrador. Revise cada ajuste, verifique o motivo e aprove ou rejeite.',
                    icon: Icons.approval_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      'Ajustes incluem correções de quantidade e descarte por avaria',
                      'Verifique o motivo informado pelo colaborador',
                      'Aprovações ficam registradas no log de auditoria',
                      'Rejeições devolvem o estoque ao valor original',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const Expanded(child: CasaEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Acesso restrito',
            description: 'Apenas administradores podem aprovar ajustes.',
          )),
        ]),
      );
    }

    final requestsAsync = ref.watch(pendingAdjustmentsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Aprovações',
        subtitle: 'Solicitações pendentes',
        pageIcon: Icons.gavel_rounded,
        iconColor: const Color(0xFFFBBF24),
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyApprovalCard,
                  title: 'Card de Solicitação',
                  description: 'Cada card representa uma solicitação de ajuste de estoque feita por uma colaboradora não-admin. Mostra: produto afetado, quantidade ajustada (+ ou −), nome de quem solicitou e horário. Como admin, cabe a você revisar e decidir.',
                  icon: Icons.approval_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Badge amarelo no canto = quantidade ajustada',
                    '"+" indica entrada extra, "-" indica baixa',
                    'Solicitações ficam paradas até decisão do admin',
                    'Apenas admins veem esta tela (acesso restrito)',
                  ],
                ),
                TutorialStep(
                  key: _keyReasonBox,
                  title: 'Motivo da Solicitação',
                  description: 'A caixa cinza mostra o motivo informado pela colaboradora ao solicitar o ajuste. LEIA COM ATENÇÃO antes de decidir — motivos comuns incluem: avaria, validade, doação não registrada, erro de digitação, conferência de inventário.',
                  icon: Icons.notes_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Motivo "avaria" = produto danificado, descarte justificado',
                    'Motivo "inventário" = correção de divergência física',
                    'Motivos vagos: peça mais detalhes antes de aprovar',
                    'Use o log de auditoria para verificar histórico da pessoa',
                  ],
                ),
                TutorialStep(
                  key: _keyApproveBtn,
                  title: 'Aprovar Ajuste',
                  description: 'O botão azul "Aprovar" confirma o ajuste e aplica a mudança no estoque imediatamente. A operação fica registrada no log de auditoria com seu nome como aprovador. Use somente quando o motivo for legítimo e verificável.',
                  icon: Icons.check_circle_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Aprovação aplica IMEDIATAMENTE no estoque',
                    'Seu nome fica vinculado à decisão (auditoria)',
                    'Verifique fisicamente antes de aprovar grandes ajustes',
                    'Em dúvida, prefira rejeitar e pedir esclarecimento',
                  ],
                ),
                TutorialStep(
                  key: _keyRejectBtn,
                  title: 'Rejeitar Ajuste',
                  description: 'O botão "Rejeitar" cancela a solicitação sem alterar o estoque. A colaboradora é notificada e pode fazer nova solicitação com mais detalhes. Use quando o motivo não estiver claro ou a quantidade parecer suspeita.',
                  icon: Icons.cancel_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Rejeitar NÃO afeta o estoque (continua original)',
                    'A colaboradora pode reabrir a solicitação melhorada',
                    'Em casos suspeitos, abra um diálogo antes',
                    'Sempre aprovado/rejeitado fica em auditoria',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return const CasaEmptyState(
                icon: Icons.verified_rounded,
                title: 'Tudo em dia!',
                description: 'Nenhuma solicitação de ajuste aguardando aprovação.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final req = requests[i];
                final requestId = req['id'] as String;
                final productName = req['productName'] as String? ?? '-';
                final qty = (req['quantity'] as num?)?.toInt() ?? 0;
                final requestedByName = req['requestedByName'] as String? ?? '-';
                final reason = req['reason'] as String? ?? 'Sem motivo';

                final card = _AdjustmentCard(
                  productName: productName,
                  qty: qty,
                  requestedByName: requestedByName,
                  reason: reason,
                  cs: cs,
                  reasonKey: i == 0 ? _keyReasonBox : null,
                  approveKey: i == 0 ? _keyApproveBtn : null,
                  rejectKey: i == 0 ? _keyRejectBtn : null,
                  onApprove: () async {
                    await ref
                        .read(_stockDatasourceProvider)
                        .processAdjustmentApproval(
                          requestId: requestId,
                          approve: true,
                          approverId: currentUser.id,
                          approverName: currentUser.name,
                        );
                    if (context.mounted) {
                      showCasaSnackbar(context,
                          message: 'Ajuste aprovado!', isSuccess: true);
                    }
                  },
                  onReject: () async {
                    await ref
                        .read(_stockDatasourceProvider)
                        .processAdjustmentApproval(
                          requestId: requestId,
                          approve: false,
                          approverId: currentUser.id,
                          approverName: currentUser.name,
                        );
                    if (context.mounted) {
                      showCasaSnackbar(context,
                          message: 'Solicitação rejeitada.', isSuccess: true);
                    }
                  },
                );
                if (i == 0) {
                  return KeyedSubtree(key: _keyApprovalCard, child: card);
                }
                return card;
              },
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar',
            description: e.toString(),
          ),
        ),
      ),
      ]),
    );
  }
}

class _AdjustmentCard extends StatelessWidget {
  final String productName;
  final int qty;
  final String requestedByName;
  final String reason;
  final ColorScheme cs;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final Key? reasonKey;
  final Key? approveKey;
  final Key? rejectKey;

  const _AdjustmentCard({
    required this.productName,
    required this.qty,
    required this.requestedByName,
    required this.reason,
    required this.cs,
    required this.onApprove,
    required this.onReject,
    this.reasonKey,
    this.approveKey,
    this.rejectKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: AppColors.warning600, width: 3),
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppColors.warning600, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productName,
                        style: AppTypography.labelLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      'Por $requestedByName',
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  qty > 0 ? '+$qty' : '$qty',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.warning600,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            key: reasonKey,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Text(
              'Motivo: $reason',
              style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: approveKey,
                  child: CasaButton(
                    label: 'Aprovar',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: onApprove,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: KeyedSubtree(
                  key: rejectKey,
                  child: CasaButton(
                    label: 'Rejeitar',
                    variant: CasaButtonVariant.secondary,
                    icon: Icons.close_rounded,
                    onPressed: onReject,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
