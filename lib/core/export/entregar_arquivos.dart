import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'baixar_no_navegador_stub.dart'
    if (dart.library.html) 'baixar_no_navegador_web.dart';

/// Um arquivo gerado pelo app (relatório, dados do doador).
typedef ArquivoGerado = ({Uint8List bytes, String nome, String mime});

/// Entrega arquivos gerados pelo app.
///
/// No navegador, baixa direto: o "compartilhar" do Chrome no Windows abre a janela de
/// compartilhamento do sistema, que não tem opção de salvar. No celular, abre o menu de
/// compartilhar (salvar em Arquivos, mandar por e-mail, WhatsApp…).
Future<void> entregarArquivos(List<ArquivoGerado> arquivos, {String? assunto}) async {
  if (kIsWeb) {
    for (final a in arquivos) {
      baixarNoNavegador(a.bytes, a.nome, a.mime);
    }
    return;
  }
  await Share.shareXFiles(
    [for (final a in arquivos) XFile.fromData(a.bytes, mimeType: a.mime, name: a.nome)],
    fileNameOverrides: [for (final a in arquivos) a.nome],
    subject: assunto,
  );
}
