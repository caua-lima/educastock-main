// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Chama `window._zxingScanFrameCb(cb)` e retorna o barcode ou null.
/// Usa callback (js.allowInterop) para evitar problemas com promiseToFuture.
Future<String?> callWebScanFrame() {
  final completer = Completer<String?>();
  try {
    js.context.callMethod('_zxingScanFrameCb', [
      js.allowInterop((dynamic result) {
        if (completer.isCompleted) return;
        final str = result?.toString();
        completer.complete(str == null || str.isEmpty ? null : str);
      })
    ]);
  } catch (e) {
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}

/// Captura foto do stream e retorna o código OU string 'ERR:...' (para logs).
/// Usa callback (js.allowInterop) — sem promiseToFuture.
Future<String?> callWebCaptureAndScanRaw() {
  final completer = Completer<String?>();
  try {
    js.context.callMethod('_captureAndScanCb', [
      js.allowInterop((dynamic result) {
        if (completer.isCompleted) return;
        completer.complete(result?.toString());
      })
    ]);
  } catch (e) {
    if (!completer.isCompleted) completer.complete('ERR:dart:$e');
  }
  return completer.future;
}

/// Captura foto do stream e retorna o código ou null (sem ERR: prefix).
Future<String?> callWebCaptureAndScan() async {
  final raw = await callWebCaptureAndScanRaw();
  if (raw == null || raw.startsWith('ERR:')) return null;
  return raw.isEmpty ? null : raw;
}

/// Retorna diagnóstico do stream de vídeo (JSON string) — síncrono.
String callWebGetDiagnostics() {
  try {
    final dynamic result = js.context.callMethod('_getStreamDiagnostics', []);
    return result?.toString() ?? '{}';
  } catch (_) {
    return '{}';
  }
}

/// Stub mantido para compatibilidade.
Future<String?> callWebScanFromFile() async => null;
