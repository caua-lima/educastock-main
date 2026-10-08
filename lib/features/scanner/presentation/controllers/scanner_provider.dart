import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/open_food_facts_datasource.dart';

final openFoodFactsProvider = Provider<OpenFoodFactsDatasource>(
  (_) => OpenFoodFactsDatasource(),
);

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
}

// ── Notifier ───────────────────────────────────────────────────────────────

class ScannerNotifier extends Notifier<ScannerState> {
  @override
  ScannerState build() => const ScannerState();

  void startScanning() => state = state.copyWith(isScanning: true);
  void stopScanning() => state = state.copyWith(isScanning: false);

  Future<void> onBarcodeDetected(String barcode) async {
    // Não reinicia a busca se já está em andamento para o mesmo código
    if (state.lastBarcode == barcode &&
        state.searchStep != WebSearchStep.idle) return;

    state = state.copyWith(
      lastBarcode: barcode,
      isScanning: false,
      apiResult: const AsyncValue.loading(),
      searchStep: WebSearchStep.openFoodFacts,
    );

    final ds = ref.read(openFoodFactsProvider);

    try {
      // Etapa 1: Open Food Facts
      final off = await ds.lookupOpenFoodFacts(barcode);
      if (off != null && off.found) {
        state = state.copyWith(
          apiResult: AsyncValue.data(off),
          searchStep: WebSearchStep.done,
        );
        return;
      }

      // Etapa 2: UPCItemDB
      state = state.copyWith(searchStep: WebSearchStep.upcItemDb);
      final upc = await ds.lookupUpcItemDb(barcode);
      if (upc != null && upc.found) {
        state = state.copyWith(
          apiResult: AsyncValue.data(upc),
          searchStep: WebSearchStep.done,
        );
        return;
      }

      // Etapa 3: BarcodeLookup
      state = state.copyWith(searchStep: WebSearchStep.barcodeLookup);
      final bl = await ds.lookupBarcodeLookupApi(barcode);
      if (bl != null && bl.found) {
        state = state.copyWith(
          apiResult: AsyncValue.data(bl),
          searchStep: WebSearchStep.done,
        );
        return;
      }

      // Nenhuma fonte encontrou o produto
      state = state.copyWith(
        apiResult: AsyncValue.data(
            ProductApiResult(barcode: barcode, found: false)),
        searchStep: WebSearchStep.done,
      );
    } catch (_) {
      state = state.copyWith(
        apiResult: AsyncValue.data(
            ProductApiResult(barcode: barcode, found: false)),
        searchStep: WebSearchStep.done,
      );
    }
  }

  void reset() => state = const ScannerState();
}

final scannerProvider =
    NotifierProvider<ScannerNotifier, ScannerState>(() => ScannerNotifier());
