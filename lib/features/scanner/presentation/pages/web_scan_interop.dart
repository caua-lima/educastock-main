import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Chama `window._zxingScanFrameCb(cb)` e retorna o barcode ou null.
/// Usa callback (dart:js_interop) para evitar problemas com promiseToFuture.
Future<String?> callWebScanFrame() {
  final completer = Completer<String?>();
  try {
    final callback = ((JSAny? result) {
      if (completer.isCompleted) return;
      final str = result?.dartify()?.toString();
      completer.complete(str == null || str.isEmpty ? null : str);
    }).toJS;
    globalContext.callMethod('_zxingScanFrameCb'.toJS, callback);
  } catch (e) {
    if (!completer.isCompleted) completer.complete(null);
  }
  return completer.future;
}

/// Captura foto do stream e retorna o código OU string 'ERR:...' (para logs).
/// Usa callback (dart:js_interop) — sem promiseToFuture.
Future<String?> callWebCaptureAndScanRaw() {
  final completer = Completer<String?>();
  try {
    final callback = ((JSAny? result) {
      if (completer.isCompleted) return;
      completer.complete(result?.dartify()?.toString());
    }).toJS;
    globalContext.callMethod('_captureAndScanCb'.toJS, callback);
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
    final JSAny? result =
        globalContext.callMethod<JSAny?>('_getStreamDiagnostics'.toJS);
    return result?.dartify()?.toString() ?? '{}';
  } catch (_) {
    return '{}';
  }
}

/// Stub mantido para compatibilidade.
Future<String?> callWebScanFromFile() async => null;
