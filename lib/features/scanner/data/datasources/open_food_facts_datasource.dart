import 'package:dio/dio.dart';

class ProductApiResult {
  final String? name;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final String? description;
  final String barcode;
  final bool found;

  const ProductApiResult({
    this.name,
    this.brand,
    this.category,
    this.imageUrl,
    this.description,
    required this.barcode,
    required this.found,
  });
}

class OpenFoodFactsDatasource {
  static const _barcodeLookupApiKey =
      String.fromEnvironment('BARCODE_LOOKUP_API_KEY');

  final Dio _dio;
  final Dio _upcDio;
  final Dio _barcodeLookupDio;

  OpenFoodFactsDatasource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://world.openfoodfacts.org',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'User-Agent':
                    'EducaStock/1.0 (ONG Casa da Crianca; contact@casadacrianca.org.br)',
              },
            )),
        _upcDio = Dio(BaseOptions(
          baseUrl: 'https://api.upcitemdb.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )),
        _barcodeLookupDio = Dio(BaseOptions(
          baseUrl: 'https://api.barcodelookup.com',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  // ── Busca individual por fonte ─────────────────────────────────────────────

  Future<ProductApiResult?> lookupOpenFoodFacts(String barcode) async {
    try {
      final response = await _dio.get('/api/v0/product/$barcode.json');
      final data = response.data as Map<String, dynamic>;

      if (data['status'] == 1) {
        final product = data['product'] as Map<String, dynamic>;
        final name = _firstNonEmpty([
          product['product_name_pt'] as String?,
          product['product_name'] as String?,
          product['generic_name_pt'] as String?,
          product['generic_name'] as String?,
        ]);

        if (name != null && name.trim().isNotEmpty) {
          final brand = product['brands'] as String?;
          final categoryTags =
              (product['categories_tags'] as List?)?.cast<String>() ?? [];
          final category = _mapCategory(categoryTags);
          final imageUrl = product['image_front_url'] as String?;

          final genericName = _firstNonEmpty([
            product['generic_name_pt'] as String?,
            product['generic_name'] as String?,
          ]);
          return ProductApiResult(
            barcode: barcode,
            found: true,
            name: name,
            brand: brand?.split(',').first.trim(),
            category: category,
            imageUrl: imageUrl,
            description: (genericName != null && genericName != name)
                ? genericName
                : null,
          );
        }
      }
    } on DioException {
      // Network error — fall through
    }
    return null;
  }

  Future<ProductApiResult?> lookupUpcItemDb(String barcode) async {
    try {
      final response = await _upcDio.get(
        '/prod/trial/lookup',
        queryParameters: {'upc': barcode},
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      if (items.isNotEmpty) {
        final item = items.first as Map<String, dynamic>;
        final title = item['title'] as String?;
        final brand = item['brand'] as String?;
        final category = _normalizeCategory(item['category'] as String?);
        final imageUrl = item['images'] is List &&
                (item['images'] as List).isNotEmpty
            ? (item['images'] as List).first as String?
            : null;
        final desc = item['description'] as String?;
        return ProductApiResult(
          barcode: barcode,
          found: title != null && title.trim().isNotEmpty,
          name: title,
          brand: brand,
          category: category,
          imageUrl: imageUrl,
          description: (desc != null && desc.trim().isNotEmpty) ? desc.trim() : null,
        );
      }
    } on DioException {
      // Network error — fall through
    }
    return null;
  }

  Future<ProductApiResult?> lookupBarcodeLookupApi(String barcode) async {
    if (_barcodeLookupApiKey.isEmpty) return null;
    try {
      final response = await _barcodeLookupDio.get(
        '/v3/products',
        queryParameters: {
          'barcode': barcode,
          'formatted': 'y',
          'key': _barcodeLookupApiKey,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final products = (data['products'] as List?) ?? [];
      if (products.isNotEmpty) {
        final item = products.first as Map<String, dynamic>;
        final name = item['product_name'] as String?;
        final brand = item['brand'] as String?;
        final category = _normalizeCategory(item['category'] as String?);
        final imageUrl = item['images'] is List &&
                (item['images'] as List).isNotEmpty
            ? (item['images'] as List).first as String?
            : null;
        final desc = item['description'] as String?;
        return ProductApiResult(
          barcode: barcode,
          found: name != null && name.trim().isNotEmpty,
          name: name,
          brand: brand,
          category: category,
          imageUrl: imageUrl,
          description: (desc != null && desc.trim().isNotEmpty) ? desc.trim() : null,
        );
      }
    } on DioException {
      // Network error — fall through
    }
    return null;
  }

  // ── Busca completa com fallback (mantida para compatibilidade) ─────────────

  Future<ProductApiResult> lookupBarcode(String barcode) async {
    final off = await lookupOpenFoodFacts(barcode);
    if (off != null && off.found) return off;

    final upc = await lookupUpcItemDb(barcode);
    if (upc != null && upc.found) return upc;

    final bl = await lookupBarcodeLookupApi(barcode);
    if (bl != null && bl.found) return bl;

    return ProductApiResult(barcode: barcode, found: false);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  String? _mapCategory(List<String> tags) {
    for (final tag in tags) {
      if (tag.contains('beverages') || tag.contains('bebidas')) return 'bebida';
      if (tag.contains('food') ||
          tag.contains('aliment') ||
          tag.contains('foods')) return 'alimento';
    }
    return null;
  }

  String? _normalizeCategory(String? raw) {
    if (raw == null) return null;
    final c = raw.toLowerCase();
    if (c.contains('bebida') || c.contains('beverage')) return 'bebida';
    if (c.contains('food') || c.contains('alimento')) return 'alimento';
    if (c.contains('clean') || c.contains('limpeza')) return 'limpeza';
    if (c.contains('hygiene') || c.contains('higiene')) return 'higienePessoal';
    if (c.contains('school') || c.contains('escolar')) return 'escolar';
    return null;
  }
}
