import 'package:flutter/material.dart';

/// Tela carregada sob demanda (`import ... deferred as`).
///
/// Na web, o código das telas pesadas (Relatórios, IA, scanner, assistente) fica fora do
/// arquivo principal e só é baixado na primeira visita — o app abre mais rápido. No
/// celular o carregamento é imediato. Depois de carregada, a tela abre sem espera.
class DeferredPage extends StatefulWidget {
  /// Identificador da biblioteca (para lembrar o que já foi carregado).
  final String id;
  final Future<void> Function() load;
  final Widget Function() builder;

  const DeferredPage({
    super.key,
    required this.id,
    required this.load,
    required this.builder,
  });

  static final Set<String> _loaded = {};

  /// A biblioteca da tela [id] já foi carregada? (usado pelos testes de layout para
  /// medir a tela de verdade, não a de "carregando").
  static bool estaCarregada(String id) => _loaded.contains(id);

  /// Marca a biblioteca como carregada (pré-carga feita fora da tela).
  static void marcarCarregada(String id) => _loaded.add(id);

  @override
  State<DeferredPage> createState() => _DeferredPageState();
}

class _DeferredPageState extends State<DeferredPage> {
  late Future<void> _future;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _error = null;
    _future = DeferredPage._loaded.contains(widget.id)
        ? Future<void>.value()
        : widget.load().then((_) => DeferredPage._loaded.add(widget.id));
    _future.catchError((Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DeferredPage._loaded.contains(widget.id)) return widget.builder();
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Não foi possível abrir esta tela. Verifique a internet e tente de novo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => setState(_start),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.error == null) {
          return widget.builder();
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
