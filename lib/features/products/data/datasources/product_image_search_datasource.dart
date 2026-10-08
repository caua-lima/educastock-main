import 'package:dio/dio.dart';

class ProductImageSearchDatasource {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'EducaStock/1.0 (ONG Casa da Crianca; flutter app)',
    },
  ));

  Future<List<String>> _searchByBarcode(String barcode) async {
    try {
      final res = await _dio
          .get('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
      final data = res.data as Map<String, dynamic>;
      if (data['status'] != 1) return [];

      final product = data['product'] as Map<String, dynamic>;
      final urls = <String>{};
      for (final field in [
        'image_front_url',
        'image_nutrition_url',
        'image_ingredients_url',
        'image_packaging_url',
      ]) {
        final u = product[field] as String?;
        if (u != null && u.isNotEmpty) urls.add(u);
      }
      return urls.toList();
    } on DioException {
      return [];
    }
  }

  Future<List<String>> _searchByName(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final res = await _dio.get(
        'https://world.openfoodfacts.org/cgi/search.pl',
        queryParameters: {
          'search_terms': query.trim(),
          'search_simple': '1',
          'action': 'process',
          'json': '1',
          'page_size': '12',
          'fields': 'image_front_url',
          'lc': 'pt',
          'cc': 'br',
        },
      );
      final data = res.data as Map<String, dynamic>;
      final products = (data['products'] as List?) ?? [];
      final urls = <String>[];
      for (final p in products) {
        final url =
            (p as Map<String, dynamic>)['image_front_url'] as String?;
        if (url != null && url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
          if (urls.length >= 8) break;
        }
      }
      return urls;
    } on DioException {
      return [];
    }
  }

  Future<List<String>> search({
    required String name,
    String? barcode,
  }) async {
    if (barcode != null && barcode.isNotEmpty) {
      final byBarcode = await _searchByBarcode(barcode);
      if (byBarcode.isNotEmpty) return byBarcode;
    }
    return _searchByName(name);
  }
}
