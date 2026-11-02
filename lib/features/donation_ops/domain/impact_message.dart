/// Setores da instituição para onde uma doação pode ser destinada (tela S03).
const kDonationSectors = <String>[
  'Cozinha da Creche (Lanches)',
  'Refeitório (Almoço/Jantar)',
  'Cestas Básicas para Famílias',
  'Bazar Beneficente',
  'Higiene e Limpeza',
  'Material Escolar',
  'Outro destino',
];

/// Texto sugerido para a mensagem de impacto enviada ao doador. A equipe pode editar.
///
/// Só usa dados que o sistema conhece (nome do doador, itens e setor): não inventa
/// números como quantidade de crianças atendidas.
String buildImpactMessage({
  required String donorName,
  required List<String> itemDescriptions,
  required String sector,
}) {
  final firstName = donorName.trim().split(RegExp(r'\s+')).first;
  final greeting = firstName.isEmpty ? 'Olá' : firstName;
  final items = _joinItems(itemDescriptions);
  final where = _sectorPhrase(sector);
  return '$greeting, $items que você doou ${itemDescriptions.length > 1 ? 'foram' : 'foi'} '
      'destinado${itemDescriptions.length > 1 ? 's' : ''} $where. '
      'Muito obrigado por ajudar a Casa da Criança a cuidar de quem mais precisa!';
}

String _joinItems(List<String> items) {
  final clean = items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (clean.isEmpty) return 'o item';
  if (clean.length == 1) return 'o item "${clean.first}"';
  if (clean.length == 2) return 'os itens "${clean[0]}" e "${clean[1]}"';
  return 'os itens "${clean[0]}", "${clean[1]}" e mais ${clean.length - 2}';
}

String _sectorPhrase(String sector) {
  final s = sector.trim();
  if (s.isEmpty) return 'à instituição';
  return switch (s) {
    'Cozinha da Creche (Lanches)' => 'à Cozinha da Creche, para o preparo dos lanches',
    'Refeitório (Almoço/Jantar)' => 'ao Refeitório, para as refeições do dia a dia',
    'Cestas Básicas para Famílias' => 'às cestas básicas entregues às famílias atendidas',
    'Bazar Beneficente' => 'ao Bazar Beneficente da instituição',
    'Higiene e Limpeza' => 'ao uso em higiene e limpeza da instituição',
    'Material Escolar' => 'ao material escolar das crianças atendidas',
    _ => 'a $s',
  };
}
