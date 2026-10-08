class RecipeItem {
  final String productId;
  final String productName;
  final int quantity;

  const RecipeItem({
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory RecipeItem.fromMap(Map<String, dynamic> map) {
    return RecipeItem(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? 'Produto',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
      };
}

class StockRecipe {
  final String id;
  final String name;
  final String? description;
  final bool isPredefined;
  final bool isActive;
  final List<RecipeItem> items;
  final DateTime createdAt;
  final String createdBy;

  const StockRecipe({
    required this.id,
    required this.name,
    this.description,
    this.isPredefined = false,
    this.isActive = true,
    this.items = const [],
    required this.createdAt,
    required this.createdBy,
  });

  factory StockRecipe.fromMap(Map<String, dynamic> map, String id) {
    return StockRecipe(
      id: id,
      name: map['name'] as String? ?? 'Receita',
      description: map['description'] as String?,
      isPredefined: map['isPredefined'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      items: ((map['items'] as List?) ?? const [])
          .map((e) => RecipeItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'isPredefined': isPredefined,
        'isActive': isActive,
        'items': items.map((e) => e.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };
}
