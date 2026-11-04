import 'package:flutter/material.dart';

abstract class AppTypography {
  /// Família única do app: Roboto empacotada em `assets/fonts` (Apache 2.0, ver
  /// `LICENSE-Roboto.txt`), pesos 400/500/700/900. Antes os estilos pediam Poppins e
  /// Nunito Sans (nunca registradas — caíam na fonte do sistema, diferente em cada
  /// aparelho) e Plus Jakarta Sans baixada em tempo de execução (sem internet, o nome
  /// do produto mudava de fonte). Agora o texto é igual em todo lugar e funciona offline.
  static const String fontFamily = 'Roboto';

  // Nomes antigos mantidos para não espalhar mudança: todos apontam para a mesma família.
  static const String fontPoppins = fontFamily;
  static const String fontNunito = fontFamily;
  static const String fontProductName = fontFamily;

  /// Estilo dos NOMES DE PRODUTOS (Estoque, Saída, Receita etc.): mesmo peso e
  /// tamanho de antes, na fonte empacotada.
  static TextStyle productName({
    double size = 14,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double height = 1.15,
    double letterSpacing = -0.2,
  }) {
    return TextStyle(
      fontFamily: fontProductName,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  // Headings
  static const TextStyle headingLarge = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: fontPoppins,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontNunito,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontNunito,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontNunito,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // Label
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontNunito,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontNunito,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontNunito,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  // Numbers & indicators
  static const TextStyle numberLarge = TextStyle(
    fontFamily: fontNunito,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  static const TextStyle numberMedium = TextStyle(
    fontFamily: fontNunito,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.1,
  );

  static const TextStyle numberSmall = TextStyle(
    fontFamily: fontNunito,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // Button
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontNunito,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontNunito,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );
}
