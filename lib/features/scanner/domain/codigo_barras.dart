// Regras do código lido ou digitado no scanner — iguais para câmera, foto e
// digitação. O código é texto: zeros à esquerda e letras/símbolos de QR e
// Code128 (&, #, +, %, /) são preservados e sempre vão codificados na rota.

import '../../../core/router/app_router.dart';

/// De onde veio o código. Define só o registro no histórico e se pedimos
/// confirmação (a câmera pode ler algo que a pessoa não quis).
enum OrigemCodigo { camera, foto, digitado }

extension OrigemCodigoX on OrigemCodigo {
  /// Valor gravado no histórico de leituras (`scanned` ou `typed`).
  String get fonteHistorico =>
      this == OrigemCodigo.digitado ? 'typed' : 'scanned';
  bool get pedeConfirmacao => this != OrigemCodigo.digitado;
}

/// Tamanho máximo aceito (QR pode ser longo; acima disso não é código de produto).
const kCodigoTamanhoMaximo = 256;

final _invisiveis = RegExp(r'[\u0000-\u001F\u007F​-‍﻿]');
final _soDigitos = RegExp(r'^\d+$');

/// Tira espaços das pontas e caracteres invisíveis (quebra de linha, zero-width).
/// Não remove zeros nem converte para número.
String normalizarCodigo(String bruto) => bruto.replaceAll(_invisiveis, '').trim();

/// Dígito verificador GTIN (EAN-8, UPC-A, EAN-13, GTIN-14) confere?
bool gtinValido(String digitos) {
  if (!_soDigitos.hasMatch(digitos)) return false;
  if (![8, 12, 13, 14].contains(digitos.length)) return false;
  var soma = 0;
  final semDv = digitos.substring(0, digitos.length - 1);
  for (var i = 0; i < semDv.length; i++) {
    final d = int.parse(semDv[semDv.length - 1 - i]);
    soma += i.isEven ? d * 3 : d;
  }
  final dv = (10 - soma % 10) % 10;
  return dv == int.parse(digitos[digitos.length - 1]);
}

/// Mensagem do problema, ou null se o código pode ser consultado.
///
/// Só números com 8, 12, 13 ou 14 dígitos são tratados como EAN/UPC e têm o
/// dígito verificador conferido; qualquer outro texto (Code128, Code39, QR,
/// código interno) é aceito como está.
String? validarCodigo(String codigo) {
  final c = normalizarCodigo(codigo);
  if (c.isEmpty) return 'Digite o código de barras.';
  if (c.length > kCodigoTamanhoMaximo) {
    return 'Código muito longo (máximo de $kCodigoTamanhoMaximo caracteres).';
  }
  if (_soDigitos.hasMatch(c) && [8, 12, 13, 14].contains(c.length) && !gtinValido(c)) {
    return 'O último dígito não confere com os anteriores. Confira os números do código (EAN/UPC).';
  }
  return null;
}

/// O código lido parece um endereço da internet (QR de site)? Ele nunca é
/// aberto automaticamente; a tela só avisa.
bool pareceEndereco(String codigo) {
  final c = normalizarCodigo(codigo).toLowerCase();
  return c.startsWith('http://') || c.startsWith('https://') || c.startsWith('www.');
}

/// Rota com os parâmetros codificados (nunca interpolar o código na URL).
String rotaComParametros(String caminho, Map<String, String?> parametros) {
  final validos = <String, String>{
    for (final e in parametros.entries)
      if (e.value != null) e.key: e.value!,
  };
  return Uri(path: caminho, queryParameters: validos.isEmpty ? null : validos).toString();
}

/// Rota da revisão do produto para [codigo].
String rotaRevisao(String codigo) =>
    rotaComParametros(AppRoutes.productReview, {'barcode': codigo});
