import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/storage_location.dart';

class LocationsRemoteDatasource {
  final FirebaseFirestore _db;

  LocationsRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('storage_locations');

  Stream<List<StorageLocation>> watchActiveLocations() {
    return _col
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => StorageLocation.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => a.label.compareTo(b.label));
      return list;
    });
  }

  Future<String> createLocation({
    String? locationName,
    required String shelf,
    required String level,
    int? productsPerLevel,
  }) async {
    final normalized = _normalizedKey(
      locationName: locationName,
      shelf: shelf,
      level: level,
    );

    final existing = await _col
        .where('normalizedKey', isEqualTo: normalized)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Esta localização já está cadastrada.');
    }

    final location = StorageLocation(
      id: '',
      locationName: _clean(locationName),
      section: '',
      shelf: shelf.trim(),
      level: level,
      room: null,
      productsPerLevel: productsPerLevel,
      isActive: true,
      createdAt: DateTime.now(),
      normalizedKey: normalized,
    );

    final ref = await _col.add(location.toMap());
    return ref.id;
  }

  /// Cria uma prateleira inteira com [levels] níveis de uma vez.
  /// Ex.: prateleira "A" com 5 níveis → cria A/1, A/2, … A/5.
  /// Pula níveis que já existirem. Retorna quantos foram criados.
  Future<int> createShelfWithLevels({
    required String shelf,
    required int levels,
    int? capacityPerLevel,
  }) async {
    var created = 0;
    for (var i = 1; i <= levels; i++) {
      final lvl = '$i';
      final normalized =
          _normalizedKey(locationName: null, shelf: shelf, level: lvl);
      final existing = await _col
          .where('normalizedKey', isEqualTo: normalized)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) continue;
      final location = StorageLocation(
        id: '',
        locationName: null,
        section: '',
        shelf: shelf.trim(),
        level: lvl,
        room: null,
        productsPerLevel: capacityPerLevel,
        isActive: true,
        createdAt: DateTime.now(),
        normalizedKey: normalized,
      );
      await _col.add(location.toMap());
      created++;
    }
    return created;
  }

  Future<void> deactivateLocation(String id) async {
    await _col.doc(id).update({'isActive': false});
  }

  String _normalizedKey({
    String? locationName,
    required String shelf,
    required String level,
  }) {
    String n(String? value) =>
        (value ?? '').trim().toLowerCase().replaceAll(' ', '');
    return '${n(locationName)}|${n(shelf)}|${n(level)}';
  }

  String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}
