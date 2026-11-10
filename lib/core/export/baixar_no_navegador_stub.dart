import 'dart:typed_data';

// Fora da web os arquivos vão pelo menu de compartilhar (ver entregarArquivos).
void baixarNoNavegador(Uint8List bytes, String nome, String mime) =>
    throw UnsupportedError('Download direto só existe na web.');
