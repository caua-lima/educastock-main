import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/donor_profile.dart';

/// Acesso ao perfil do doador (`donors/{uid}`) — RF16 e RF17.
class DonorProfileDatasource {
  final FirebaseFirestore _db;

  DonorProfileDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('donors').doc(uid);

  Stream<DonorProfile?> watchProfile(String uid) {
    return _doc(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return null;
      return DonorProfile.fromMap(data, snap.id);
    });
  }

  Future<DonorProfile?> getProfile(String uid) async {
    final snap = await _doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return DonorProfile.fromMap(data, snap.id);
  }

  /// Cria o perfil se ainda não existir (login com Google no fluxo "Sou doador").
  /// Grava o consentimento dos termos; só deve ser chamado após o aceite.
  Future<void> ensureProfile({
    required String uid,
    required String displayName,
    DonorType donorType = DonorType.pf,
    String? phone,
    String? city,
  }) async {
    final snap = await _doc(uid).get();
    if (snap.exists) return;
    final profile = DonorProfile(
      uid: uid,
      displayName: displayName,
      donorType: donorType,
      phone: phone,
      city: city,
    );
    await _doc(uid).set(profile.toCreateMap());
  }

  Future<void> updateProfile(DonorProfile profile) {
    return _doc(profile.uid).update({
      'displayName': profile.displayName,
      'donorType': profile.donorType.value,
      'phone': profile.phone,
      'city': profile.city,
      'prefs': profile.prefs.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// RF17: registra o pedido de exclusão; a anonimização é feita por função (RN-D11).
  Future<void> requestDeletion(String uid) {
    return _doc(uid).update({
      'deletionRequestedAt': FieldValue.serverTimestamp(),
    });
  }
}
