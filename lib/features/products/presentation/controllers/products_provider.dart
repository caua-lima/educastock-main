import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/products_remote_datasource.dart';
import '../../domain/entities/product.dart';

final productsDatasourceProvider = Provider<ProductsRemoteDatasource>(
  (_) => ProductsRemoteDatasource(),
);

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productsDatasourceProvider).watchProducts();
});

// autoDispose garante que o cache é descartado quando o widget sai da tela.
// Sem isso, um resultado null (produto não encontrado) ficaria em cache
// permanentemente — mesmo depois de cadastrar o produto e escanear novamente.
final productByBarcodeProvider =
    FutureProvider.autoDispose.family<Product?, String>((ref, barcode) async {
  return ref.watch(productsDatasourceProvider).getProductByBarcode(barcode);
});

final productByIdProvider =
    FutureProvider.family<Product?, String>((ref, id) async {
  // Reaproveita o cache do StreamProvider da lista — evita round-trip ao Firestore
  // ao abrir a página de detalhe vindo do Estoque (produto já está em memória).
  final cached = ref.watch(productsProvider).valueOrNull;
  if (cached != null) {
    for (final p in cached) {
      if (p.id == id) return p;
    }
  }
  return ref.watch(productsDatasourceProvider).getProductById(id);
});

// Form notifier para criação/edição de produto
class ProductFormNotifier extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  Future<void> saveProduct(Product product, {File? imageFile}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(productsDatasourceProvider);
      return ds.saveProduct(product, imageFile: imageFile);
    });
  }
}

final productFormProvider =
    NotifierProvider<ProductFormNotifier, AsyncValue<String?>>(
        () => ProductFormNotifier());

// ─── CSV Batch Import ─────────────────────────────────────────────────────────

class _CsvImportState {
  final bool loading;
  final int total;
  final int done;
  final String? error;
  final bool success;

  const _CsvImportState({
    this.loading = false,
    this.total = 0,
    this.done = 0,
    this.error,
    this.success = false,
  });
  _CsvImportState copyWith({
    bool? loading,
    int? total,
    int? done,
    String? error,
    bool? success,
  }) =>
      _CsvImportState(
        loading: loading ?? this.loading,
        total: total ?? this.total,
        done: done ?? this.done,
        error: error ?? this.error,
        success: success ?? this.success,
      );
}

class CsvImportNotifier extends Notifier<_CsvImportState> {
  @override
  _CsvImportState build() => const _CsvImportState();

  Future<int> importFromCsvString(String csvContent, String createdBy) async {
    state = const _CsvImportState(loading: true);
    try {
      final lines = csvContent
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Skip header if present
      final dataLines = (lines.isNotEmpty &&
              lines.first
                  .toLowerCase()
                  .startsWith(RegExp(r'nome|name')))
          ? lines.sublist(1)
          : lines;

      state = state.copyWith(total: dataLines.length);

      final products = <Product>[];
      for (final line in dataLines) {
        final parts = _splitCsvLine(line);
        if (parts.length < 2) continue;
        final name = parts[0].trim();
        if (name.isEmpty) continue;
        final categoryRaw = parts.length > 1 ? parts[1].trim().toLowerCase() : '';
        final barcode = parts.length > 2 ? parts[2].trim() : null;
        final perishableRaw = parts.length > 3 ? parts[3].trim().toLowerCase() : '';
        final category = _parseCategory(categoryRaw);
        final isPerishable = perishableRaw == 'sim' ||
            perishableRaw == 'true' ||
            perishableRaw == 's' ||
            perishableRaw == '1' ||
            perishableRaw == 'yes';

        products.add(Product(
          id: '',
          name: name,
          category: category,
          unit: 'un',
          barcode: barcode?.isEmpty ?? true ? null : barcode,
          isPerishable: isPerishable,
          minimumStock: 0,
          createdAt: DateTime.now(),
          createdBy: createdBy,
        ));
      }

      if (products.isEmpty) {
        state = state.copyWith(
            loading: false, error: 'Nenhum produto válido encontrado no CSV.');
        return 0;
      }

      final ds = ref.read(productsDatasourceProvider);
      await ds.batchCreateProducts(products);

      state = _CsvImportState(
          loading: false, total: products.length, done: products.length, success: true);
      return products.length;
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
      return 0;
    }
  }

  void reset() => state = const _CsvImportState();

  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (final ch in line.runes) {
      final c = String.fromCharCode(ch);
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(sb.toString());
        sb.clear();
      } else {
        sb.write(c);
      }
    }
    result.add(sb.toString());
    return result;
  }

  static ProductCategory _parseCategory(String raw) {
    switch (raw) {
      case 'alimento':
      case 'alimentação':
      case 'food':
        return ProductCategory.alimento;
      case 'bebida':
      case 'drink':
        return ProductCategory.bebida;
      case 'limpeza':
      case 'cleaning':
        return ProductCategory.limpeza;
      case 'higiene':
      case 'higienepessoal':
      case 'higiene_pessoal':
      case 'higiene pessoal':
        return ProductCategory.higienePessoal;
      case 'escolar':
      case 'materialescolar':
        return ProductCategory.escolar;
      case 'roupas':
      case 'roupa':
        return ProductCategory.roupas;
      default:
        return ProductCategory.outro;
    }
  }
}

final csvImportProvider =
    NotifierProvider<CsvImportNotifier, _CsvImportState>(
        () => CsvImportNotifier());
