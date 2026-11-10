import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/design_system/design_system.dart';
import '../../data/scan_history_repository.dart';
import '../../domain/codigo_barras.dart';
import '../../domain/falha_camera.dart';
import '../controllers/scanner_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../donation_ops/presentation/controllers/donation_ops_provider.dart';
// Interop de scan direto para web (polyfill BarcodeDetector via JS bridge)
import 'web_scan_interop_stub.dart'
    if (dart.library.html) 'web_scan_interop.dart';
// Análise de imagem estática via ML Kit (Android/iOS) — stub no web
import 'barcode_image_analyzer_stub.dart'
    if (dart.library.io) 'barcode_image_analyzer_native.dart';

// ── Constantes do scanner ────────────────────────────────────────────────────
const _kScanBoxSize = 260.0;
// 0.25 ≈ ~2.75× — zoom mais baixo facilita enquadrar o código e melhora detecção
const _kInitialZoomMobile = 0.25;
const _kZoomStep          = 0.1;
// Máximo de tentativas ao escanear por foto
const _kMaxPhotoAttempts = 3;
// Tentativas automáticas de abrir a câmera (iOS Safari libera o stream com atraso)
const _kTentativasCamera = 3;

// ── Página ───────────────────────────────────────────────────────────────────
class ScannerPage extends ConsumerStatefulWidget {
  /// Tempo máximo para a câmera abrir. Passado o limite, a tela explica e
  /// oferece Tentar novamente / Digitar código (em vez de "Abrindo…" para sempre).
  final Duration limiteCamera;
  const ScannerPage({super.key, this.limiteCamera = const Duration(seconds: 30)});
  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

/// Ciclo da leitura:
/// - um único caminho de aceitação ([_aceitarCodigo]) para câmera, foto e
///   digitação: valida, pausa a captura, confirma (se veio da câmera/foto),
///   registra no histórico uma vez e abre a revisão com a rota codificada;
/// - a captura fica pausada durante confirmação, digitação, revisão e com o
///   app/aba em segundo plano, e é retomada uma vez ao voltar;
/// - cada início de câmera tem um número ([_cicloCamera]); um início antigo
///   (tentativa atrasada, troca de tela) não liga a câmera depois.
class _ScannerPageState extends ConsumerState<ScannerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  // Camera ─────────────────────────────────────────────────────────────────
  // Nativo (Android + iOS): noDuplicates — o SDK nativo gerencia deduplicação.
  // Web: DetectionSpeed.normal — o loop ZXing customizado tem guarda própria.
  // formats: limita aos formatos usados em produtos de ONG brasileira, o que
  // reduz o trabalho do ML Kit/Vision a cada quadro.
  final _camera = MobileScannerController(
    detectionSpeed: kIsWeb ? DetectionSpeed.normal : DetectionSpeed.noDuplicates,
    returnImage: false,
    autoStart: false,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.qrCode,
      BarcodeFormat.itf,
      BarcodeFormat.dataMatrix,
    ],
  );

  /// Um código está sendo confirmado/revisado: nenhuma outra leitura é aceita.
  bool   _navigating    = false;
  /// Captura pausada por modal/teclado (digitação, ajuda).
  bool   _pausadoPorModal = false;
  /// App/aba em segundo plano.
  bool   _emSegundoPlano = false;
  int    _cicloCamera   = 0;
  bool   _zoomSupported = true;
  // Web: zoom digital 1.5× — o leitor recorta o quadro na mesma proporção.
  double _zoom          = kIsWeb ? 1.5 : _kInitialZoomMobile;
  bool   _detected      = false;
  bool   _iniciandoCamera = false;

  // ── Diagnóstico técnico (fora da interface comum) ─────────────────────
  // Visível só com --dart-define=SCANNER_DIAGNOSTICO=true ou após tocar e segurar o título.
  bool _diagnosticoLiberado = const bool.fromEnvironment('SCANNER_DIAGNOSTICO');
  bool _showDebugLog      = false;
  FalhaCamera? _falhaCamera;
  bool _scanningFromPhoto = false;
  int  _photoAttempt      = 0;   // tentativa atual da varredura por foto
  int  _frameCount        = 0;
  Timer? _heartbeat;
  Timer? _webScanTimer;
  Timer? _debounce;              // evita duplicatas em DetectionSpeed.normal
  Timer? _flashDeteccao;
  bool   _webScanBusy = false;  // evita scans web sobrepostos
  final List<_LogEntry> _logs = [];

  void _log(String msg, {bool isError = false}) {
    final now = DateTime.now();
    final ts  = '${now.hour.toString().padLeft(2,'0')}:'
                '${now.minute.toString().padLeft(2,'0')}:'
                '${now.second.toString().padLeft(2,'0')}';
    // Sempre grava em memória, mas só dispara setState quando o painel está aberto.
    _logs.insert(0, _LogEntry(ts: ts, msg: msg, isError: isError));
    if (_logs.length > 40) _logs.removeLast();
    if (_showDebugLog && mounted) setState(() {});
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    if (!_diagnosticoLiberado) return;
    _heartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
      final state = _camera.value;
      final label = kIsWeb ? 'tentativas ZXing' : 'frames processados';
      if (kIsWeb) {
        final diag = callWebGetDiagnostics();
        _log('Scanner: running=${state.isRunning} | $label=$_frameCount | diag=$diag');
      } else {
        final platform = defaultTargetPlatform == TargetPlatform.android
            ? 'Android'
            : 'iOS';
        _log('$platform: running=${state.isRunning} | $label=$_frameCount');
      }
      _frameCount = 0;
    });
  }

  // ── Loop de scan ZXing via JS bridge (somente web / iOS Safari) ──────────
  void _startWebScanLoop() {
    if (!kIsWeb) return;
    _webScanTimer?.cancel();
    _log('Iniciando loop do leitor web');
    _webScanTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!_capturaAtiva) return;
      _doWebScan();
    });
  }

  Future<void> _doWebScan() async {
    if (_webScanBusy) return;
    _webScanBusy = true;
    _frameCount++;
    final ciclo = _cicloCamera;
    try {
      // Tempo limite no interop: um detector que nunca responde não prende
      // _webScanBusy (as próximas leituras continuariam ignoradas).
      final barcode = await callWebScanFrame(zoom: _zoom);
      if (barcode != null && barcode.isNotEmpty && ciclo == _cicloCamera && _capturaAtiva) {
        _log('Leitor web detectou: $barcode');
        _aceitarCodigo(barcode, origem: OrigemCodigo.camera);
      }
    } catch (e) {
      _log('Leitor web erro: $e', isError: true);
    } finally {
      _webScanBusy = false;
    }
  }

  /// Câmera deve estar lendo agora?
  bool get _capturaAtiva =>
      mounted && !_navigating && !_pausadoPorModal && !_emSegundoPlano && _rotaNoTopo && !_saindo;

  /// O scanner é a tela de cima? Com outra tela (ou folha) por cima, ou saindo, a
  /// câmera não lê: um código lido "por trás" abriria a confirmação sobre outra tela.
  bool _rotaNoTopo = true;
  bool _saindo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final noTopo = ModalRoute.isCurrentOf(context) ?? true;
    if (noTopo == _rotaNoTopo) return;
    _rotaNoTopo = noTopo;
    if (!noTopo) {
      _log('Outra tela cobriu o scanner — câmera pausada');
      _pararCamera();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _retomarCaptura();
      });
    }
  }

  // Animação da linha de scan ──────────────────────────────────────────────
  late final AnimationController _lineCtrl;
  late final Animation<double>   _lineAnim;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);

    // Zoom inicial: Android precisa mais zoom (melhor resolução do código)
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _zoom = 0.45; // Android: mais zoom (~3.15×)
    } else if (!kIsWeb) {
      _zoom = _kInitialZoomMobile; // iOS: zoom padrão (0.25 ≈ 2.75×)
    }

    // Inicia câmera APÓS o primeiro frame para garantir que o widget
    // MobileScanner já está na árvore (necessário para autoStart:false).
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_emSegundoPlano) {
          _emSegundoPlano = false;
          _log('App voltou ao primeiro plano');
          _retomarCaptura();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (!_emSegundoPlano) {
          _emSegundoPlano = true;
          _log('App em segundo plano — câmera pausada');
          _pararCamera();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Desliga câmera, temporizadores e animação, e invalida inícios pendentes.
  void _pararCamera() {
    _cicloCamera++;
    _iniciandoCamera = false;
    _heartbeat?.cancel();
    _webScanTimer?.cancel();
    _debounce?.cancel();
    if (_lineCtrl.isAnimating) _lineCtrl.stop();
    unawaited(_camera.stop().catchError((Object _) {}));
  }

  /// Volta a ler, uma vez, se nada impede (confirmação, revisão, modal, fundo).
  void _retomarCaptura() {
    if (!_capturaAtiva) return;
    if (_camera.value.isRunning || _iniciandoCamera) return;
    _startCamera();
  }

  Future<void> _startCamera() async {
    if (!_capturaAtiva) return;
    final ciclo = ++_cicloCamera;
    _iniciandoCamera = true;
    if (mounted) setState(() => _falhaCamera = null);

    // Web: o leitor de códigos (ZXing) é baixado só agora, quando o scanner
    // abre — e antes da câmera, para o mobile_scanner usar a mesma cópia.
    if (kIsWeb) {
      final leitores = await callWebEnsureReaders();
      if (ciclo != _cicloCamera || !mounted) return;
      if (leitores != 'ok') _log('Leitor ZXing: $leitores (segue com a detecção nativa, se houver)', isError: true);
    }

    FalhaCamera? falha;
    for (var tentativa = 0; tentativa < _kTentativasCamera; tentativa++) {
      if (ciclo != _cicloCamera || !mounted) return;
      _log('Iniciando câmera (tentativa ${tentativa + 1})');
      // Web: para o stream anterior antes de iniciar — sem isso o navegador
      // pode tentar abrir um segundo stream enquanto libera o primeiro.
      if (kIsWeb) {
        try { await _camera.stop(); } catch (_) {}
        await Future.delayed(Duration(milliseconds: tentativa == 0 ? 200 : 400 * tentativa + 400));
        if (ciclo != _cicloCamera || !mounted) return;
      }
      try {
        await _camera.start().timeout(widget.limiteCamera);
      } on TimeoutException {
        falha = FalhaCamera.semResposta;
        _log('A câmera não respondeu em ${widget.limiteCamera.inSeconds} s', isError: true);
      } on MobileScannerException catch (e) {
        if (e.errorCode != MobileScannerErrorCode.controllerAlreadyInitialized) {
          falha = classificarFalhaCamera(e);
          _log('Erro ao abrir câmera: ${e.errorCode.name} ${e.errorDetails?.message ?? ''}', isError: true);
        }
      } catch (e) {
        falha = classificarFalhaCamera(e);
        _log('Erro ao abrir câmera: $e', isError: true);
      }
      if (ciclo != _cicloCamera || !mounted) {
        // A tela mudou enquanto a câmera abria: não deixa a câmera ligada.
        unawaited(_camera.stop().catchError((Object _) {}));
        return;
      }
      if (falha == null) {
        _iniciandoCamera = false;
        _log('Câmera iniciada');
        if (!_lineCtrl.isAnimating) _lineCtrl.repeat(reverse: true);
        _startHeartbeat();
        if (kIsWeb) _startWebScanLoop();
        if (!kIsWeb && _zoomSupported) {
          try {
            await _camera.setZoomScale(_zoom);
          } catch (e) {
            _log('Zoom indisponível: $e', isError: true);
            if (mounted) setState(() => _zoomSupported = false);
          }
        }
        return;
      }
      if (!falha.repetirAutomaticamente) break;
      if (tentativa < _kTentativasCamera - 1) {
        falha = null;
        await Future.delayed(Duration(milliseconds: 600 + tentativa * 400));
      }
    }
    _iniciandoCamera = false;
    if (ciclo != _cicloCamera || !mounted) return;
    _log('Câmera indisponível: ${falha?.name}', isError: true);
    setState(() => _falhaCamera = falha ?? FalhaCamera.desconhecida);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cicloCamera++;
    _heartbeat?.cancel();
    _webScanTimer?.cancel();
    _debounce?.cancel();
    _flashDeteccao?.cancel();
    _lineCtrl.dispose();
    _camera.dispose();
    super.dispose();
  }

  // ── Detecção contínua ────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    _frameCount++;
    if (_showDebugLog && (capture.barcodes.isNotEmpty || _frameCount % 10 == 0)) {
      final dbgRaw = capture.barcodes.firstOrNull?.rawValue;
      _log('Frame #$_frameCount | barcodes: ${capture.barcodes.length}'
          '${dbgRaw != null ? " | valor: $dbgRaw" : ""}');
    }

    if (!_capturaAtiva) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Debounce leve (150ms) apenas para estabilidade da UI.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _aceitarCodigo(raw, origem: OrigemCodigo.camera);
    });
  }

  // ── Caminho único de aceitação do código ─────────────────────────────────
  Future<void> _aceitarCodigo(String bruto, {required OrigemCodigo origem}) async {
    if (_navigating || !mounted) return;
    final codigo = normalizarCodigo(bruto);
    final problema = validarCodigo(codigo);
    if (problema != null) {
      // Leitura da câmera inválida (ex.: dígito verificador): ignora e segue lendo.
      _log('Código recusado ($problema): $codigo', isError: true);
      if (origem != OrigemCodigo.camera) _avisar(problema);
      return;
    }
    _navigating = true;
    _pararCamera();
    _log('Código aceito ($origem): $codigo');

    if (origem.pedeConfirmacao) {
      if (!kIsWeb) HapticFeedback.mediumImpact();
      setState(() => _detected = true);
      _flashDeteccao?.cancel();
      _flashDeteccao = Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _detected = false);
      });
      final confirmado = await _confirmar(codigo);
      if (!mounted) return;
      if (confirmado != true) {
        _log('Leitura descartada — voltando a ler');
        _navigating = false;
        _retomarCaptura();
        return;
      }
    }
    await _abrirRevisao(codigo, origem);
  }

  /// QR Code do protocolo de doação: abre a doação (receber/conferir) em vez de
  /// procurar um produto com esse código.
  Future<bool> _abrirDoacaoPeloProtocolo(String protocolo) async {
    if (!canOperateDonations(ref.read(currentUserProvider))) {
      _avisar('Este é o QR Code de uma doação ($protocolo). Só administrador e estoquista '
          'abrem doações.');
      return false;
    }
    String? id;
    try {
      id = await ref.read(donationOpsRepositoryProvider).findIdByProtocol(protocolo);
    } catch (e) {
      _log('Erro ao buscar a doação $protocolo: $e', isError: true);
      _avisar('Não foi possível buscar a doação agora. Verifique a internet e tente de novo.');
      return false;
    }
    if (!mounted) return false;
    if (id == null) {
      _avisar('Nenhuma doação com o protocolo $protocolo.');
      return false;
    }
    _log('Protocolo $protocolo: doação $id');
    await context.push(AppRoutes.opsDonationPath(id));
    return true;
  }

  Future<void> _abrirRevisao(String codigo, OrigemCodigo origem) async {
    final protocolo = protocoloDeDoacao(codigo);
    if (protocolo != null) {
      final abriu = await _abrirDoacaoPeloProtocolo(protocolo);
      if (!mounted) return;
      if (abriu) ref.read(scannerProvider.notifier).reset();
      _navigating = false;
      _retomarCaptura();
      return;
    }
    // Histórico: uma vez por código aceito. A consulta externa começa na
    // própria revisão (depois do cadastro local) — aqui só navegamos.
    unawaited(ref.read(scanHistoryRepositoryProvider).record(codigo, source: origem.fonteHistorico));
    await context.push(rotaRevisao(codigo));
    if (!mounted) return;
    _log('Voltou da revisão — retomando a câmera');
    ref.read(scannerProvider.notifier).reset();
    _navigating = false;
    _retomarCaptura();
  }

  void _avisar(String texto, {bool erro = true}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        backgroundColor: erro ? cs.errorContainer : null,
        showCloseIcon: true,
      ));
  }

  // ── Escanear a partir de foto ─────────────────────────────────────────────
  Future<void> _scanFromPhoto() async {
    if (_navigating || _scanningFromPhoto) return;
    if (kIsWeb) {
      // Na web: captura do stream atual (ImageCapture) sem abrir câmera nativa.
      _log('Capturando foto do stream');
      setState(() => _scanningFromPhoto = true);
      final raw = await callWebCaptureAndScanRaw(zoom: _zoom);
      if (!mounted) return;
      setState(() => _scanningFromPhoto = false);
      if (raw != null && raw.isNotEmpty && !raw.startsWith('ERR:')) {
        _log('Código lido da foto: $raw');
        _aceitarCodigo(raw, origem: OrigemCodigo.foto);
        return;
      }
      final motivo = raw == null || raw.isEmpty ? 'nenhum' : raw.substring(4);
      _log('Foto sem código ($motivo)', isError: motivo != 'nenhum');
      switch (motivo) {
        case 'no_stream':
          _avisar('A câmera não está ativa. Reabrindo…');
          _retomarCaptura();
        case 'no_detector':
          _avisar('O leitor de códigos ainda não está disponível. Verifique a internet ou digite o código.');
        case 'timeout':
          _avisar('A leitura da foto demorou demais. Tente de novo ou digite o código.');
        default:
          _avisar('Nenhum código encontrado na foto. Aproxime, centralize e tente de novo — ou digite o código.');
      }
      return;
    }

    // Caminho nativo (Android / iOS): para câmera ANTES de abrir o picker do
    // sistema — no iOS, duas sessões simultâneas impedem a captura.
    _pausadoPorModal = true;
    _pararCamera();

    final picker = ImagePicker();
    String? achado;

    for (int attempt = 1; attempt <= _kMaxPhotoAttempts; attempt++) {
      if (!mounted || _navigating) break;
      setState(() { _scanningFromPhoto = true; _photoAttempt = attempt; });

      if (attempt > 1) {
        _avisar('Tentativa $attempt de $_kMaxPhotoAttempts — aproxime e centralize o código', erro: false);
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) break;
      }

      XFile? photo;
      try {
        photo = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 92,
        );
      } catch (e) {
        _log('Erro ao capturar foto: $e', isError: true);
        break;
      }
      if (photo == null) {
        _log('Captura cancelada na tentativa $attempt');
        break;
      }
      try {
        final raw = await analyzeBarcodeImage(photo.path);
        if (raw != null && raw.isNotEmpty) {
          achado = raw;
          break;
        }
        _log('Tentativa $attempt: nenhum código', isError: attempt == _kMaxPhotoAttempts);
      } catch (e) {
        _log('Erro do leitor na tentativa $attempt: $e', isError: true);
      }
    }

    if (!mounted) return;
    setState(() { _scanningFromPhoto = false; _photoAttempt = 0; });
    _pausadoPorModal = false;
    if (achado != null) {
      _aceitarCodigo(achado, origem: OrigemCodigo.foto);
      return;
    }
    _avisar('Código não detectado na foto. Aproxime mais ou digite o código.');
    _retomarCaptura();
  }

  // ── Ler o código de uma imagem já existente (galeria / arquivo) ─────────
  /// Funciona também sem câmera (ex.: computador sem webcam): a pessoa escolhe
  /// uma foto do código e o app lê. Na web usa ZXing/detector do navegador; no
  /// celular, o ML Kit.
  Future<void> _lerImagemEscolhida() async {
    if (_navigating || _scanningFromPhoto) return;
    _pausadoPorModal = true;
    _pararCamera();
    XFile? arquivo;
    try {
      arquivo = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 95);
    } catch (e) {
      _log('Erro ao escolher imagem: $e', isError: true);
    }
    if (!mounted) return;
    if (arquivo == null) {
      _pausadoPorModal = false;
      _retomarCaptura();
      return;
    }
    setState(() => _scanningFromPhoto = true);
    String? achado;
    try {
      achado = kIsWeb
          ? await callWebScanImageBytes(await arquivo.readAsBytes())
          : await analyzeBarcodeImage(arquivo.path);
    } catch (e) {
      _log('Erro ao ler a imagem: $e', isError: true);
    }
    if (!mounted) return;
    setState(() => _scanningFromPhoto = false);
    _pausadoPorModal = false;
    if (achado != null && achado.isNotEmpty) {
      _log('Código lido da imagem: $achado');
      _aceitarCodigo(achado, origem: OrigemCodigo.foto);
      return;
    }
    _avisar('Nenhum código encontrado nessa imagem. Use uma foto nítida, com o código inteiro '
        'e reto — ou digite o código.');
    _retomarCaptura();
  }

  Future<bool?> _confirmar(String barcode) {
    final ehEndereco = pareceEndereco(barcode);
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return SafeArea(
          top: false,
          child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
           child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success600.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: AppColors.success600, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text('Código detectado',
                              style: tt.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                        Text('Confira antes de continuar',
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: cs.outline.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_rounded,
                        color: cs.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        barcode,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (ehEndereco) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este QR contém um endereço da internet. Ele não será aberto: o texto é usado só como código do produto.',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Ler outro código'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  FilledButton.icon(
                    autofocus: true,
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('Continuar com este código'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
          ),
        );
      },
    );
  }

  // ── Zoom ─────────────────────────────────────────────────────────────────
  // Web: zoom digital (1.0× a 4.0×, passo 0.5×) e o leitor recorta o quadro
  // na mesma proporção. App nativo: zoom da câmera (0.0 a 1.0, passo 0.1).
  Future<void> _adjustZoom(double delta) async {
    if (!_zoomSupported) return;

    if (kIsWeb) {
      final step = delta > 0 ? 0.5 : -0.5;
      final next = (_zoom + step).clamp(1.0, 4.0);
      if ((next - _zoom).abs() < 0.01) return;
      setState(() => _zoom = next);
      return;
    }

    final next = (_zoom + delta).clamp(0.0, 1.0);
    if ((next - _zoom).abs() < 0.005) return;
    setState(() => _zoom = next);
    try {
      await _camera.setZoomScale(next);
    } catch (_) {
      if (mounted) setState(() => _zoomSupported = false);
    }
  }

  String get _zoomLabel {
    if (kIsWeb) return '${_zoom.toStringAsFixed(1)}×';
    return '${(1.0 + _zoom * 7.0).toStringAsFixed(1)}×';
  }

  // ── Código manual ────────────────────────────────────────────────────────
  Future<void> _showManualInput() async {
    if (_navigating) return;
    // Teclado/modal aberto: a câmera não lê por baixo.
    _pausadoPorModal = true;
    _pararCamera();
    final codigo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CodigoManualSheet(),
    );
    if (!mounted) return;
    _pausadoPorModal = false;
    if (codigo != null) {
      await _aceitarCodigo(codigo, origem: OrigemCodigo.digitado);
    } else {
      _retomarCaptura();
    }
  }

  Future<void> _abrirAjuda() async {
    _pausadoPorModal = true;
    _pararCamera();
    showCasaHelpModal(
      context: context,
      pageTitle: 'Escanear produto',
      pageDescription: 'Leia o código de barras ou QR da embalagem para ver o produto, os lotes e dar entrada.',
      headerIcon: Icons.qr_code_scanner_rounded,
      tips: const [
        HelpTip(
          icon: Icons.center_focus_strong_rounded,
          title: 'Enquadre o código',
          description: 'Deixe o código inteiro dentro do quadrado, bem iluminado. Use + e − para aproximar.',
        ),
        HelpTip(
          icon: Icons.keyboard_rounded,
          title: 'Digitar o código',
          description: 'Funciona sem câmera e sem internet: o produto já cadastrado aparece na revisão.',
        ),
        HelpTip(
          icon: Icons.photo_camera_rounded,
          title: 'Ler por foto',
          description: 'O botão redondo tira uma foto e procura o código nela — útil com reflexo ou código pequeno.',
        ),
      ],
      faq: const [
        HelpFaq(
          pergunta: 'A câmera não abre. O que faço?',
          resposta: 'A tela mostra o motivo (permissão, câmera em uso ou ausente). Corrija e toque em Tentar novamente — ou digite o código.',
        ),
        HelpFaq(
          pergunta: 'Li o código errado.',
          resposta: 'Na confirmação, toque em "Ler outro código". Nada é gravado antes de você confirmar.',
        ),
        HelpFaq(
          pergunta: 'E se o produto não estiver em nenhuma base?',
          resposta: 'Na revisão você pode cadastrá-lo manualmente; se a internet falhar, a revisão diz isso e oferece Tentar novamente.',
        ),
      ],
    ).whenComplete(() {
      if (!mounted) return;
      _pausadoPorModal = false;
      _retomarCaptura();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq       = MediaQuery.of(context);
    final sw       = mq.size.width;
    final sh       = mq.size.height;
    final boxSize  = _kScanBoxSize.clamp(160.0, (sw < sh ? sw : sh) * 0.7);
    final boxLeft  = (sw - boxSize) / 2;
    final boxTop   = (sh - boxSize) / 2;
    final scanWin  = Rect.fromLTWH(boxLeft, boxTop, boxSize, boxSize);
    final topPad   = mq.padding.top;
    final botPad   = mq.padding.bottom;

    return PopScope(
      // Saindo do scanner (voltar): desliga a câmera já, sem esperar a animação.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop || _saindo) return;
        _saindo = true;
        _pararCamera();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      // A câmera fica sempre em fundo escuro (melhor para enquadrar), em
      // qualquer tema; os textos sobre ela são claros.
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [

            // ── Câmera ───────────────────────────────────────────────────
            // Na WEB: ClipRect + Transform.scale para zoom digital (Safari iOS
            // não tem zoom de câmera). O leitor recorta o quadro na mesma
            // proporção, então o que aparece é o que é lido.
            ExcludeSemantics(
              child: kIsWeb
                  ? ClipRect(
                      child: Transform.scale(
                        scale: _zoom,
                        alignment: Alignment.center,
                        child: MobileScanner(
                          controller: _camera,
                          onDetect: _onDetect,
                        ),
                      ),
                    )
                  : MobileScanner(
                      controller: _camera,
                      onDetect: _onDetect,
                    ),
            ),

            // ── Overlay escuro + cantos + linha de scan ──────────────────
            ExcludeSemantics(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _lineAnim,
                  builder: (_, __) => CustomPaint(
                    size: Size(sw, sh),
                    painter: _ScanOverlayPainter(
                      scanWindow: scanWin,
                      lineProgress: _lineAnim.value,
                      detected: _detected,
                    ),
                  ),
                ),
              ),
            ),

            // ── Barra de controles superior ──────────────────────────────
            Positioned(
              top: topPad + 6,
              left: 8,
              right: 8,
              child: ValueListenableBuilder<MobileScannerState>(
                valueListenable: _camera,
                builder: (_, estado, __) {
                  final temLanterna = !kIsWeb &&
                      estado.isRunning &&
                      estado.torchState != TorchState.unavailable;
                  final variasCameras = (estado.availableCameras ?? 2) > 1;
                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 6,
                    children: [
                      _FabBtn(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Voltar',
                        onTap: () => context.pop(),
                      ),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_zoomSupported && estado.isRunning) ...[
                            _FabBtn(
                              icon: Icons.remove_rounded,
                              tooltip: 'Afastar (zoom −)',
                              onTap: () => _adjustZoom(-_kZoomStep),
                            ),
                            Semantics(
                              label: 'Zoom $_zoomLabel',
                              child: ExcludeSemantics(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _zoomLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _FabBtn(
                              icon: Icons.add_rounded,
                              tooltip: 'Aproximar (zoom +)',
                              onTap: () => _adjustZoom(_kZoomStep),
                            ),
                          ],
                          if (temLanterna)
                            _FabBtn(
                              icon: estado.torchState == TorchState.on
                                  ? Icons.flashlight_on_rounded
                                  : Icons.flashlight_off_rounded,
                              tooltip: estado.torchState == TorchState.on
                                  ? 'Desligar lanterna'
                                  : 'Ligar lanterna',
                              onTap: _camera.toggleTorch,
                            ),
                          if (estado.isRunning && variasCameras)
                            _FabBtn(
                              icon: Icons.flip_camera_ios_outlined,
                              tooltip: 'Trocar câmera',
                              onTap: () async {
                                await _camera.switchCamera();
                                if (!kIsWeb) {
                                  try { await _camera.setZoomScale(_zoom); } catch (_) {}
                                }
                              },
                            ),
                          _FabBtn(
                            icon: Icons.help_outline_rounded,
                            tooltip: 'Ajuda do scanner',
                            onTap: _abrirAjuda,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Título / instrução (acima do quadrado) ────────────────────
            if (_falhaCamera == null)
              Positioned(
                top: (boxTop - 70).clamp(topPad + 64, double.infinity),
                left: 24,
                right: 24,
                child: GestureDetector(
                  // Diagnóstico técnico: tocar e segurar o título.
                  onLongPress: () => setState(() => _diagnosticoLiberado = true),
                  child: Column(
                    children: [
                      Semantics(
                        header: true,
                        child: const Text(
                          'Escanear produto',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            shadows: [Shadow(blurRadius: 8)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _iniciandoCamera ? 'Abrindo a câmera…' : 'Aponte o código para a área marcada',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          shadows: [Shadow(blurRadius: 6)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Instrução embaixo do quadrado ────────────────────────────
            if (_falhaCamera == null)
              Positioned(
                top: boxTop + boxSize + 16,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'EAN/UPC · Code 128 · Code 39 · ITF · QR · Data Matrix',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ),

            // ── Ações inferiores: digitar e ler por foto ────────────────
            Positioned(
              bottom: botPad + 20,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_diagnosticoLiberado) ...[
                    _FabBtn(
                      icon: Icons.bug_report_rounded,
                      tooltip: _showDebugLog ? 'Ocultar diagnóstico' : 'Mostrar diagnóstico técnico',
                      onTap: () => setState(() => _showDebugLog = !_showDebugLog),
                    ),
                    const SizedBox(width: 12),
                  ],
                  _FabBtn(
                    icon: Icons.photo_library_rounded,
                    tooltip: 'Ler o código de uma imagem',
                    onTap: _lerImagemEscolhida,
                  ),
                  const SizedBox(width: 20),
                  _BotaoFoto(
                    ocupado: _scanningFromPhoto,
                    tentativa: _photoAttempt,
                    habilitado: _falhaCamera == null || !kIsWeb,
                    onTap: _scanFromPhoto,
                  ),
                  const SizedBox(width: 20),
                  _FabBtn(
                    icon: Icons.keyboard_rounded,
                    tooltip: 'Digitar o código',
                    onTap: _showManualInput,
                  ),
                ],
              ),
            ),

            // ── Câmera indisponível: motivo + Tentar novamente + Digitar ──
            if (_falhaCamera != null)
              Positioned(
                top: topPad + 72,
                left: 16,
                right: 16,
                child: _AvisoCamera(
                  falha: _falhaCamera!,
                  onTentarNovamente: () {
                    setState(() => _falhaCamera = null);
                    _retomarCaptura();
                  },
                  onDigitar: _showManualInput,
                  onImagem: _lerImagemEscolhida,
                ),
              ),

            // ── Painel de log visual ─────────────────────────────────────
            if (_showDebugLog)
              Positioned(
                bottom: botPad + 120,
                left: 12,
                right: 12,
                child: _DebugLogPanel(
                  logs: _logs,
                  onClear: () => setState(() => _logs.clear()),
                ),
              ),

          ],
        ),
      ),
      ),
    );
  }
}

// ── Digitação do código ──────────────────────────────────────────────────────
/// Folha de digitação: dona do próprio TextEditingController (descartado ao
/// fechar), valida com mensagem útil e aceita letras/símbolos (Code128/QR).
class _CodigoManualSheet extends StatefulWidget {
  const _CodigoManualSheet();
  @override
  State<_CodigoManualSheet> createState() => _CodigoManualSheetState();
}

class _CodigoManualSheetState extends State<_CodigoManualSheet> {
  final _ctrl = TextEditingController();
  String? _erro;
  bool _soNumeros = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _enviar() {
    final codigo = normalizarCodigo(_ctrl.text);
    final problema = validarCodigo(codigo);
    if (problema != null) {
      setState(() => _erro = problema);
      return;
    }
    Navigator.of(context).pop(codigo);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: cs.surface,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text('Digitar o código',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                Text('Funciona sem câmera e sem internet: primeiro procuramos no cadastro.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 16),
                TextField(
                  controller: _ctrl,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: _soNumeros ? TextInputType.number : TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _enviar(),
                  onChanged: (_) {
                    if (_erro != null) setState(() => _erro = null);
                  },
                  decoration: InputDecoration(
                    hintText: _soNumeros ? 'Ex.: 7891234567890' : 'Ex.: ABC-123/45',
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    labelText: 'Código de barras',
                    errorText: _erro,
                    errorMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 8),
                // O teclado numérico não tem letras: Code128/QR podem ter.
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: !_soNumeros,
                  onChanged: (v) => setState(() => _soNumeros = !v),
                  title: const Text('O código tem letras ou símbolos'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _enviar,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Buscar produto'),
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

// ── Aviso de câmera indisponível ─────────────────────────────────────────────
class _AvisoCamera extends StatelessWidget {
  final FalhaCamera falha;
  final VoidCallback onTentarNovamente;
  final VoidCallback onDigitar;
  final VoidCallback onImagem;
  const _AvisoCamera({
    required this.falha,
    required this.onTentarNovamente,
    required this.onDigitar,
    required this.onImagem,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Superfície escura neutra (a câmera fica atrás); o ícone indica o problema.
          color: const Color(0xF2121A26),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.videocam_off_rounded, color: Color(0xFFFFB4A8), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(falha.titulo,
                      style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(falha.explicacao, style: tt.bodyMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onDigitar,
                  icon: const Icon(Icons.keyboard_rounded, size: 18),
                  label: const Text('Digitar código'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brandPrimary800,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onImagem,
                  icon: const Icon(Icons.photo_library_rounded, size: 18, color: Colors.white),
                  label: const Text('Ler de uma imagem', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                    minimumSize: const Size(48, 48),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onTentarNovamente,
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                  label: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white70),
                    minimumSize: const Size(48, 48),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botão de leitura por foto ────────────────────────────────────────────────
class _BotaoFoto extends StatelessWidget {
  final bool ocupado;
  final int tentativa;
  final bool habilitado;
  final VoidCallback onTap;
  const _BotaoFoto({required this.ocupado, required this.tentativa, required this.habilitado, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (ocupado) {
      return Semantics(
        label: 'Procurando código na foto',
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                ),
                if (tentativa > 0)
                  Text('$tentativa/$_kMaxPhotoAttempts',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }
    return Tooltip(
      message: 'Ler código por foto',
      child: Semantics(
        button: true,
        enabled: habilitado,
        label: 'Ler código por foto',
        child: Material(
          color: habilitado ? Colors.white : Colors.white38,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: habilitado ? onTap : null,
            child: const SizedBox(
              width: 72,
              height: 72,
              child: Icon(Icons.photo_camera_rounded, color: Colors.black87, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modelo de entrada de log ─────────────────────────────────────────────────
class _LogEntry {
  final String ts;
  final String msg;
  final bool   isError;
  const _LogEntry({required this.ts, required this.msg, this.isError = false});
}

// ── Painel de log visual ──────────────────────────────────────────────────────
class _DebugLogPanel extends StatelessWidget {
  final List<_LogEntry> logs;
  final VoidCallback onClear;
  const _DebugLogPanel({required this.logs, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.bug_report_rounded,
                    color: Colors.greenAccent, size: 14),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Diagnóstico técnico',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Limpar', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Aguardando eventos...',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final e = logs[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 1),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.ts,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.msg,
                                style: TextStyle(
                                  color: e.isError
                                      ? Colors.redAccent
                                      : Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Botão circular flutuante ─────────────────────────────────────────────────
/// Alvo de 48 × 48, nome acessível e dica (tooltip).
class _FabBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _FabBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: Colors.black54,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Overlay CustomPainter ─────────────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  final Rect   scanWindow;
  final double lineProgress;
  final bool   detected;

  const _ScanOverlayPainter({
    required this.scanWindow,
    required this.lineProgress,
    this.detected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sombra ao redor do quadrado
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.68);
    final path   = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
          scanWindow, const Radius.circular(14)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shadow);

    // Cantos: branco ao detectar, verde normal
    final cornerColor = detected ? Colors.white : Colors.greenAccent;
    final corner = Paint()
      ..color      = cornerColor
      ..strokeWidth = detected ? 5.0 : 3.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    const cl = 30.0;
    final tl = scanWindow.topLeft;
    final tr = scanWindow.topRight;
    final bl = scanWindow.bottomLeft;
    final br = scanWindow.bottomRight;

    canvas.drawLine(tl + Offset(0, cl), tl, corner);
    canvas.drawLine(tl, tl + Offset(cl, 0), corner);
    canvas.drawLine(tr + Offset(-cl, 0), tr, corner);
    canvas.drawLine(tr, tr + Offset(0, cl), corner);
    canvas.drawLine(bl + Offset(0, -cl), bl, corner);
    canvas.drawLine(bl, bl + Offset(cl, 0), corner);
    canvas.drawLine(br + Offset(-cl, 0), br, corner);
    canvas.drawLine(br, br + Offset(0, -cl), corner);

    // Linha de scan animada
    final lineY = scanWindow.top + scanWindow.height * lineProgress;
    final lr = Rect.fromLTWH(
        scanWindow.left + 10, lineY - 1.5, scanWindow.width - 20, 3);
    final linePaint = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        Colors.greenAccent.withValues(alpha: 0.9),
        Colors.transparent,
      ]).createShader(lr);
    canvas.drawRect(lr, linePaint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.lineProgress != lineProgress || old.detected != detected || old.scanWindow != scanWindow;
}
