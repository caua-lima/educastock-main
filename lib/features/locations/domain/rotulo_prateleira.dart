/// Rótulo da prateleira: "1" ou "A" viram "Prat. 1" / "Prat. A"; um nome já completo
/// ("Prateleira A", "Estante 3", "Porta") fica como está.
String rotuloPrateleira(String shelf) {
  final s = shelf.trim();
  if (s.isEmpty) return '';
  return s.length <= 2 ? 'Prat. $s' : s;
}
