import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/donation.dart';
import '../../domain/entities/donation_point.dart';
import '../../domain/entities/donation_rules.dart';
import '../../domain/entities/donation_status.dart';

/// Doações (`donations`), pontos de recebimento (`donation_points`) e regras
/// (`settings/donation_rules`) — RF18, RF20, RF22 e RF24.
class DonationsRemoteDatasource {
  final FirebaseFirestore _db;

  DonationsRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _donations =>
      _db.collection('donations');
  CollectionReference<Map<String, dynamic>> get _points =>
      _db.collection('donation_points');

  /// Doações do doador, da mais recente para a mais antiga (índice
  /// `donorId ↑, createdAt ↓`).
  Stream<List<Donation>> watchByDonor(String donorId) {
    return _donations
        .where('donorId', isEqualTo: donorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Donation.fromMap(d.data(), d.id))
            .toList(growable: false));
  }

  Stream<Donation?> watchById(String id) {
    return _donations.doc(id).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return Donation.fromMap(data, snap.id);
    });
  }

  /// Registra a intenção com status inicial `pendente` (RF20).
  ///
  /// O ID do documento é gerado no cliente (`clientId`, uma vez por rascunho),
  /// o que torna o reenvio idempotente: se uma tentativa anterior chegou ao
  /// servidor, o novo `set` vira um update negado pelas regras, e então
  /// confirmamos que o documento já existe e tratamos como sucesso.
  Future<String> create(Donation donation, String clientId) async {
    final ref = _donations.doc(clientId);
    try {
      await ref.set(donation.toCreateMap());
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      final existing = await ref.get();
      if (!existing.exists) rethrow;
    }
    return clientId;
  }

  /// O doador só pode cancelar (regras limitam os campos alterados).
  Future<void> cancel(String donationId, {String? reason}) {
    return _donations.doc(donationId).update({
      'status': DonationStatus.cancelada.value,
      'cancelReason': reason ?? 'cancelada_pelo_doador',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Pontos ativos. O filtro `isActive == true` é exigido pelas regras.
  Stream<List<DonationPoint>> watchActivePoints() {
    return _points.where('isActive', isEqualTo: true).snapshots().map((snap) {
      final points =
          snap.docs.map((d) => DonationPoint.fromMap(d.data(), d.id)).toList();
      points.sort((a, b) => a.name.compareTo(b.name));
      return points;
    });
  }

  Stream<DonationRules> watchRules() {
    return _db
        .collection('settings')
        .doc('donation_rules')
        .snapshots()
        .map((snap) => DonationRules.fromMap(snap.data()));
  }
}
