/// Stubs para plataformas não-web. Nunca chamados em runtime.
Future<String> callWebEnsureReaders({Duration limite = const Duration(seconds: 15)}) async => 'ok';
Future<String?> callWebScanFrame({double zoom = 1, Duration limite = const Duration(seconds: 3)}) async => null;
Future<String?> callWebCaptureAndScan() async => null;
Future<String?> callWebCaptureAndScanRaw({double zoom = 1, Duration limite = const Duration(seconds: 30)}) async => null;
Future<String?> callWebScanFromFile() async => null;
String callWebGetDiagnostics() => '{}';
