import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web: o Auth do SDK JavaScript está mesmo ligado ao emulador?
///
/// O FlutterFire ignora em silêncio o erro "auth/emulator-config-failed" (quando uma
/// sessão salva já fez o Auth falar com o servidor real); aqui conferimos direto no
/// SDK (`getAuth().emulatorConfig`). Devolve null se não der para saber.
bool? authNoEmulador() {
  try {
    final modulo = globalContext['firebase_auth'];
    if (modulo == null || !modulo.isA<JSObject>()) return null;
    final auth = (modulo as JSObject).callMethod<JSAny?>('getAuth'.toJS);
    if (auth == null || !auth.isA<JSObject>()) return null;
    return (auth as JSObject)['emulatorConfig'].isDefinedAndNotNull;
  } catch (_) {
    return null;
  }
}
