import 'package:flutter/material.dart';

abstract class AppColors {
  // Brand Primary
  static const brandPrimary800 = Color(0xFF0B3C74);
  static const brandPrimary700 = Color(0xFF0F4C8A);
  static const brandPrimary600 = Color(0xFF1D5FA8);
  static const brandPrimary500 = Color(0xFF2F74C0);
  static const brandPrimary100 = Color(0xFFDCEBFA);

  /// Azul da marca clareado para TEXTO/ícone sobre fundo escuro (tema escuro):
  /// 8,3:1 sobre a superfície escura; o 500 dava 3,8:1, abaixo do AA (4,5:1).
  static const brandPrimary300 = Color(0xFF7FB3EE);

  // Secondary
  static const secondaryBlue600 = Color(0xFF2563EB);
  static const secondarySky500 = Color(0xFF38BDF8);

  // Semantic
  static const info600 = Color(0xFF1E40AF);
  static const success600 = Color(0xFF2E7D32);
  static const warning600 = Color(0xFFB7791F);
  static const danger600 = Color(0xFFC53030);

  /// Vermelho de erro para o tema escuro (6,5:1 sobre a superfície escura; o 600 dava 3,3:1).
  static const danger400 = Color(0xFFF87171);

  // Neutral
  static const neutral900 = Color(0xFF111827);
  static const neutral700 = Color(0xFF374151);
  static const neutral500 = Color(0xFF6B7280);
  static const neutral100 = Color(0xFFF3F4F6);

  // Surface
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFEFF6FF);

  // Status chips
  static const chipCritico = danger600;
  static const chipAtencao = warning600;
  static const chipOk = success600;
  static const chipVencido = Color(0xFF6B7280);
  static const chipSemValidade = Color(0xFF374151);
}
