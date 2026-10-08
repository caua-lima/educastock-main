enum ProductCategory {
  alimento,
  bebida,
  limpeza,
  higienePessoal,
  escolar,
  roupas,
  outro,
}

class Product {
  final String id;
  final String name;
  final String? brand;
  final ProductCategory category;
  final String unit;
  final String? barcode;
  final String? imageUrl;
  final String? description;
  final bool isPerishable;
  final int minimumStock;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    this.brand,
    required this.category,
    required this.unit,
    this.barcode,
    this.imageUrl,
    this.description,
    required this.isPerishable,
    this.minimumStock = 0,
    required this.createdAt,
    required this.createdBy,
    this.isActive = true,
  });

  String get categoryLabel => switch (category) {
        ProductCategory.alimento => 'Alimento',
        ProductCategory.bebida => 'Bebida',
        ProductCategory.limpeza => 'Limpeza',
        ProductCategory.higienePessoal => 'Higiene Pessoal',
        ProductCategory.escolar => 'Material Escolar',
        ProductCategory.roupas => 'Roupas',
        ProductCategory.outro => 'Outro',
      };

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      category: ProductCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ProductCategory.outro,
      ),
      unit: map['unit'] as String,
      barcode: map['barcode'] as String?,
      imageUrl: map['imageUrl'] as String?,
      description: map['description'] as String?,
      isPerishable: map['isPerishable'] as bool? ?? true,
      minimumStock: map['minimumStock'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      createdBy: map['createdBy'] as String,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'brand': brand,
        'category': category.name,
        'unit': unit,
        'barcode': barcode,
        'imageUrl': imageUrl,
        'description': description,
        'isPerishable': isPerishable,
        'minimumStock': minimumStock,
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'isActive': isActive,
      };

  Product copyWith({
    String? name,
    String? brand,
    ProductCategory? category,
    String? unit,
    String? barcode,
    String? imageUrl,
    String? description,
    bool? isPerishable,
    int? minimumStock,
    bool? isActive,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        barcode: barcode ?? this.barcode,
        imageUrl: imageUrl ?? this.imageUrl,
        description: description ?? this.description,
        isPerishable: isPerishable ?? this.isPerishable,
        minimumStock: minimumStock ?? this.minimumStock,
        createdAt: createdAt,
        createdBy: createdBy,
        isActive: isActive ?? this.isActive,
      );
}
