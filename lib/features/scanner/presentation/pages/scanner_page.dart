import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../data/scan_history_repository.dart';
import '../controllers/scanner_provider.dart';
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

// ── Página ───────────────────────────────────────────────────────────────────
class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});
  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage>
    with SingleTickerProviderStateMixin {

  // Camera ─────────────────────────────────────────────────────────────────
  // Nativo (Android + iOS): noDuplicates — o SDK nativo gerencia deduplicação
  // e entrega cada barcode apenas uma vez, sem debounce agressivo.
  // Web: DetectionSpeed.normal — o loop ZXing customizado tem busy-guard próprio.
  //
  // formats: limita aos formatos usados em produtos de ONG brasileira.
  // Isso evita que o ML Kit (Android) e Vision (iOS) rodem todos os algoritmos
  // a cada frame — impacto direto na velocidade de detecção e no uso de CPU.
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

  bool   _navigating    = false;
  bool   _zoomSupported = true;
  // Web: 1.5× digital zoom — barcodes ficam na proporção correta do scan box
  // sem perda de qualidade (ZXing lê do frame nativo full HD, não do CSS zoom)
  double _zoom          = kIsWeb ? 1.5 : _kInitialZoomMobile;
  bool   _detected      = false;

  // ── Log visual de diagnóstico ─────────────────────────────────────────
  bool _showDebugLog      = false;
  bool _cameraFailed      = false;
  bool _scanningFromPhoto = false;
  int  _photoAttempt      = 0;   // tentativa atual da varredura por foto
  int  _frameCount        = 0;
  Timer? _heartbeat;
  Timer? _webScanTimer;
  Timer? _debounce;              // evita duplicatas em DetectionSpeed.normal
  bool   _webScanBusy = false;  // evita scans web sobrepostos
  final List<_LogEntry> _logs = [];

  void _log(String msg, {bool isError = false}) {
    final now = DateTime.now();
    final ts  = '${now.hour.toString().padLeft(2,'0')}:'
                '${now.minute.toString().padLeft(2,'0')}:'
                '${now.second.toString().padLeft(2,'0')}';
    // Sempre grava em memória, mas só dispara setState quando o painel está aberto.
    // Evita rebuilds da árvore toda na frequência dos frames da câmera.
    _logs.insert(0, _LogEntry(ts: ts, msg: msg, isError: isError));
    if (_logs.length > 40) _logs.removeLast();
    if (_showDebugLog && mounted) setState(() {});
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
      final state = _camera.value;
      final label = kIsWeb ? 'tentativas ZXing' : 'frames processados';
      if (kIsWeb) {
        final diag = callWebGetDiagnostics();
        _log('💓 Scanner: running=${state.isRunning} | $label=$_frameCount | diag=$diag');
      } else {
        final platform = defaultTargetPlatform == TargetPlatform.android
            ? 'Android'
            : 'iOS';
        _log('💓 $platform: running=${state.isRunning} | $label=$_frameCount');
      }
      _frameCount = 0;
    });
  }

  // ── Loop de scan ZXing via JS bridge (somente web / iOS Safari) ──────────
  void _startWebScanLoop() {
    if (!kIsWeb) return;
    _webScanTimer?.cancel();
    _log('🔁 Iniciando loop ZXing (multi-estratégia)');
    _webScanTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (_navigating || !mounted) return;
      _doWebScan();
    });
  }

  Future<void> _doWebScan() async {
    if (_webScanBusy) return;
    _webScanBusy = true;
    _frameCount++;
    try {
      final barcode = await callWebScanFrame();
      if (barcode != null && barcode.isNotEmpty && !_navigating && mounted) {
        _log('🎯 ZXing detectou: $barcode');
        _webScanTimer?.cancel();
        _processBarcode(barcode);
      }
    } catch (e) {
      _log('⚠️ ZXing erro: $e', isError: true);
    } finally {
      _webScanBusy = false;
    }
  }

  // Animação da linha de scan ──────────────────────────────────────────────
  late final AnimationController _lineCtrl;
  late final Animation<double>   _lineAnim;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
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

  Future<void> _startCamera({int attempt = 0}) async {
    if (!mounted) return;
    if (mounted) setState(() => _cameraFailed = false);
    _log('📷 Iniciando câmera... (tentativa ${attempt + 1})');

    // Web: sempre para o stream anterior antes de iniciar (mesmo attempt=0).
    // Sem o stop prévio, mobile_scanner pode tentar criar um segundo stream
    // enquanto o anterior ainda está sendo liberado, causando flickering.
    // attempt=0 usa 200 ms mínimo para o browser finalizar o track anterior.
    if (kIsWeb) {
      try { await _camera.stop(); } catch (_) {}
      await Future.delayed(attempt > 0
          ? Duration(milliseconds: 400 * attempt)
          : const Duration(milliseconds: 200));
    }

    try {
      await _camera.start();
      _log('✅ Câmera iniciada com sucesso');
      if (!kIsWeb) {
        final plat = defaultTargetPlatform == TargetPlatform.android ? 'Android' : 'iOS';
        _log('🎯 $plat: noDuplicates, zoom=${_zoom.toStringAsFixed(2)}, debounce=150ms');
      }
      _startHeartbeat();
      if (kIsWeb) _startWebScanLoop();
      if (!kIsWeb) {
        try {
          await _camera.setZoomScale(_zoom);
          _log('🔍 Zoom inicial: ${(_zoom * 7 + 1).toStringAsFixed(1)}×');
        } catch (e) {
          _log('⚠️ Zoom indisponível: $e', isError: true);
          if (mounted) setState(() => _zoomSupported = false);
        }
      }
    } catch (e) {
      final err = e.toString().toLowerCase();
      _log('❌ Erro (tentativa ${attempt + 1}): $e', isError: true);

      // Permissão negada — não adianta tentar novamente automaticamente
      if (err.contains('notallowed') ||
          err.contains('permission') ||
          err.contains('denied')) {
        _log('🚫 Permissão de câmera negada pelo usuário', isError: true);
        if (mounted) setState(() => _cameraFailed = true);
        return;
      }

      // iOS Safari: após conceder permissão, o stream é interrompido.
      // Aguardamos e tentamos até 3 vezes.
      if (kIsWeb && attempt < 3 && mounted) {
        _log('🔄 Aguardando iOS liberar câmera...');
        await Future.delayed(Duration(milliseconds: 600 + attempt * 400));
        if (mounted) await _startCamera(attempt: attempt + 1);
        return;
      }

      // Falha definitiva
      _log('❌ Não foi possível iniciar câmera após ${attempt + 1} tentativas', isError: true);
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _webScanTimer?.cancel();
    _debounce?.cancel();
    _lineCtrl.dispose();
    _camera.dispose();
    super.dispose();
  }

  // ── Detecção contínua ────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    _frameCount++;

    // Log de frame: só quando o painel de debug está visível.
    // SEM esse guard, _log → setState toda frame → jank na animação do Android.
    if (_showDebugLog && (capture.barcodes.isNotEmpty || _frameCount % 10 == 0)) {
      final dbgRaw = capture.barcodes.firstOrNull?.rawValue;
      _log('📡 Frame #$_frameCount | barcodes: ${capture.barcodes.length}'
          '${dbgRaw != null ? " | valor: $dbgRaw" : ""}');
    }

    if (_navigating) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // noDuplicates garante que o mesmo barcode não chega duas vezes seguidas.
    // Debounce leve (150ms) apenas para estabilidade da UI.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!_navigating && mounted) _processBarcode(raw);
    });
  }

  void _processBarcode(String raw) {
    if (_navigating) return;
    _navigating = true;
    _heartbeat?.cancel();
    _webScanTimer?.cancel();
    _log('🎯 Código aceito: $raw');
    if (!kIsWeb) HapticFeedback.mediumImpact();
    setState(() => _detected = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _detected = false);
    });
    _camera.stop();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _showConfirmation(raw);
    });
  }

  // ── Escanear a partir de foto ─────────────────────────────────────────────
  Future<void> _scanFromPhoto() async {
    if (kIsWeb) {
      // Na web (iOS Chrome/Safari): usa ImageCapture.takePhoto() para capturar
      // do stream atual SEM abrir câmera nativa do iOS.
      _log('📸 Capturando foto do stream (ImageCapture)...');
      if (mounted) setState(() => _scanningFromPhoto = true);
      try {
        final raw = await callWebCaptureAndScanRaw()
            .timeout(const Duration(seconds: 30), onTimeout: () => 'ERR:timeout');
        if (raw == null || raw.isEmpty) {
          _log('📸 Nenhum código detectado na foto', isError: true);
        } else if (raw.startsWith('ERR:')) {
          final reason = raw.substring(4);
          switch (reason) {
            case 'no_stream':
              _log('📸 Câmera não está ativa — reiniciando...', isError: true);
              if (mounted) setState(() => _scanningFromPhoto = false);
              await _startCamera();
              return;
            case 'no_detector':
              _log('📸 BarcodeDetector não disponível — aguarde o polyfill carregar', isError: true);
            case 'capture_failed':
              _log('📸 Falha na captura — tente novamente', isError: true);
            case 'timeout':
              _log('📸 Timeout ao capturar foto', isError: true);
            default:
              _log('📸 Erro: $raw', isError: true);
          }
          if (mounted) {
            setState(() => _scanningFromPhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ $reason — aproxime o código e tente novamente'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        } else {
          _log('📸 Código lido da foto: $raw');
          if (mounted) setState(() => _scanningFromPhoto = false);
          _processBarcode(raw);
          return;
        }
        if (mounted) {
          setState(() => _scanningFromPhoto = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Nenhum código detectado. Aproxime mais e tente novamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        _log('📸 Erro ao capturar foto: $e', isError: true);
        if (mounted) setState(() => _scanningFromPhoto = false);
      }
      return;
    }

    // Caminho nativo (Android / iOS):
    // Para câmera ANTES de abrir o picker do sistema — no iOS, duas sessões de
    // câmera simultâneas impedem a captura e causam falha silenciosa no analyzeImage.
    try { await _camera.stop(); } catch (_) {}

    final picker = ImagePicker();
    bool foundBarcode = false;

    for (int attempt = 1; attempt <= _kMaxPhotoAttempts; attempt++) {
      if (!mounted || _navigating) break;

      if (mounted) setState(() { _scanningFromPhoto = true; _photoAttempt = attempt; });

      if (attempt > 1 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔍 Tentativa $attempt/$_kMaxPhotoAttempts — aproxime e centralize o código',
            ),
            duration: const Duration(milliseconds: 1800),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) break;
      }

      _log('📸 Tentativa $attempt/$_kMaxPhotoAttempts — abrindo câmera...');

      XFile? photo;
      try {
        photo = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.rear,
          // 92 % = arquivo menor → ML Kit processa mais rápido, sem perda de detecção
          imageQuality: 92,
        );
      } catch (e) {
        _log('📸 Erro ao capturar foto: $e', isError: true);
        break;
      }

      if (photo == null) {
        _log('📸 Captura cancelada na tentativa $attempt');
        break;
      }

      _log('📸 Analisando via ML Kit: ${photo.path}');
      try {
        // Usa ML Kit diretamente — mais confiável que _camera.analyzeImage
        // (que depende do estado interno do MobileScannerController)
        final raw = await analyzeBarcodeImage(photo.path);
        if (raw != null && raw.isNotEmpty) {
          _log('📸 ✅ Código detectado na tentativa $attempt: $raw');
          if (mounted) setState(() { _scanningFromPhoto = false; _photoAttempt = 0; });
          foundBarcode = true;
          _processBarcode(raw); // _processBarcode reinicia câmera após confirmação
          return;
        }
        _log('📸 Tentativa $attempt: nenhum código detectado',
            isError: attempt == _kMaxPhotoAttempts);
      } catch (e) {
        _log('📸 Erro ML Kit na tentativa $attempt: $e', isError: true);
      }
    }

    // Limpa estado e reinicia câmera (tentativas esgotadas ou cancelamento)
    if (mounted) {
      setState(() { _scanningFromPhoto = false; _photoAttempt = 0; });
      if (!foundBarcode && !_navigating) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Código não detectado. Tente digitar manualmente ou aproxime mais.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    if (!_navigating) _startCamera();
  }

  void _showConfirmation(String barcode) {
    showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, 24 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
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
              // Ícone + título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Código detectado!',
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Confirme antes de prosseguir',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Chip do código
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: cs.outline.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_rounded,
                        color: cs.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        barcode,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Ações
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Escanear\nnovamente',
                          textAlign: TextAlign.center),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Confirmar código'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _log('✔️ Confirmado → navegando para revisão');
        ref.read(scannerProvider.notifier).onBarcodeDetected(barcode);
        // Salva no histórico do banco (Firestore) como ESCANEADO.
        ref
            .read(scanHistoryRepositoryProvider)
            .record(barcode, source: 'scanned');
        context
            .push('${AppRoutes.productReview}?barcode=$barcode')
            .then((_) {
          _log('↩️ Voltou da revisão — reiniciando câmera');
          _navigating = false;
          ref.read(scannerProvider.notifier).reset();
          _startCamera();
        });
      } else {
        _log('🔄 Cancelado — reiniciando câmera');
        _navigating = false;
        _startCamera();
      }
    });
  }

  // ── Zoom ─────────────────────────────────────────────────────────────────
  // Safari/Web: zoom digital via Transform.scale (1.0× a 4.0×, passo 0.5×).
  // App nativo: zoom via setZoomScale da câmera  (0.0 a 1.0, passo 0.1).
  Future<void> _adjustZoom(double delta) async {
    if (!_zoomSupported) return;

    if (kIsWeb) {
      // Zoom digital — apenas escala o widget Flutter, não a câmera.
      // Funciona em qualquer browser incluindo Safari iOS.
      final step = delta > 0 ? 0.5 : -0.5;
      final next = (_zoom + step).clamp(1.0, 4.0);
      if ((next - _zoom).abs() < 0.01) return;
      setState(() => _zoom = next);
      return;
    }

    // App nativo: zoom real da câmera
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
    if (kIsWeb) {
      // Web: _zoom já é o fator de escala real (ex: 2.0 = 2×)
      return '${_zoom.toStringAsFixed(1)}×';
    }
    // App nativo: 0.0 → 1.0×  …  1.0 → 8.0×
    return '${(1.0 + _zoom * 7.0).toStringAsFixed(1)}×';
  }

  // ── Código manual ────────────────────────────────────────────────────────
  void _showManualInput() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        final tt = Theme.of(sheetCtx).textTheme;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                Text('Código manual',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Digite o código para buscar o produto.',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ex: 7891234567890',
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    labelText: 'Código de barras',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final code = ctrl.text.trim();
                      if (code.isEmpty) return;
                      ref
                          .read(scanHistoryRepositoryProvider)
                          .record(code, source: 'typed');
                      Navigator.of(sheetCtx).pop();
                      context.push(
                          '${AppRoutes.productReview}?barcode=$code');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Buscar produto'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq       = MediaQuery.of(context);
    final sw       = mq.size.width;
    final sh       = mq.size.height;
    final boxLeft  = (sw - _kScanBoxSize) / 2;
    final boxTop   = (sh - _kScanBoxSize) / 2;
    final scanWin  = Rect.fromLTWH(boxLeft, boxTop, _kScanBoxSize, _kScanBoxSize);
    final topPad   = mq.padding.top;
    final botPad   = mq.padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [

            // ── Câmera ───────────────────────────────────────────────────
            // NÃO usamos scanWindow — não é suportado na web e em algumas
            // versões Android pode bloquear toda a detecção.
            // Na WEB: envolvemos com ClipRect + Transform.scale para zoom digital.
            // Isso funciona em Safari iOS onde a API de zoom de câmera não existe.
            // A detecção roda no frame nativo (sem corte), o zoom é só visual.
            if (kIsWeb)
              ClipRect(
                child: Transform.scale(
                  scale: _zoom,
                  alignment: Alignment.center,
                  child: MobileScanner(
                    controller: _camera,
                    onDetect: _onDetect,
                  ),
                ),
              )
            else
              MobileScanner(
                controller: _camera,
                onDetect: _onDetect,
              ),


            // ── Overlay escuro + cantos + linha de scan ──────────────────
            // RepaintBoundary isola a animação do resto da árvore:
            // qualquer rebuild do Scaffold não repinta o overlay, e vice-versa.
            RepaintBoundary(
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

            // ── Barra de controles superior ──────────────────────────────
            Positioned(
              top: topPad + 6,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  _FabBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  // ── Controles de Zoom ─────────────────────────────
                  if (_zoomSupported) ...[
                    _FabBtn(
                      icon: Icons.remove_rounded,
                      onTap: () => _adjustZoom(-_kZoomStep),
                    ),
                    const SizedBox(width: 6),
                    Container(
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
                    const SizedBox(width: 6),
                    _FabBtn(
                      icon: Icons.add_rounded,
                      onTap: () => _adjustZoom(_kZoomStep),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    // Na web o browser não expõe controle de zoom de câmera
                    Tooltip(
                      message: 'Zoom indisponível no navegador',
                      child: Opacity(
                        opacity: 0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.zoom_in_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('zoom',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Lanterna — indisponível no browser (Safari/Chrome iOS
                  // não expõem a API de torch via WebRTC).
                  if (!kIsWeb) ...[
                    ValueListenableBuilder(
                      valueListenable: _camera,
                      builder: (_, state, __) => _FabBtn(
                        icon: state.torchState == TorchState.on
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        onTap: _camera.toggleTorch,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Virar câmera
                  _FabBtn(
                    icon: Icons.flip_camera_ios_outlined,
                    onTap: () async {
                      await _camera.switchCamera();
                      // Na web o zoom é digital (Transform.scale), não precisa
                      // reaplicar setZoomScale após troca de câmera.
                      if (!kIsWeb) {
                        try { await _camera.setZoomScale(_zoom); } catch (_) {}
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── Título / instrução (acima do quadrado) ────────────────────
            Positioned(
              top: topPad + 66,
              left: 24,
              right: 24,
              child: const Column(
                children: [
                  Text(
                    'Escanear produto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Aponte o código para a área marcada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // ── Instrução embaixo do quadrado ────────────────────────────
            Positioned(
              top: boxTop + _kScanBoxSize + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'EAN-8 · EAN-13 · QR Code · Code 128',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
            ),

            // ── Botão inferior central: tirar foto (FAB redondo) ────────────
            Positioned(
              bottom: botPad + 24,
              left: 0,
              right: 0,
              child: Center(
                child: _scanningFromPhoto
                    ? Container(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                              if (_photoAttempt > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '$_photoAttempt/$_kMaxPhotoAttempts',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : GestureDetector(
                        onTap: _scanFromPhoto,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 14,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.black87,
                            size: 32,
                          ),
                        ),
                      ),
              ),
            ),

            // ── Botão código manual (ícone) ──────────────────────────────
            Positioned(
              bottom: botPad + 40,
              right: 32,
              child: _FabBtn(
                icon: Icons.keyboard_rounded,
                onTap: _showManualInput,
              ),
            ),

            // ── Banner: câmera com falha definitiva ──────────────────────
            if (_cameraFailed)
              Positioned(
                top: topPad + 66,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.videocam_off_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Câmera indisponível',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Permita o acesso à câmera nas configurações do navegador e toque em "Tentar novamente".',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _startCamera(),
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 16),
                          label: const Text('Tentar novamente',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Botão de log de diagnóstico ──────────────────────────────
            Positioned(
              bottom: botPad + 40,
              left: 32,
              child: _FabBtn(
                icon: Icons.bug_report_rounded,
                onTap: () => setState(() => _showDebugLog = !_showDebugLog),
              ),
            ),

            // ── Painel de log visual ─────────────────────────────────────
            if (_showDebugLog)
              Positioned(
                bottom: botPad + 130,
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
        color: Colors.black.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          // Cabeçalho
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.bug_report_rounded,
                    color: Colors.greenAccent, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'Log de diagnóstico',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClear,
                  child: const Text(
                    'limpar',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Lista de eventos
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Aguardando eventos...',
                      style: TextStyle(
                        color: Colors.white38,
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
                                color: Colors.white38,
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
class _FabBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FabBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
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
    final shadow = Paint()..color = Colors.black.withOpacity(0.68);
    final path   = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
          scanWindow, const Radius.circular(14)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shadow);

    // Cantos: branco piscante ao detectar, verde normal
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

    // top-left
    canvas.drawLine(tl + Offset(0, cl), tl, corner);
    canvas.drawLine(tl, tl + Offset(cl, 0), corner);
    // top-right
    canvas.drawLine(tr + Offset(-cl, 0), tr, corner);
    canvas.drawLine(tr, tr + Offset(0, cl), corner);
    // bottom-left
    canvas.drawLine(bl + Offset(0, -cl), bl, corner);
    canvas.drawLine(bl, bl + Offset(cl, 0), corner);
    // bottom-right
    canvas.drawLine(br + Offset(-cl, 0), br, corner);
    canvas.drawLine(br, br + Offset(0, -cl), corner);

    // Linha de scan animada
    final lineY = scanWindow.top + scanWindow.height * lineProgress;
    final lr = Rect.fromLTWH(
        scanWindow.left + 10, lineY - 1.5, scanWindow.width - 20, 3);
    final linePaint = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        Colors.greenAccent.withOpacity(0.9),
        Colors.transparent,
      ]).createShader(lr);
    canvas.drawRect(lr, linePaint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.lineProgress != lineProgress || old.detected != detected;
}
