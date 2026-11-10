// Stubs para plataformas não-web. Nunca chamados em runtime.
import 'dart:typed_data';

Future<String> callWebEnsureReaders({Duration limite = const Duration(seconds: 15)}) async => 'ok';
Future<String?> callWebScanFrame({double zoom = 1, Duration limite = const Duration(seconds: 3)}) async => null;
Future<String?> callWebCaptureAndScan() async => null;
Future<String?> callWebCaptureAndScanRaw({double zoom = 1, Duration limite = const Duration(seconds: 30)}) async => null;
Future<String?> callWebScanFromFile() async => null;
Future<String?> callWebScanImageBytes(Uint8List bytes, {Duration limite = const Duration(seconds: 20)}) async => null;
String callWebGetDiagnostics() => '{}';
