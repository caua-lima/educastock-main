import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Item do histórico de códigos (escaneados ou digitados).
class ScanHistoryItem {
  final String code;
  final String source; // 'scanned' | 'typed'
  final DateTime scannedAt;

  const ScanHistoryItem({
    required this.code,
    required this.source,
    required this.scannedAt,
  });

  factory ScanHistoryItem.fromMap(Map<String, dynamic> map) {
    return ScanHistoryItem(
      code: map['code'] as String? ?? '',
      source: map['source'] as String? ?? 'scanned',
      scannedAt: DateTime.tryParse(map['scannedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Persiste o histórico de códigos lidos/digitados no Firestore, por usuário,
/// em `users/{uid}/scan_history/{code}`. Usar o próprio código como ID do
/// documento garante deduplicação automática (regravar atualiza o timestamp).
/// Subcoleção + orderBy num único campo dispensa índice composto.
class ScanHistoryRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ScanHistoryRepository({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static const _maxItems = 12;

  CollectionReference<Map<String, dynamic>>? get _col {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('scan_history');
  }

  /// Sanitiza o código para uso como ID de documento (sem '/').
  String _docId(String code) => code.trim().replaceAll(RegExp(r'[/\s]'), '_');

  /// Registra um código no histórico. [source] = 'scanned' ou 'typed'.
  /// Best-effort: falhas não devem quebrar o fluxo de scan/cadastro.
  Future<void> record(String code, {required String source}) async {
    final col = _col;
    final clean = code.trim();
    if (col == null || clean.isEmpty) return;
    try {
      await col.doc(_docId(clean)).set({
        'code': clean,
        'source': source,
        'scannedAt': DateTime.now().toIso8601String(),
      });
      await _trim(col);
    } catch (e) {
      debugPrint('[ScanHistory] record error: $e');
    }
  }

  /// Mantém apenas os [_maxItems] mais recentes (remove o excedente).
  Future<void> _trim(CollectionReference<Map<String, dynamic>> col) async {
    try {
      final snap = await col.orderBy('scannedAt', descending: true).get();
      if (snap.docs.length <= _maxItems) return;
      final batch = _db.batch();
      for (final doc in snap.docs.skip(_maxItems)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {
      // silencioso
    }
  }

  /// Lê os códigos mais recentes do usuário.
  Future<List<ScanHistoryItem>> getRecent() async {
    final col = _col;
    if (col == null) return const [];
    try {
      final snap = await col
          .orderBy('scannedAt', descending: true)
          .limit(_maxItems)
          .get();
      return snap.docs
          .map((d) => ScanHistoryItem.fromMap(d.data()))
          .toList();
    } catch (e) {
      debugPrint('[ScanHistory] getRecent error: $e');
      return const [];
    }
  }

  /// Stream em tempo real (atualiza chips automaticamente).
  Stream<List<ScanHistoryItem>> watchRecent() {
    final col = _col;
    if (col == null) return Stream.value(const []);
    return col
        .orderBy('scannedAt', descending: true)
        .limit(_maxItems)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ScanHistoryItem.fromMap(d.data())).toList());
  }

  /// Apaga todo o histórico do usuário.
  Future<void> clear() async {
    final col = _col;
    if (col == null) return;
    try {
      final snap = await col.get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ScanHistory] clear error: $e');
    }
  }
}

final scanHistoryRepositoryProvider = Provider<ScanHistoryRepository>(
  (_) => ScanHistoryRepository(),
);

/// Stream dos códigos recentes — usado para exibir os chips no modal.
final scanHistoryProvider = StreamProvider<List<ScanHistoryItem>>((ref) {
  return ref.watch(scanHistoryRepositoryProvider).watchRecent();
});
