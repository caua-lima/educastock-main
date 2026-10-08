/// Horário de funcionamento de um ponto de recebimento.
/// `weekday` segue `DateTime.weekday` (1 = segunda … 7 = domingo).
class PointHours {
  final int weekday;
  final String from; // "HH:mm"
  final String to; // "HH:mm"

  const PointHours({required this.weekday, required this.from, required this.to});

  factory PointHours.fromMap(Map<String, dynamic> map) => PointHours(
        weekday: (map['weekday'] as num?)?.toInt() ?? 1,
        from: map['from'] as String? ?? '08:00',
        to: map['to'] as String? ?? '17:00',
      );

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  int get fromMinutes => _minutes(from);
  int get toMinutes => _minutes(to);
}

/// Ponto de recebimento — documento `donation_points/{id}` (RF22).
class DonationPoint {
  final String id;
  final String name;
  final String address;
  final List<PointHours> hours;
  final String? contact;
  final String? instructions;
  final bool isActive;

  const DonationPoint({
    required this.id,
    required this.name,
    required this.address,
    this.hours = const [],
    this.contact,
    this.instructions,
    this.isActive = true,
  });

  factory DonationPoint.fromMap(Map<String, dynamic> map, String id) {
    final rawHours = (map['hours'] as List?) ?? const [];
    return DonationPoint(
      id: id,
      name: map['name'] as String? ?? 'Ponto de recebimento',
      address: map['address'] as String? ?? '',
      hours: rawHours
          .whereType<Map>()
          .map((e) => PointHours.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false),
      contact: map['contact'] as String?,
      instructions: map['instructions'] as String?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  /// Resumo curto dos horários para exibir ao doador.
  String get hoursSummary {
    if (hours.isEmpty) return 'Combine o horário com a equipe';
    const names = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return hours
        .map((h) => '${names[h.weekday.clamp(1, 7)]} ${h.from}–${h.to}')
        .join(' · ');
  }

  /// A janela (mesmo dia) precisa estar dentro do horário do ponto no dia da
  /// semana correspondente. Ponto sem horários cadastrados aceita qualquer janela.
  bool acceptsWindow(DateTime from, DateTime to) {
    if (hours.isEmpty) return true;
    if (from.year != to.year || from.month != to.month || from.day != to.day) {
      return false;
    }
    final fromMin = from.hour * 60 + from.minute;
    final toMin = to.hour * 60 + to.minute;
    return hours.any((h) =>
        h.weekday == from.weekday &&
        fromMin >= h.fromMinutes &&
        toMin <= h.toMinutes);
  }
}
