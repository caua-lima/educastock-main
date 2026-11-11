/// Textos da auditoria em português: nome da ação e o que mudou, sem mapas crus
/// ("{quantity: 0}") nem códigos internos ("donation_recebida").
library;

const _acoes = <String, String>{
  'entrada': 'Entrada registrada',
  'saida': 'Saída registrada',
  'ajustePositivo': 'Ajuste positivo',
  'ajusteNegativo': 'Ajuste negativo (baixa)',
  'descarte': 'Descarte registrado',
  'create': 'Cadastro criado',
  'update': 'Cadastro alterado',
  'delete': 'Cadastro excluído',
  'process': 'Processamento',
  'approval_granted': 'Ajuste aprovado',
  'approval_rejected': 'Ajuste rejeitado',
  'donation_aprovada': 'Doação aprovada',
  'donation_recusada': 'Doação recusada',
  'donation_recebida': 'Doação recebida',
  'donation_recebida_parcial': 'Doação recebida em parte',
  'donation_cancelada': 'Doação cancelada',
  'donation_expirada': 'Doação expirada',
  'donation_pendente': 'Doação registrada',
};

const _campos = <String, String>{
  'quantity': 'Quantidade',
  'status': 'Status',
  'reasonCode': 'Motivo',
  'role': 'Papel',
  'isActive': 'Ativo',
  'name': 'Nome',
  'category': 'Categoria',
  'expiryDate': 'Validade',
  'shelfLocation': 'Local',
  'batchNumber': 'Lote',
  'protocol': 'Protocolo',
};

const _valores = <String, String>{
  'disponivel': 'disponível',
  'distribuido': 'distribuído',
  'recebida_parcial': 'recebida em parte',
  'uso': 'uso',
  'avaria': 'avaria',
  'vencido': 'vencido',
  'admin': 'administrador',
  'voluntario': 'voluntário',
};

/// "donation_recebida" -> "Doação recebida"; código desconhecido vira texto legível.
String rotuloAcao(String acao) {
  final conhecido = _acoes[acao];
  if (conhecido != null) return conhecido;
  if (acao.isEmpty) return 'Operação';
  final texto = acao.replaceAll('_', ' ');
  return texto[0].toUpperCase() + texto.substring(1);
}

/// "Quantidade: de 0 para 13 · Status: de pendente para recebida". Vazio se não houver dados.
String descreverMudanca(Object? antes, Object? depois) {
  final a = antes is Map ? antes : const {};
  final d = depois is Map ? depois : const {};
  final chaves = <Object?>{...a.keys, ...d.keys}.where((k) => k != 'updatedAt').toList();
  final partes = <String>[];
  for (final k in chaves) {
    final campo = _campos[k] ?? '$k';
    final va = a.containsKey(k) ? _valor(a[k]) : null;
    final vd = d.containsKey(k) ? _valor(d[k]) : null;
    if (va != null && vd != null) {
      if (va == vd) continue;
      partes.add('$campo: de $va para $vd');
    } else {
      partes.add('$campo: ${vd ?? va}');
    }
  }
  return partes.join(' · ');
}

/// Um lado só (para a exportação): "Quantidade: 13 · Status: disponível".
String descreverMapa(Object? mapa) => descreverMudanca(null, mapa);

String _valor(Object? v) {
  if (v == null) return '—';
  if (v is bool) return v ? 'sim' : 'não';
  final s = '$v';
  return _valores[s] ?? s;
}
