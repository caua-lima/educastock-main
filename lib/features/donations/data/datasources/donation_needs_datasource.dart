import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/donation_need.dart';
import '../../domain/nova_necessidade.dart';

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

  /// Publica uma necessidade criada pela equipe (regra do banco: só administrador e
  /// estoquista). `updatedAt` é obrigatório: a lista do doador ordena por ele.
  Future<String> criarNecessidade(NovaNecessidade n,
      {required String criadoPor}) async {
    final doc = await _col.add({
      ...n.dados(criadoPor: criadoPor),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Tira a necessidade do portal (o banco não permite apagar: fica o histórico).
  Future<void> encerrarNecessidade(String id) => _col.doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<DonationNeed?> getNeedById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _col.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return DonationNeed.fromMap(data, doc.id);
  }
}
