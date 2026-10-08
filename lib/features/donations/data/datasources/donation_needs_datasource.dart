import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/donation_need.dart';

/// Necessidades ativas da ONG (`donation_needs`) — RF19.
class DonationNeedsDatasource {
  final FirebaseFirestore _db;

  DonationNeedsDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('donation_needs');

  /// Necessidades ativas ordenadas por prioridade (1 = crítica) e, em seguida,
  /// pelas atualizadas mais recentemente. Usa o índice composto
  /// `isActive ↑, priorityRank ↑, updatedAt ↓`. O filtro `isActive == true` é
  /// obrigatório: as regras só liberam ao doador as necessidades ativas.
  Stream<List<DonationNeed>> watchActiveNeeds() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('priorityRank')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DonationNeed.fromMap(d.data(), d.id))
            .toList(growable: false));
  }

  Future<DonationNeed?> getNeedById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return DonationNeed.fromMap(data, doc.id);
  }
}
