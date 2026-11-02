/// Dados de um relatório já prontos para exportar (PDF, Excel e CSV usam o mesmo modelo).
class ReportTable {
  final String title;
  final String? subtitle;

  /// Indicadores de topo (rótulo → valor), por exemplo "Lotes disponíveis" → "42".
  final Map<String, String> summary;
  final List<String> headers;
  final List<List<String>> rows;

  const ReportTable({
    required this.title,
    this.subtitle,
    this.summary = const {},
    required this.headers,
    required this.rows,
  });

  /// Nome de arquivo seguro: sem acentos, espaços nem símbolos.
  String fileBaseName([DateTime? now]) {
    final d = now ?? DateTime.now();
    final stamp =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return '${_slug(title)}_$stamp';
  }

  static String _slug(String text) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      buffer.write(i >= 0 ? to[i] : ch);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }
}
