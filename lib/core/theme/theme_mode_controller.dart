import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema escolhido (Claro, Escuro ou Sistema) — fonte única de estado.
///
/// A preferência é lida ANTES da primeira tela ([lerPreferencia] no `main`),
/// então não há clarão do tema errado na abertura. Se o controlador for criado
/// sem a preferência (testes, telas isoladas), ela é carregada em segundo
/// plano, mas nunca sobrescreve uma escolha feita nesse meio-tempo.
class ThemeModeController extends StateNotifier<ThemeMode> {
  static const themeModeKey = 'theme_mode';

  bool _escolhidoPelaPessoa = false;

  ThemeModeController({ThemeMode? inicial}) : super(inicial ?? ThemeMode.light) {
    if (inicial == null) _load();
  }

  static ThemeMode deTexto(String? raw) => switch (raw) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };

  static String paraTexto(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        ThemeMode.light => 'light',
      };

  /// Preferência gravada (Claro se nunca escolheu ou se o armazenamento falhar).
  static Future<ThemeMode> lerPreferencia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return deTexto(prefs.getString(themeModeKey));
    } catch (_) {
      return ThemeMode.light;
    }
  }

  Future<void> _load() async {
    final salvo = await lerPreferencia();
    // A pessoa já escolheu enquanto carregava (ou o controlador foi descartado):
    // a preferência antiga não volta por cima.
    if (_escolhidoPelaPessoa || !mounted) return;
    state = salvo;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _escolhidoPelaPessoa = true;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(themeModeKey, paraTexto(mode));
    } catch (_) {/* sem armazenamento: vale só nesta sessão */}
  }

  Future<void> toggleDark(bool enabled) async {
    await setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);
