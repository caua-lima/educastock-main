import 'package:cloud_firestore/cloud_firestore.dart';
import 'donation_dates.dart';

/// Versão vigente dos Termos de Uso / Política de Privacidade (gravada em
/// `consentAt` + `termsVersion`, RNF13).
const String kDonorTermsVersion = '2026-10';

enum DonorType {
  pf('pf', 'Pessoa física'),
  pj('pj', 'Pessoa jurídica');

  const DonorType(this.value, this.label);
  final String value;
  final String label;

  static DonorType fromValue(String? raw) =>
      DonorType.values.firstWhere((t) => t.value == raw, orElse: () => DonorType.pf);
}

/// Preferências do doador (RF17).
class DonorPrefs {
  /// Exibir "Doador anônimo" nas doações e agradecimentos.
  final bool anonimo;
  final bool notificacoes;

  const DonorPrefs({this.anonimo = false, this.notificacoes = true});

  factory DonorPrefs.fromMap(Map<String, dynamic>? map) => DonorPrefs(
        anonimo: map?['anonimo'] as bool? ?? false,
        notificacoes: map?['notificacoes'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'anonimo': anonimo,
        'notificacoes': notificacoes,
      };

  DonorPrefs copyWith({bool? anonimo, bool? notificacoes}) => DonorPrefs(
        anonimo: anonimo ?? this.anonimo,
        notificacoes: notificacoes ?? this.notificacoes,
      );
}

/// Perfil do doador — documento `donors/{uid}`.
class DonorProfile {
  final String uid;
  final String displayName;
  final DonorType donorType;
  final String? phone;
  final String? city;
  final DateTime? consentAt;
  final String termsVersion;
  final DonorPrefs prefs;
  final DateTime? deletionRequestedAt;

  const DonorProfile({
    required this.uid,
    required this.displayName,
    required this.donorType,
    this.phone,
    this.city,
    this.consentAt,
    this.termsVersion = kDonorTermsVersion,
    this.prefs = const DonorPrefs(),
    this.deletionRequestedAt,
  });

  bool get deletionRequested => deletionRequestedAt != null;

  /// Nome que vai para o `donorSnapshot` da doação (respeita o anonimato).
  String get publicName => prefs.anonimo ? 'Doador anônimo' : displayName;

  factory DonorProfile.fromMap(Map<String, dynamic> map, String uid) {
    return DonorProfile(
      uid: uid,
      displayName: map['displayName'] as String? ?? '',
      donorType: DonorType.fromValue(map['donorType'] as String?),
      phone: map['phone'] as String?,
      city: map['city'] as String?,
      consentAt: parseDonationDate(map['consentAt']),
      termsVersion: map['termsVersion'] as String? ?? kDonorTermsVersion,
      prefs: DonorPrefs.fromMap((map['prefs'] as Map?)?.cast<String, dynamic>()),
      deletionRequestedAt: parseDonationDate(map['deletionRequestedAt']),
    );
  }

  /// Payload de criação (RF16). `consentAt` usa o relógio do servidor.
  Map<String, dynamic> toCreateMap() => {
        'displayName': displayName,
        'donorType': donorType.value,
        'phone': phone,
        'city': city,
        'consentAt': FieldValue.serverTimestamp(),
        'termsVersion': termsVersion,
        'prefs': prefs.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      };

  DonorProfile copyWith({
    String? displayName,
    DonorType? donorType,
    String? phone,
    String? city,
    DonorPrefs? prefs,
  }) =>
      DonorProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        donorType: donorType ?? this.donorType,
        phone: phone ?? this.phone,
        city: city ?? this.city,
        consentAt: consentAt,
        termsVersion: termsVersion,
        prefs: prefs ?? this.prefs,
        deletionRequestedAt: deletionRequestedAt,
      );
}
