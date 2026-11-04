import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global flag — true enquanto um tutorial está aberto (atalhos globais de
/// teclado da navegação ficam em pausa).
final ValueNotifier<bool> tutorialActiveNotifier = ValueNotifier<bool>(false);

/// Preferência de posição do texto em relação ao destaque. É só uma
/// preferência: o painel vai para o lado com espaço suficiente.
enum ContentAlign { top, bottom, left, right, custom }

/// Forma do destaque em volta do componente.
// ignore: constant_identifier_names
enum ShapeLightFocus { Circle, RRect }

class TutorialStep {
  final GlobalKey key;
  final String title;
  final String description;
  final IconData icon;
  final ShapeLightFocus shape;
  final ContentAlign align;
  final double verticalOffset;
  final double paddingFocus;
  final List<String> hints;

  const TutorialStep({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    this.shape = ShapeLightFocus.RRect,
    this.align = ContentAlign.bottom,
    this.verticalOffset = 0,
    this.paddingFocus = 8.0,
    this.hints = const [],
  });
}

/// Como o tutorial terminou.
enum FimTutorial { concluido, pulado }

// ─── Progresso por usuário/versão ────────────────────────────────────────────

/// Guarda quais tutoriais cada pessoa já concluiu (por versão do conteúdo),
/// só para oferecer "Rever tutorial" — nunca impede abrir de novo.
class TutorialProgresso {
  TutorialProgresso._();

  /// Conta atual (definida pela navegação ao entrar). Sem conta: 'anonimo'.
  static String usuarioAtual = 'anonimo';

  /// Versão do conteúdo dos tutoriais. Aumente quando os passos mudarem muito.
  static const versao = 2;

  static String _chave(String id) => 'tutorial.$id.v$versao.$usuarioAtual';

  static Future<bool> concluido(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_chave(id)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> marcarConcluido(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_chave(id), true);
    } catch (_) {/* sem armazenamento: só não lembra */}
  }
}

/// Abre o tutorial de passos.
///
/// - **Concluir** (último passo) chama [onFinish] exatamente uma vez e marca
///   o tutorial [id] como concluído para a conta atual;
/// - **Pular**, Escape e o botão Voltar do aparelho cancelam e chamam
///   [onSkip] (nunca [onFinish]);
/// - em qualquer saída (inclusive troca de rota ou descarte) o destaque, o
///   estado global e o foco são limpos uma única vez, e o foco volta para quem
///   abriu o tutorial.
///
/// O tutorial é uma rota modal: o leitor de tela não lê nem aciona os
/// controles do fundo enquanto ele está aberto.
Future<FimTutorial?> showCasaTutorial({
  required BuildContext context,
  required List<TutorialStep> steps,
  VoidCallback? onFinish,
  VoidCallback? onSkip,
  String? id,
}) async {
  if (steps.isEmpty || !context.mounted) return null;
  // Um tutorial por vez.
  if (tutorialActiveNotifier.value) return null;
  tutorialActiveNotifier.value = true;
  FimTutorial? fim;
  try {
    fim = await Navigator.of(context, rootNavigator: true).push<FimTutorial>(
      _TutorialRoute(steps: steps),
    );
  } finally {
    tutorialActiveNotifier.value = false;
  }
  if (fim == FimTutorial.concluido) {
    if (id != null) unawaited(TutorialProgresso.marcarConcluido(id));
    onFinish?.call();
  } else {
    onSkip?.call();
  }
  return fim ?? FimTutorial.pulado;
}

// ─── Rota modal ──────────────────────────────────────────────────────────────

class _TutorialRoute extends PopupRoute<FimTutorial> {
  final List<TutorialStep> steps;
  _TutorialRoute({required this.steps});

  @override
  Color? get barrierColor => null; // o próprio overlay desenha o escurecimento

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => 'Tutorial';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _TutorialOverlay(steps: steps);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}

class _AvancarIntent extends Intent {
  const _AvancarIntent();
}

class _VoltarIntent extends Intent {
  const _VoltarIntent();
}

class _PularIntent extends Intent {
  const _PularIntent();
}

class _TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  const _TutorialOverlay({required this.steps});

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay> {
  int _indice = 0;
  Rect? _alvo; // retângulo do componente destacado (coordenadas da tela)
  bool _preparando = true;
  bool _encerrado = false;
  int _geracao = 0; // descarta preparação de passo antigo
  final _focoPrincipal = FocusNode(debugLabel: 'tutorial-principal');

  List<TutorialStep> get _passos => widget.steps;
  TutorialStep get _passo => _passos[_indice];
  bool get _ultimo => _indice == _passos.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _irPara(0));
    _agendarMedida();
  }

  @override
  void dispose() {
    _geracao++;
    _focoPrincipal.dispose();
    super.dispose();
  }

  /// Mede o alvo depois de cada quadro que já acontece (rolagem, redimensionar,
  /// teclado, rotação) — sem pedir quadros novos: parado, não gasta nada.
  void _agendarMedida() {
    if (!mounted || _encerrado) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _medirAlvo();
      _agendarMedida();
    });
  }

  void _medirAlvo() {
    if (!mounted || _preparando || _encerrado) return;
    final r = _retanguloDe(_passo.key);
    if (r != _alvo) setState(() => _alvo = r);
  }

  /// Retângulo do componente, ou null se não está na tela.
  Rect? _retanguloDe(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null || !ctx.mounted) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize || ro.size.isEmpty) return null;
    final origem = ro.localToGlobal(Offset.zero);
    final r = origem & ro.size;
    final tela = Offset.zero & MediaQuery.sizeOf(context);
    final visivel = r.intersect(tela);
    if (visivel.isEmpty || visivel.width <= 0 || visivel.height <= 0) return null;
    return r;
  }

  /// Prepara o passo [i]: rola até o alvo (sem esperas fixas longas: no máximo
  /// alguns quadros para listas preguiçosas montarem) e mede o retângulo.
  Future<void> _irPara(int i) async {
    if (_encerrado) return;
    final geracao = ++_geracao;
    setState(() {
      _indice = i;
      _preparando = true;
    });
    final reduzirMovimento = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final key = _passos[i].key;
    // Alvo ainda não montado (lista preguiçosa / layout): espera até 6 quadros.
    for (var q = 0; q < 6 && key.currentContext == null; q++) {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted || geracao != _geracao) return;
    }
    final ctx = key.currentContext;
    if (ctx != null && ctx.mounted) {
      try {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.3,
          duration: reduzirMovimento ? Duration.zero : const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      } catch (_) {/* sem rolagem ancestral */}
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!mounted || geracao != _geracao) return;
    setState(() {
      _alvo = _retanguloDe(key);
      _preparando = false;
    });
    // Foco no botão principal e anúncio do passo para leitor de tela.
    _focoPrincipal.requestFocus();
    final view = View.maybeOf(context);
    if (view != null) {
      SemanticsService.sendAnnouncement(
        view,
        'Passo ${i + 1} de ${_passos.length}: ${_passos[i].title}',
        Directionality.of(context),
      );
    }
  }

  void _encerrar(FimTutorial fim) {
    if (_encerrado) return;
    _encerrado = true;
    _geracao++;
    Navigator.of(context).pop(fim);
  }

  void _avancar() {
    if (_preparando || _encerrado) return;
    if (_ultimo) {
      _encerrar(FimTutorial.concluido);
    } else {
      _irPara(_indice + 1);
    }
  }

  void _voltar() {
    if (_preparando || _encerrado || _indice == 0) return;
    _irPara(_indice - 1);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final cs = Theme.of(context).colorScheme;
    final alvo = _preparando ? null : _alvo;
    final destaque = alvo?.inflate(_passo.paddingFocus);

    return PopScope(
      canPop: false,
      // Voltar do aparelho / Escape = pular.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _encerrar(FimTutorial.pulado);
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): _PularIntent(),
          SingleActivator(LogicalKeyboardKey.arrowRight): _AvancarIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _VoltarIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _PularIntent: CallbackAction<_PularIntent>(onInvoke: (_) => _encerrar(FimTutorial.pulado)),
            _AvancarIntent: CallbackAction<_AvancarIntent>(onInvoke: (_) => _avancar()),
            _VoltarIntent: CallbackAction<_VoltarIntent>(onInvoke: (_) => _voltar()),
          },
          child: FocusScope(
            autofocus: true,
            child: Stack(
              children: [
                // Escurecimento com recorte no componente destacado.
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {}, // toques fora do painel não acionam o fundo
                      child: CustomPaint(
                        painter: _DestaquePainter(
                          alvo: destaque,
                          circulo: _passo.shape == ShapeLightFocus.Circle,
                          cor: Colors.black.withValues(alpha: 0.62),
                          borda: cs.primaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!_preparando)
                  _PainelPosicionado(
                    alvo: destaque,
                    tela: mq.size,
                    padding: mq.padding + EdgeInsets.only(bottom: mq.viewInsets.bottom),
                    preferenciaAcima: _passo.align == ContentAlign.top,
                    child: _PainelPasso(
                      passo: _passo,
                      indice: _indice,
                      total: _passos.length,
                      semDestaque: alvo == null,
                      ultimo: _ultimo,
                      focoPrincipal: _focoPrincipal,
                      onVoltar: _indice > 0 ? _voltar : null,
                      onAvancar: _avancar,
                      onPular: () => _encerrar(FimTutorial.pulado),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Posicionamento do painel ────────────────────────────────────────────────

/// Põe o painel no lado com mais espaço livre (acima ou abaixo do destaque).
/// Sem espaço suficiente (celular deitado, fonte grande, teclado aberto), o
/// painel fica compacto, encostado na borda oposta ao destaque, com rolagem
/// interna — os botões continuam sempre à vista.
class _PainelPosicionado extends StatelessWidget {
  final Rect? alvo;
  final Size tela;
  final EdgeInsets padding;
  final bool preferenciaAcima;
  final Widget child;

  const _PainelPosicionado({
    required this.alvo,
    required this.tela,
    required this.padding,
    required this.preferenciaAcima,
    required this.child,
  });

  static const _margem = 12.0;
  static const _alturaMinimaConfortavel = 220.0;

  @override
  Widget build(BuildContext context) {
    final largura = (tela.width - 2 * _margem).clamp(0.0, 480.0);
    final esquerda = (tela.width - largura) / 2;
    final topoUtil = padding.top + _margem;
    final baseUtil = tela.height - padding.bottom - _margem;

    if (alvo == null) {
      // Sem componente na tela: painel no centro.
      return Positioned(
        left: esquerda,
        width: largura,
        top: topoUtil,
        bottom: tela.height - baseUtil,
        child: Center(child: child),
      );
    }

    final espacoAcima = alvo!.top - topoUtil - _margem;
    final espacoAbaixo = baseUtil - alvo!.bottom - _margem;
    // Com fonte ampliada o painel precisa de mais altura para caber cabeçalho,
    // um pouco de texto e os botões.
    final minimo = MediaQuery.textScalerOf(context).scale(_alturaMinimaConfortavel);
    final cabeAbaixo = espacoAbaixo >= minimo;
    final cabeAcima = espacoAcima >= minimo;
    final abaixo = cabeAbaixo && cabeAcima
        ? !preferenciaAcima || espacoAbaixo > espacoAcima * 1.6
        : cabeAbaixo || (!cabeAcima && espacoAbaixo >= espacoAcima);

    if (abaixo && cabeAbaixo) {
      return Positioned(
        left: esquerda,
        width: largura,
        top: alvo!.bottom + _margem,
        bottom: tela.height - baseUtil,
        child: Align(alignment: Alignment.topCenter, child: child),
      );
    }
    if (!abaixo && cabeAcima) {
      return Positioned(
        left: esquerda,
        width: largura,
        top: topoUtil,
        bottom: tela.height - (alvo!.top - _margem),
        child: Align(alignment: Alignment.bottomCenter, child: child),
      );
    }
    // Compacto: encosta na borda oposta ao centro do destaque. O painel só
    // cresce o que o conteúdo pede; se a tela é baixa (deitada, fonte grande),
    // pode usar a altura útil toda — o texto rola e os botões ficam à vista.
    final destaqueNaMetadeDeCima = alvo!.center.dy < tela.height / 2;
    final alturaMax = (baseUtil - topoUtil).clamp(120.0, double.infinity);
    return Positioned(
      left: esquerda,
      width: largura,
      top: destaqueNaMetadeDeCima ? null : topoUtil,
      bottom: destaqueNaMetadeDeCima ? tela.height - baseUtil : null,
      child: ConstrainedBox(constraints: BoxConstraints(maxHeight: alturaMax), child: child),
    );
  }
}

// ─── Painel do passo ─────────────────────────────────────────────────────────

class _PainelPasso extends StatelessWidget {
  final TutorialStep passo;
  final int indice;
  final int total;
  final bool semDestaque;
  final bool ultimo;
  final FocusNode focoPrincipal;
  final VoidCallback? onVoltar;
  final VoidCallback onAvancar;
  final VoidCallback onPular;

  const _PainelPasso({
    required this.passo,
    required this.indice,
    required this.total,
    required this.semDestaque,
    required this.ultimo,
    required this.focoPrincipal,
    required this.onVoltar,
    required this.onAvancar,
    required this.onPular,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Tutorial, passo ${indice + 1} de $total',
      child: Material(
        color: cs.surface,
        elevation: 8,
        shadowColor: Colors.black54,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho: passo atual e Pular (sempre visível).
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(passo.icon, size: 20, color: cs.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Passo ${indice + 1} de $total',
                            style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: onPular,
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: const Text('Pular tutorial'),
                    ),
                  ],
                ),
              ),
              // Barra de progresso (não depende só de cor: há o texto acima).
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (indice + 1) / total,
                    minHeight: 4,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ),
              ),
              // Conteúdo com rolagem própria.
              Flexible(
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: Text(
                            passo.title,
                            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(passo.description, style: tt.bodyLarge?.copyWith(color: cs.onSurface, height: 1.45)),
                        if (semDestaque) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Esta parte não está visível agora (pode depender de dados ou permissão).',
                            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                          ),
                        ],
                        if (passo.hints.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final h in passo.hints)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(Icons.lightbulb_outline_rounded, size: 18, color: cs.primary),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(h, style: tt.bodyMedium?.copyWith(color: cs.onSurface))),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              // Ações (sempre visíveis).
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onVoltar != null)
                      OutlinedButton.icon(
                        onPressed: onVoltar,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Voltar'),
                        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                      ),
                    FilledButton.icon(
                      focusNode: focoPrincipal,
                      onPressed: onAvancar,
                      icon: Icon(ultimo ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 18),
                      label: Text(ultimo ? 'Concluir' : 'Próximo'),
                      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
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

// ─── Desenho do escurecimento com recorte ────────────────────────────────────

class _DestaquePainter extends CustomPainter {
  final Rect? alvo;
  final bool circulo;
  final Color cor;
  final Color borda;
  const _DestaquePainter({required this.alvo, required this.circulo, required this.cor, required this.borda});

  @override
  void paint(Canvas canvas, Size size) {
    final tudo = Path()..addRect(Offset.zero & size);
    if (alvo == null) {
      canvas.drawPath(tudo, Paint()..color = cor);
      return;
    }
    final recorte = Path();
    if (circulo) {
      recorte.addOval(Rect.fromCircle(center: alvo!.center, radius: alvo!.longestSide / 2));
    } else {
      recorte.addRRect(RRect.fromRectAndRadius(alvo!, const Radius.circular(12)));
    }
    canvas.drawPath(Path.combine(PathOperation.difference, tudo, recorte), Paint()..color = cor);
    // Contorno do destaque (contraste com qualquer fundo).
    canvas.drawPath(
      recorte,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = borda,
    );
  }

  @override
  bool shouldRepaint(_DestaquePainter old) =>
      old.alvo != alvo || old.circulo != circulo || old.cor != cor || old.borda != borda;
}
