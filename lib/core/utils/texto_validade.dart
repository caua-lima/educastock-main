/// Texto da validade a partir dos dias que faltam (negativo = já venceu).
///
/// "Venceu há 3 dias", "Venceu ontem", "Vence hoje", "Vence amanhã", "Vence em 5 dias":
/// nunca "Vence em -2 dia(s)".
String textoValidade(int dias) {
  if (dias < -1) return 'Venceu há ${-dias} dias';
  if (dias == -1) return 'Venceu ontem';
  if (dias == 0) return 'Vence hoje';
  if (dias == 1) return 'Vence amanhã';
  return 'Vence em $dias dias';
}

/// Versão curta para listas estreitas: "Venceu há 3d", "Vence hoje", "Vence em 5d".
String textoValidadeCurto(int dias) {
  if (dias < 0) return 'Venceu há ${-dias}d';
  if (dias == 0) return 'Vence hoje';
  return 'Vence em ${dias}d';
}

/// Para selos bem curtos ao lado da data: "venceu", "hoje", "5d" (nunca "-2d").
String diasCurtos(int dias) {
  if (dias < 0) return 'venceu';
  if (dias == 0) return 'hoje';
  return '${dias}d';
}
