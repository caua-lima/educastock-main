import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/batch.dart';

class BatchesRemoteDatasource {
  final FirebaseFirestore _db;

  BatchesRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection('batches');

  Stream<List<Batch>> watchBatchesByProduct(String productId) {
    return _col
        .where('productId', isEqualTo: productId)
        .where('status', isEqualTo: BatchStatus.disponivel.name)
        .orderBy('expiryDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Batch.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<List<Batch>> watchAllAvailableBatches() {
    return _col
        .where('status', isEqualTo: BatchStatus.disponivel.name)
        .where('quantity', isGreaterThan: 0)
        .snapshots()
        .map((snap) {
      final batches = snap.docs
          .map((d) => Batch.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      batches.sort((a, b) {
        if (a.noExpiry && b.noExpiry) return 0;
        if (a.noExpiry) return 1;
        if (b.noExpiry) return -1;
        if (a.expiryDate == null && b.expiryDate == null) return 0;
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });
      return batches;
    });
  }

  Future<List<Batch>> getBatchesExpiringInDays(int days) async {
    final limit = DateTime.now().add(Duration(days: days));
    final snap = await _col
        .where('status', isEqualTo: BatchStatus.disponivel.name)
        .where('noExpiry', isEqualTo: false)
        .where('expiryDate',
            isLessThanOrEqualTo: limit.toIso8601String())
        .orderBy('expiryDate')
        .get();
    return snap.docs
        .map((d) => Batch.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<Batch?> getBatchById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Batch.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<String> saveBatch(Batch batch, {File? imageFile}) async {
    String? imagePath = batch.imageUrl;

    if (batch.id.isEmpty) {
      // Novo lote: cria primeiro, depois salva imagem com ID real
      final ref = await _col.add(batch.toMap());
      if (imageFile != null && !kIsWeb) {
        imagePath = await _saveImageLocally(imageFile, ref.id);
        await ref.update({'imageUrl': imagePath});
      }
      return ref.id;
    }

    // Edição
    if (imageFile != null && !kIsWeb) {
      imagePath = await _saveImageLocally(imageFile, batch.id);
    }
    final updated = imagePath != null ? batch.copyWith(imageUrl: imagePath) : batch;
    await _col.doc(batch.id).set(updated.toMap());
    return batch.id;
  }

  Future<void> updateBatchQuantity(
      String batchId, int newQuantity, BatchStatus status) async {
    await _col.doc(batchId).update({
      'quantity': newQuantity,
      'status': status.name,
    });
  }

  Future<void> deleteBatch(String batchId) async {
    await _col.doc(batchId).delete();
  }

  // Salva a imagem na pasta local do app e retorna o caminho absoluto.
  Future<String> _saveImageLocally(File imageFile, String batchId) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${dir.path}/batch_images');
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    final ext = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${batchId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final target = File('${imagesDir.path}/$fileName');
    await imageFile.copy(target.path);
    return target.path;
  }
}
