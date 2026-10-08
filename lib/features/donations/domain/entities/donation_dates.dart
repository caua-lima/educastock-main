import 'package:cloud_firestore/cloud_firestore.dart';

/// Lê datas gravadas como `Timestamp` (Admin SDK / serverTimestamp) ou como
/// string ISO-8601 (padrão legado do app). Retorna null se ausente/inválida.
DateTime? parseDonationDate(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

Timestamp? toTimestamp(DateTime? date) =>
    date == null ? null : Timestamp.fromDate(date);
