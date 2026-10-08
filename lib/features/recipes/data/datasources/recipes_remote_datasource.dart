import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../stock/domain/entities/stock_movement.dart';
import '../../domain/entities/stock_recipe.dart';

class RecipesRemoteDatasource {
  final FirebaseFirestore _db;

  RecipesRemoteDatasource({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _recipes => _db.collection('recipes');
  CollectionReference<Map<String, dynamic>> get _runs => _db.collection('recipe_runs');
  CollectionReference<Map<String, dynamic>> get _movements => _db.collection('stock_movements');

  Future<void> ensureSeedTemplates({required String userId}) async {
    final snap = await _recipes.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final now = DateTime.now().toIso8601String();
    final seed = [
      {
        'name': 'Kit Lanche',
        'description': 'Modelo rápido para distribuição de lanche',
      },
      {
        'name': 'Kit Higiene',
        'description': 'Modelo rápido para itens de higiene',
      },
      {
        'name': 'Cesta Básica',
        'description': 'Modelo rápido para montagem de cestas',
      },
    ];

    final batch = _db.batch();
    for (final item in seed) {
      final ref = _recipes.doc();
      batch.set(ref, {
        ...item,
        'isPredefined': true,
        'isActive': true,
        'items': const [],
        'createdAt': now,
        'createdBy': userId,
      });
    }
    await batch.commit();
  }

  Stream<List<StockRecipe>> watchRecipes() {
    return _recipes
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => StockRecipe.fromMap(d.data(), d.id)).toList());
  }

  Future<String> saveRecipe(StockRecipe recipe) async {
    if (recipe.id.isEmpty) {
      final ref = await _recipes.add(recipe.toMap());
      return ref.id;
    }
    await _recipes.doc(recipe.id).set(recipe.toMap());
    return recipe.id;
  }

  Future<void> deactivateRecipe(String id) {
    return _recipes.doc(id).set({'isActive': false}, SetOptions(merge: true));
  }

  Future<void> executeRecipe({
    required StockRecipe recipe,
    required String userId,
    required String userName,
  }) async {
    if (recipe.items.isEmpty) {
      throw Exception('A receita não possui itens.');
    }

    final plannedUpdates = <Map<String, dynamic>>[];

    for (final item in recipe.items) {
      final batchesSnap = await _db
          .collection('batches')
          .where('productId', isEqualTo: item.productId)
          .where('status', isEqualTo: 'disponivel')
          .get();

      final docs = batchesSnap.docs.toList();
      docs.sort((a, b) {
        final ad = DateTime.tryParse((a.data()['expiryDate'] as String?) ?? '9999-12-31') ?? DateTime(9999);
        final bd = DateTime.tryParse((b.data()['expiryDate'] as String?) ?? '9999-12-31') ?? DateTime(9999);
        final an = a.data()['noExpiry'] as bool? ?? false;
        final bn = b.data()['noExpiry'] as bool? ?? false;
        if (an && bn) return 0;
        if (an) return 1;
        if (bn) return -1;
        return ad.compareTo(bd);
      });

      final totalAvailable = docs.fold<int>(0, (acc, d) => acc + ((d.data()['quantity'] as num?)?.toInt() ?? 0));
      if (totalAvailable < item.quantity) {
        throw Exception('Estoque insuficiente para ${item.productName}. Disponível: $totalAvailable, necessário: ${item.quantity}.');
      }

      var remaining = item.quantity;
      for (final doc in docs) {
        if (remaining <= 0) break;
        final before = (doc.data()['quantity'] as num?)?.toInt() ?? 0;
        if (before <= 0) continue;
        final consume = before >= remaining ? remaining : before;
        final after = before - consume;
        remaining -= consume;
        plannedUpdates.add({
          'doc': doc,
          'consumed': consume,
          'before': before,
          'after': after,
          'productName': item.productName,
          'productId': item.productId,
        });
      }
    }

    final batch = _db.batch();
    final now = DateTime.now();

    for (final p in plannedUpdates) {
      final doc = p['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
      final consumed = p['consumed'] as int;
      final before = p['before'] as int;
      final after = p['after'] as int;
      final productName = p['productName'] as String;
      final productId = p['productId'] as String;

      batch.update(doc.reference, {
        'quantity': after,
        if (after <= 0) 'status': 'distribuido',
      });

      final movRef = _movements.doc();
      batch.set(movRef, {
        'productId': productId,
        'productName': productName,
        'batchId': doc.id,
        'type': MovementType.saida.name,
        'quantity': consumed,
        'reasonCode': MovementReasonCode.receita.name,
        'reason': 'Consumo por receita: ${recipe.name}',
        'activity': recipe.name,
        'performedBy': userId,
        'performedByName': userName,
        'performedAt': now.toIso8601String(),
        'isPendingSync': false,
        'auditBefore': {'quantity': before, 'status': doc.data()['status']},
        'auditAfter': {
          'quantity': after,
          'status': after <= 0 ? 'distribuido' : doc.data()['status'],
          'reasonCode': MovementReasonCode.receita.name,
          'recipeId': recipe.id,
          'recipeName': recipe.name,
        },
      });
    }

    final runRef = _runs.doc();
    batch.set(runRef, {
      'recipeId': recipe.id,
      'recipeName': recipe.name,
      'totalItems': recipe.items.length,
      'totalQuantityMoved': plannedUpdates.fold<int>(0, (acc, e) => acc + (e['consumed'] as int)),
      'performedBy': userId,
      'performedByName': userName,
      'performedAt': now.toIso8601String(),
    });

    await batch.commit();
  }
}
