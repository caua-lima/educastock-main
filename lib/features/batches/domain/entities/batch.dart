enum BatchStatus { disponivel, reservado, distribuido, descartado, vencido }

class Batch {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final int initialQuantity;
  final DateTime? expiryDate;
  final bool noExpiry;
  final DateTime entryDate;
  final String origin; // doacao, compra, parceiro, transferencia
  final String? donor;
  final String? supplier;
  final double? unitPrice;
  final String? batchNumber; // número do lote impresso na embalagem
  final String? imageUrl;    // URL da foto do lote (Firebase Storage)
  final String? shelfLocation;
  final String? notes;
  final BatchStatus status;
  final String createdBy;
  final DateTime createdAt;

  const Batch({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.initialQuantity,
    this.expiryDate,
    this.noExpiry = false,
    required this.entryDate,
    required this.origin,
    this.donor,
    this.supplier,
    this.unitPrice,
    this.batchNumber,
    this.imageUrl,
    this.shelfLocation,
    this.notes,
    this.status = BatchStatus.disponivel,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isExpired {
    if (noExpiry || expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  int get daysToExpiry {
    if (noExpiry || expiryDate == null) return 9999;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  /// Retorna o nível de urgência para alertas
  /// 0=vencido, 1=crítico(<=7d), 2=atenção(<=30d), 3=ok, 4=sem validade
  int get expiryUrgency {
    if (noExpiry) return 4;
    if (isExpired) return 0;
    final days = daysToExpiry;
    if (days <= 7) return 1;
    if (days <= 30) return 2;
    return 3;
  }

  factory Batch.fromMap(Map<String, dynamic> map, String id) {
    return Batch(
      id: id,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: map['quantity'] as int,
      initialQuantity: map['initialQuantity'] as int,
      expiryDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'] as String)
          : null,
      noExpiry: map['noExpiry'] as bool? ?? false,
      entryDate: DateTime.parse(map['entryDate'] as String),
      origin: map['origin'] as String,
      donor: map['donor'] as String?,
      supplier: map['supplier'] as String?,
      unitPrice: (map['unitPrice'] as num?)?.toDouble(),
      batchNumber: map['batchNumber'] as String?,
      imageUrl: map['imageUrl'] as String?,
      shelfLocation: map['shelfLocation'] as String?,
      notes: map['notes'] as String?,
      status: BatchStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => BatchStatus.disponivel,
      ),
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'initialQuantity': initialQuantity,
        'expiryDate': expiryDate?.toIso8601String(),
        'noExpiry': noExpiry,
        'entryDate': entryDate.toIso8601String(),
        'origin': origin,
        'donor': donor,
        'supplier': supplier,
        'unitPrice': unitPrice,
        'batchNumber': batchNumber,
        'imageUrl': imageUrl,
        'shelfLocation': shelfLocation,
        'notes': notes,
        'status': status.name,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  Batch copyWith({
    int? quantity,
    BatchStatus? status,
    String? notes,
    String? shelfLocation,
    String? batchNumber,
    String? imageUrl,
    double? unitPrice,
  }) =>
      Batch(
        id: id,
        productId: productId,
        productName: productName,
        quantity: quantity ?? this.quantity,
        initialQuantity: initialQuantity,
        expiryDate: expiryDate,
        noExpiry: noExpiry,
        entryDate: entryDate,
        origin: origin,
        donor: donor,
        supplier: supplier,
        unitPrice: unitPrice ?? this.unitPrice,
        batchNumber: batchNumber ?? this.batchNumber,
        imageUrl: imageUrl ?? this.imageUrl,
        shelfLocation: shelfLocation ?? this.shelfLocation,
        notes: notes ?? this.notes,
        status: status ?? this.status,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}
