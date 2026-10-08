import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/entities/product.dart';

class ProductsRemoteDatasource {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  ProductsRemoteDatasource({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference get _col => _db.collection('products');

  Stream<List<Product>> watchProducts() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Product.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    // Força busca no servidor para garantir dado fresco.
    // Sem Source.server o Firestore pode retornar o cache local (stale) que
    // ainda não tem um produto recém-cadastrado → resultado null incorreto.
    // Fallback para cache quando offline / timeout de rede.
    QuerySnapshot snap;
    try {
      snap = await _col
          .where('barcode', isEqualTo: barcode)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      // Offline ou erro de rede — usa cache local como fallback
      try {
        snap = await _col
            .where('barcode', isEqualTo: barcode)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get(const GetOptions(source: Source.cache));
      } catch (_) {
        return null;
      }
    }
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Product.fromMap(d.data() as Map<String, dynamic>, d.id);
  }

  Future<Product?> getProductById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Product.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<String> saveProduct(Product product, {File? imageFile}) async {
    String? imageUrl = product.imageUrl;

    if (imageFile != null) {
      final ext = imageFile.path.split('.').last;
      final tmpId = product.id.isNotEmpty
          ? product.id
          : 'tmp_${DateTime.now().millisecondsSinceEpoch}';
      final ref = _storage.ref('products/$tmpId/foto.$ext');
      final task = await ref.putFile(imageFile);
      imageUrl = await task.ref.getDownloadURL();
    }

    final p = imageUrl != null ? product.copyWith(imageUrl: imageUrl) : product;

    if (product.id.isEmpty) {
      final docRef = await _col.add(p.toMap());
      // Se a imagem foi enviada com id temporário, re-sobe com id real
      if (imageFile != null) {
        final ext = imageFile.path.split('.').last;
        final newRef = _storage.ref('products/${docRef.id}/foto.$ext');
        final task = await newRef.putFile(imageFile);
        final finalUrl = await task.ref.getDownloadURL();
        await docRef.update({'imageUrl': finalUrl});
      }
      return docRef.id;
    }
    await _col.doc(product.id).set(p.toMap());
    return product.id;
  }

  Future<void> updateImageUrl(String productId, String imageUrl) async {
    await _col.doc(productId).update({'imageUrl': imageUrl});
  }

  Future<void> deleteProduct(String id) async {
    await _col.doc(id).update({'isActive': false});
  }

  /// Cria múltiplos produtos em lote usando WriteBatch.
  /// Retorna a lista de IDs criados.
  Future<List<String>> batchCreateProducts(List<Product> products) async {
    const chunkSize = 400; // Firestore limite: 500 ops por batch
    final ids = <String>[];
    for (var i = 0; i < products.length; i += chunkSize) {
      final chunk = products.sublist(
          i, (i + chunkSize).clamp(0, products.length));
      final batch = _db.batch();
      for (final p in chunk) {
        final ref = _col.doc();
        batch.set(ref, p.copyWith().toMap()
          ..['createdAt'] = DateTime.now().toIso8601String());
        ids.add(ref.id);
      }
      await batch.commit();
    }
    return ids;
  }
}
