import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

/// Chama uma função JS que responde por callback, com tempo limite e conclusão
/// única: se o JavaScript nunca chamar o callback (detector travado, aba em
/// segundo plano), o Future termina com [seTempoEsgotar] em vez de prender
/// quem espera (ex.: o `_webScanBusy` do scanner).
Future<String?> _comCallback(
  String funcao,
  List<JSAny?> args, {
  required Duration limite,
  required String? seTempoEsgotar,
  required String? seErro,
}) {
  if (!globalContext.has(funcao)) return Future.value(seErro);
  final completer = Completer<String?>();
  final relogio = Timer(limite, () {
    if (!completer.isCompleted) completer.complete(seTempoEsgotar);
  });
  try {
    final callback = ((JSAny? result) {
      if (completer.isCompleted) return;
      relogio.cancel();
      completer.complete(result?.dartify()?.toString());
    }).toJS;
    globalContext.callMethodVarArgs(funcao.toJS, [callback, ...args]);
  } catch (_) {
    relogio.cancel();
    if (!completer.isCompleted) completer.complete(seErro);
  }
  return completer.future;
}

/// Garante o leitor de códigos da web (ZXing + BarcodeDetector), baixado só
/// quando o scanner abre. Devolve 'ok', 'erro' (sem ZXing: segue só com o
/// detector nativo, quando houver) ou 'timeout'.
Future<String> callWebEnsureReaders({Duration limite = const Duration(seconds: 15)}) async {
  final r = await _comCallback('_ensureBarcodeReaders', const [],
      limite: limite, seTempoEsgotar: 'timeout', seErro: 'erro');
  return r ?? 'erro';
}

/// Lê um quadro da câmera. [zoom] > 1 faz o leitor considerar só a parte
/// central visível (o zoom da web é visual): o que aparece na tela é o que
/// é decodificado. Devolve o código ou null.
Future<String?> callWebScanFrame({double zoom = 1, Duration limite = const Duration(seconds: 3)}) async {
  final r = await _comCallback('_zxingScanFrameCb', [zoom.toJS],
      limite: limite, seTempoEsgotar: null, seErro: null);
  return (r == null || r.isEmpty) ? null : r;
}

/// Captura foto do stream e retorna o código OU 'ERR:...' (motivo).
Future<String?> callWebCaptureAndScanRaw({double zoom = 1, Duration limite = const Duration(seconds: 30)}) =>
    _comCallback('_captureAndScanCb', [zoom.toJS],
        limite: limite, seTempoEsgotar: 'ERR:timeout', seErro: 'ERR:no_detector');

/// Captura foto do stream e retorna o código ou null (sem ERR: prefix).
Future<String?> callWebCaptureAndScan() async {
  final raw = await callWebCaptureAndScanRaw();
  if (raw == null || raw.startsWith('ERR:')) return null;
  return raw.isEmpty ? null : raw;
}

/// Retorna diagnóstico do stream de vídeo (JSON string) — síncrono.
String callWebGetDiagnostics() {
  try {
    final JSAny? result =
        globalContext.callMethod<JSAny?>('_getStreamDiagnostics'.toJS);
    return result?.dartify()?.toString() ?? '{}';
  } catch (_) {
    return '{}';
  }
}

/// Lê o código de uma imagem escolhida pela pessoa (arquivo ou galeria).
/// Garante o leitor antes. Devolve o código ou null se não achar.
Future<String?> callWebScanImageBytes(Uint8List bytes, {Duration limite = const Duration(seconds: 20)}) async {
  await callWebEnsureReaders();
  final r = await _comCallback('_scanImageBytesCb', [bytes.toJS],
      limite: limite, seTempoEsgotar: null, seErro: null);
  return (r == null || r.isEmpty) ? null : r;
}

/// Stub mantido para compatibilidade.
Future<String?> callWebScanFromFile() async => null;
