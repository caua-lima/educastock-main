import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppTypography {
  // Poppins — títulos e destaques
  static const String fontPoppins = 'Poppins';

  // Nunito Sans — textos, formulários, números
  static const String fontNunito = 'NunitoSans';

  /// Fonte distinta para NOMES DE PRODUTOS — usada em todas as áreas
  /// que listam produtos (Estoque, Saída, Receita, etc).
  /// Plus Jakarta Sans é moderna, com bom peso visual e excelente leitura.
  static TextStyle productName({
    double size = 14,
    FontWeight weight = FontWeight.w800,
    Color? color,
    double height = 1.15,
    double letterSpacing = -0.2,
  }) {
    return GoogleFonts.plusJakartaSans(
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
