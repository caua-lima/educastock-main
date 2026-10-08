enum MovementType {
  entrada,
  saida,
  ajustePositivo,
  ajusteNegativo,
  descarte,
}

enum MovementReasonCode {
  uso,
  validade,
  avaria,
  receita,
  ajusteInventario,
  doacao,
  outro,
}

class StockMovement {
  final String id;
  final String productId;
  final String productName;
  final String batchId;
  final MovementType type;
  final int quantity;
  final String? reasonCode;
  final String? reason;
  final String? activity;
  final String performedBy;
  final String performedByName;
  final DateTime performedAt;
  final bool isPendingSync;
  final Map<String, dynamic>? auditBefore;
  final Map<String, dynamic>? auditAfter;

  const StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.batchId,
    required this.type,
    required this.quantity,
    this.reasonCode,
    this.reason,
    this.activity,
    required this.performedBy,
    required this.performedByName,
    required this.performedAt,
    this.isPendingSync = false,
    this.auditBefore,
    this.auditAfter,
  });

  String get typeLabel => switch (type) {
        MovementType.entrada => 'Entrada',
        MovementType.saida => 'Saída',
        MovementType.ajustePositivo => 'Ajuste +',
        MovementType.ajusteNegativo => 'Ajuste -',
        MovementType.descarte => 'Descarte',
      };

  bool get isInbound =>
      type == MovementType.entrada || type == MovementType.ajustePositivo;

  factory StockMovement.fromMap(Map<String, dynamic> map, String id) {
    return StockMovement(
      id: id,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      batchId: map['batchId'] as String,
      type: MovementType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => MovementType.saida,
      ),
      quantity: map['quantity'] as int,
      reasonCode: map['reasonCode'] as String?,
      reason: map['reason'] as String?,
      activity: map['activity'] as String?,
      performedBy: map['performedBy'] as String,
      performedByName: map['performedByName'] as String,
      performedAt: DateTime.parse(map['performedAt'] as String),
      isPendingSync: map['isPendingSync'] as bool? ?? false,
      auditBefore: map['auditBefore'] as Map<String, dynamic>?,
      auditAfter: map['auditAfter'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'batchId': batchId,
        'type': type.name,
        'quantity': quantity,
        'reasonCode': reasonCode,
        'reason': reason,
        'activity': activity,
        'performedBy': performedBy,
        'performedByName': performedByName,
        'performedAt': performedAt.toIso8601String(),
        'isPendingSync': isPendingSync,
        'auditBefore': auditBefore,
        'auditAfter': auditAfter,
      };
}
