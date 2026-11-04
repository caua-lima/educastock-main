import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../help/ajuda_telas.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'casa_button.dart';
import 'casa_tutorial.dart';

class HelpTip {
  final IconData icon;
  final String title;
  final String description;
  const HelpTip({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Pergunta frequente da ajuda (abre/fecha).
class HelpFaq {
  final String pergunta;
  final String resposta;
  const HelpFaq({required this.pergunta, required this.resposta});
}

/// Ajuda curta da tela: finalidade, ações principais e dúvidas frequentes.
/// Com [onVerTutorial], oferece "Ver tutorial" (ou "Rever tutorial", se a
/// pessoa já concluiu o tutorial [tutorialId]) — sem obrigar o passeio.
Future<void> showCasaHelpModal({
  required BuildContext context,
  required String pageTitle,
  required String pageDescription,
  required List<HelpTip> tips,
  List<HelpFaq> faq = const [],
  VoidCallback? onVerTutorial,
  String? tutorialId,
  IconData headerIcon = Icons.help_outline_rounded,
  Color? accentColor,
}) async {
  final jaViu = tutorialId != null && await TutorialProgresso.concluido(tutorialId);
  if (!context.mounted) return;
  final querTutorial = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CasaHelpModalSheet(
      pageTitle: pageTitle,
      pageDescription: pageDescription,
      tips: tips,
      faq: faq,
      temTutorial: onVerTutorial != null,
      jaViuTutorial: jaViu,
      headerIcon: headerIcon,
      accentColor: accentColor,
    ),
  );
  // O tutorial começa depois de a folha fechar (o destaque precisa da tela livre).
  if (querTutorial == true) onVerTutorial?.call();
}

class _CasaHelpModalSheet extends StatelessWidget {
  final String pageTitle;
  final String pageDescription;
  final List<HelpTip> tips;
  final List<HelpFaq> faq;
  final bool temTutorial;
  final bool jaViuTutorial;
  final IconData headerIcon;
  final Color? accentColor;

  const _CasaHelpModalSheet({
    required this.pageTitle,
    required this.pageDescription,
    required this.tips,
    required this.faq,
    required this.temTutorial,
    required this.jaViuTutorial,
    required this.headerIcon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;
    final maxH = MediaQuery.sizeOf(context).height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH, maxWidth: 640),
      child: Material(
        color: cs.surface,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            // Conteúdo rolável; os botões ficam fixos embaixo.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(headerIcon, color: accent, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Ajuda: $pageTitle',
                              style: AppTypography.headingMedium.copyWith(color: cs.onSurface),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      pageDescription,
                      style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (tips.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _Rotulo('O que dá para fazer aqui', cs: cs),
                      const SizedBox(height: AppSpacing.sm),
                      for (final tip in tips)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(AppRadius.small),
                                ),
                                child: Icon(tip.icon, color: accent, size: 20),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tip.title,
                                      style: AppTypography.labelLarge.copyWith(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tip.description,
                                      style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (faq.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _Rotulo('Dúvidas frequentes', cs: cs),
                      const SizedBox(height: AppSpacing.xs),
                      for (final f in faq)
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            expandedAlignment: Alignment.centerLeft,
                            title: Text(f.pergunta,
                                style: AppTypography.labelLarge.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600)),
                            children: [
                              Text(f.resposta, style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Divider(color: cs.outlineVariant, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: temTutorial
                  ? Wrap(
                      alignment: WrapAlignment.end,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                          child: const Text('Fechar'),
                        ),
                        FilledButton.icon(
                          autofocus: true,
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.school_rounded, size: 18),
                          label: Text(jaViuTutorial ? 'Rever tutorial' : 'Ver tutorial'),
                          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                        ),
                      ],
                    )
                  : CasaButton(
                      label: 'Entendido',
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  final String texto;
  final ColorScheme cs;
  const _Rotulo(this.texto, {required this.cs});
  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: AppTypography.labelMedium.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
      );
}

/// Abre a ajuda curta da tela atual (pela rota) e, a partir dela, o tutorial.
/// Sem ajuda cadastrada para a rota, abre o tutorial direto.
Future<void> abrirAjudaDaTela(BuildContext context, {VoidCallback? iniciarTutorial}) async {
  String? caminho;
  try {
    caminho = GoRouterState.of(context).uri.path;
  } catch (_) {
    caminho = null; // fora do roteador (ex.: testes de componente)
  }
  final ajuda = caminho == null ? null : ajudaDaRota(caminho);
  if (ajuda == null) {
    iniciarTutorial?.call();
    return;
  }
  await showCasaHelpModal(
    context: context,
    pageTitle: ajuda.titulo,
    pageDescription: ajuda.finalidade,
    tips: ajuda.acoes,
    faq: ajuda.duvidas,
    headerIcon: ajuda.icone,
    onVerTutorial: iniciarTutorial,
    tutorialId: caminho,
  );
}

/// Botão "Ajuda" padronizado para cabeçalhos escuros: alvo de 48, nome
/// acessível e dica. Abre a ajuda curta da tela; o tutorial ([onPressed]) é
/// oferecido dentro dela ("Ver tutorial").
Widget buildHelpButton({
  required BuildContext context,
  required VoidCallback onPressed,
}) {
  return _BotaoAjuda(onTutorial: onPressed);
}

class _BotaoAjuda extends StatelessWidget {
  final VoidCallback onTutorial;
  const _BotaoAjuda({required this.onTutorial});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Tooltip(
        message: 'Ajuda',
        child: Semantics(
          button: true,
          label: 'Ajuda desta tela',
          excludeSemantics: true,
          child: Material(
            color: Colors.white.withValues(alpha: 0.14),
            shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.28))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => abrirAjudaDaTela(context, iniciarTutorial: onTutorial),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.help_outline_rounded, size: 22, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
