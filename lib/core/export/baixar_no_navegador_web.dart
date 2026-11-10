import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Baixa o arquivo pelo navegador (link temporário com `download`).
void baixarNoNavegador(Uint8List bytes, String nome, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = nome
    ..style.display = 'none';
  web.document.body!.append(link);
  link.click();
  link.remove();
  // Dá tempo ao navegador de começar o download antes de liberar a memória.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}
