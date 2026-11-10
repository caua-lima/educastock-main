import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/open_food_facts_datasource.dart';

final openFoodFactsProvider = Provider<OpenFoodFactsDatasource>(
  (_) => OpenFoodFactsDatasource(),
);

/// Tempo máximo por base externa. Uma promessa que nunca termina vira
/// "consulta indisponível" em vez de prender a tela em "Consultando…".
final scannerLookupTimeoutProvider =
    Provider<Duration>((_) => const Duration(seconds: 12));

// ── Etapas de busca na web ─────────────────────────────────────────────────

enum WebSearchStep { idle, openFoodFacts, upcItemDb, barcodeLookup, done }

extension WebSearchStepX on WebSearchStep {
  String get label {
    switch (this) {
      case WebSearchStep.idle:
        return '';
      case WebSearchStep.openFoodFacts:
        return 'Open Food Facts';
      case WebSearchStep.upcItemDb:
        return 'UPC Item DB';
      case WebSearchStep.barcodeLookup:
        return 'Barcode Lookup';
      case WebSearchStep.done:
        return 'Concluído';
    }
  }

  double get progress {
    switch (this) {
      case WebSearchStep.idle:
        return 0.0;
      case WebSearchStep.openFoodFacts:
        return 0.2;
      case WebSearchStep.upcItemDb:
        return 0.55;
      case WebSearchStep.barcodeLookup:
        return 0.85;
      case WebSearchStep.done:
        return 1.0;
    }
  }
}

/// A consulta externa não pôde ser concluída (sem internet, serviço fora do ar
/// ou demora acima do limite). É diferente de "produto não encontrado": nesse
/// caso não dá para afirmar que o produto não existe nas bases.
class ScannerLookupUnavailable implements Exception {
  final String barcode;
  const ScannerLookupUnavailable(this.barcode);
  @override
  String toString() => 'Consulta indisponível para $barcode';
}

// ── Estado do scanner ──────────────────────────────────────────────────────

class ScannerState {
  final bool isScanning;
  final String? lastBarcode;
  final AsyncValue<ProductApiResult?> apiResult;
  final WebSearchStep searchStep;

  const ScannerState({
    this.isScanning = false,
    this.lastBarcode,
    this.apiResult = const AsyncValue.data(null),
    this.searchStep = WebSearchStep.idle,
  });

  ScannerState copyWith({
    bool? isScanning,
    String? lastBarcode,
    AsyncValue<ProductApiResult?>? apiResult,
    WebSearchStep? searchStep,
  }) =>
      ScannerState(
        isScanning: isScanning ?? this.isScanning,
        lastBarcode: lastBarcode ?? this.lastBarcode,
        apiResult: apiResult ?? this.apiResult,
        searchStep: searchStep ?? this.searchStep,
      );

  /// Há uma consulta em andamento para [barcode]?
  bool buscando(String barcode) =>
      lastBarcode == barcode &&
      searchStep != WebSearchStep.idle &&
      searchStep != WebSearchStep.done;
}

// ── Notifier ───────────────────────────────────────────────────────────────

/// Consulta externa do código lido/digitado.
///
/// Cada consulta recebe uma "geração". Depois de cada espera, só grava no
/// estado se ainda for a geração atual: uma resposta antiga (de outro código,
/// de antes de "Limpar" ou de depois de sair da tela) é descartada e nunca
/// associa o nome/foto de um código a outro.
class ScannerNotifier extends Notifier<ScannerState> {
  int _geracao = 0;
  Future<void>? _emAndamento;

  @override
  ScannerState build() {
    // Provider descartado (saiu do fluxo): nenhuma resposta pendente volta.
    ref.onDispose(() => _geracao++);
    return const ScannerState();
  }

  void startScanning() => state = state.copyWith(isScanning: true);
  void stopScanning() => state = state.copyWith(isScanning: false);

  /// Inicia (ou reaproveita) a consulta de [barcode].
  ///
  /// - Mesma consulta ainda em andamento: devolve a mesma (sem duplicar).
  /// - Mesmo código já encontrado: mantém o resultado (cache), a não ser que
  ///   [forcar] seja verdadeiro.
  /// - "Não encontrado" ou falha: consulta de novo.
  Future<void> onBarcodeDetected(String barcode, {bool forcar = false}) {
    final codigo = barcode.trim();
    if (codigo.isEmpty) return Future.value();
    if (!forcar && state.buscando(codigo) && _emAndamento != null) {
      return _emAndamento!;
    }
    final atual = state.apiResult.value;
    if (!forcar &&
        state.lastBarcode == codigo &&
        state.searchStep == WebSearchStep.done &&
        atual != null &&
        atual.found &&
        atual.barcode == codigo) {
      return Future.value();
    }
    final geracao = ++_geracao;
    final consulta = _consultar(codigo, geracao);
    _emAndamento = consulta;
    return consulta.whenComplete(() {
      if (identical(_emAndamento, consulta)) _emAndamento = null;
    });
  }

  /// Nova tentativa explícita (botão "Tentar novamente").
  Future<void> tentarNovamente() {
    final codigo = state.lastBarcode;
    if (codigo == null) return Future.value();
    return onBarcodeDetected(codigo, forcar: true);
  }

  bool _valida(int geracao) => geracao == _geracao;

  Future<void> _consultar(String barcode, int geracao) async {
    state = ScannerState(
      lastBarcode: barcode,
      isScanning: false,
      apiResult: const AsyncValue.loading(),
      searchStep: WebSearchStep.openFoodFacts,
    );
    final ds = ref.read(openFoodFactsProvider);
    final limite = ref.read(scannerLookupTimeoutProvider);
    var falhou = false;

    final etapas = <(WebSearchStep, Future<ProductApiResult?> Function())>[
      (WebSearchStep.openFoodFacts, () => ds.lookupOpenFoodFacts(barcode)),
      (WebSearchStep.upcItemDb, () => ds.lookupUpcItemDb(barcode)),
      (WebSearchStep.barcodeLookup, () => ds.lookupBarcodeLookupApi(barcode)),
    ];

    for (final (etapa, buscar) in etapas) {
      if (!_valida(geracao)) return;
      state = state.copyWith(searchStep: etapa);
      ProductApiResult? r;
      try {
        r = await buscar().timeout(limite);
      } catch (_) {
        // Rede, serviço fora do ar ou tempo esgotado: tenta a próxima base,
        // mas lembra que a ausência não é conclusiva.
        falhou = true;
      }
      if (!_valida(geracao)) return;
      // Resultado de outro código (fonte mal comportada) não é aceito.
      if (r != null && r.found && r.barcode == barcode) {
        state = state.copyWith(
          apiResult: AsyncValue.data(r),
          searchStep: WebSearchStep.done,
        );
        return;
      }
    }

    if (!_valida(geracao)) return;
    state = state.copyWith(
      apiResult: falhou
          ? AsyncValue.error(
              ScannerLookupUnavailable(barcode), StackTrace.current)
          : AsyncValue.data(ProductApiResult(barcode: barcode, found: false)),
      searchStep: WebSearchStep.done,
    );
  }

  /// Limpa o scanner e invalida qualquer consulta pendente.
  void reset() {
    _geracao++;
    _emAndamento = null;
    state = const ScannerState();
  }
}

final scannerProvider =
    NotifierProvider<ScannerNotifier, ScannerState>(() => ScannerNotifier());
