/// Extrai datas de validade de textos lidos por OCR em embalagens brasileiras.
///
/// Formatos aceitos (separadores `/`, `-`, `.` ou espaço):
/// * `DD/MM/AAAA` e `DD/MM/AA`
/// * `MM/AAAA` e `MM/AA` (somente quando o texto traz VAL, VENC, EXP, VALIDADE etc.)
/// * `DD MMM AAAA`, `MMM/AAAA` e `MMM AA` com mês abreviado (JAN, FEV, MAR… ou
///   JAN, FEB, APR, AUG, DEC… em inglês)
///
/// Datas só com mês/ano usam o último dia do mês (a validade vale até o fim do mês).
/// Datas anteriores a hoje são ignoradas. O resultado vem sem repetições e em
/// ordem crescente.
library;

const _months = <String, int>{
  'JAN': 1,
  'FEV': 2,
  'FEB': 2,
  'MAR': 3,
  'ABR': 4,
  'APR': 4,
  'MAI': 5,
  'MAY': 5,
  'JUN': 6,
  'JUL': 7,
  'AGO': 8,
  'AUG': 8,
  'SET': 9,
  'SEP': 9,
  'OUT': 10,
  'OCT': 10,
  'NOV': 11,
  'DEZ': 12,
  'DEC': 12,
};

final _monthNames = _months.keys.join('|');

final _fullDate = RegExp(r'(?<!\d)(\d{1,2})\s*[/\-.\s]\s*(\d{1,2})\s*[/\-.\s]\s*(\d{4}|\d{2})(?!\d)');
final _dayMonthName = RegExp(
  '(?<!\\d)(\\d{1,2})\\s*[/\\-.\\s]?\\s*($_monthNames)[A-Z]*\\s*[/\\-.\\s]?\\s*(\\d{4}|\\d{2})(?!\\d)',
  caseSensitive: false,
);
final _monthNameYear = RegExp(
  '(?<![A-Z])($_monthNames)[A-Z]*\\s*[/\\-.\\s]\\s*(\\d{4}|\\d{2})(?!\\d)',
  caseSensitive: false,
);
final _monthYear = RegExp(r'(?<!\d)(\d{1,2})\s*[/\-.]\s*(\d{4})(?!\d)');
final _monthYearShort = RegExp(r'(?<!\d)(0[1-9]|1[0-2])\s*[/\-.]\s*(\d{2})(?!\d)');
final _keyword = RegExp(r'VAL|VENC|EXP|BEST|USE\s*BY|CONSUM', caseSensitive: false);

int _fullYear(String raw) {
  final y = int.parse(raw);
  return raw.length == 2 ? 2000 + y : y;
}

DateTime? _safeDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return null;
  final dt = DateTime(y, m, d);
  // Rejeita 31/02 e similares (o DateTime "rola" para o mês seguinte).
  if (dt.year != y || dt.month != m || dt.day != d) return null;
  return dt;
}

DateTime _endOfMonth(int y, int m) => DateTime(y, m + 1, 0);

/// Corrige confusões comuns do OCR entre letras e números dentro de trechos de data.
String _normalizeOcr(String text) {
  return text
      .replaceAllMapped(
        RegExp(r'(?<=\d)[Oo](?=\d)|(?<=[/\-.\s])[Oo](?=\d)|(?<=\d)[Oo](?=[/\-.\s])'),
        (_) => '0',
      )
      .replaceAllMapped(RegExp(r'(?<=\d)[lI|](?=\d)'), (_) => '1');
}

List<DateTime> extractExpiryDates(String text, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final limit = DateTime(today.year, today.month, today.day); // hoje ainda vale
  final src = _normalizeOcr(text);
  final hasKeyword = _keyword.hasMatch(src);
  final found = <DateTime>{};
  final consumed = <(int, int)>[];

  bool overlaps(int s, int e) => consumed.any((r) => s < r.$2 && e > r.$1);

  void add(RegExpMatch m, DateTime? dt) {
    if (dt == null) return;
    // Mesmo uma data já vencida "consome" o trecho, para não virar mês/ano depois.
    consumed.add((m.start, m.end));
    if (!dt.isBefore(limit)) found.add(dt);
  }

  for (final m in _fullDate.allMatches(src)) {
    add(m, _safeDate(_fullYear(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!)));
  }
  for (final m in _dayMonthName.allMatches(src)) {
    if (overlaps(m.start, m.end)) continue;
    final month = _months[m.group(2)!.toUpperCase()]!;
    add(m, _safeDate(_fullYear(m.group(3)!), month, int.parse(m.group(1)!)));
  }
  for (final m in _monthNameYear.allMatches(src)) {
    if (overlaps(m.start, m.end)) continue;
    final month = _months[m.group(1)!.toUpperCase()]!;
    final y = _fullYear(m.group(2)!);
    add(m, _endOfMonth(y, month));
  }
  for (final m in _monthYear.allMatches(src)) {
    if (overlaps(m.start, m.end)) continue;
    final mo = int.parse(m.group(1)!);
    if (mo < 1 || mo > 12) continue;
    add(m, _endOfMonth(int.parse(m.group(2)!), mo));
  }
  if (hasKeyword) {
    for (final m in _monthYearShort.allMatches(src)) {
      if (overlaps(m.start, m.end)) continue;
      add(m, _endOfMonth(2000 + int.parse(m.group(2)!), int.parse(m.group(1)!)));
    }
  }

  final list = found.toList()..sort();
  return list;
}
