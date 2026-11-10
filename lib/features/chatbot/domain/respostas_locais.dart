/// Respostas do assistente sem IA, usadas quando o app não tem a chave do Gemini.
///
/// Cobrem as dúvidas mais comuns com as mesmas regras do prompt do assistente
/// ([kAssistantSystemPrompt]). Não inventam endereço, horário nem estoque: mandam o
/// doador para a tela certa. [maisPrecisados] traz as necessidades abertas do app,
/// já em texto (ex.: "Leite UHT integral: faltam 240 un (prioridade Crítica)").
String respostaLocal(String pergunta, {List<String> maisPrecisados = const []}) {
  final p = _normalizar(pergunta);
  bool tem(List<String> termos) => termos.any(p.contains);

  if (tem(['senha', 'cartao', 'cpf', 'rg ', 'documento', 'conta bancaria'])) {
    return 'Por segurança, não peço nem recebo senhas, cartões ou documentos. '
        'Para doar, basta usar o formulário "Quero doar" do aplicativo.';
  }
  if (tem(['precis', 'falta', 'prioridad', 'necessidade', 'mais ajuda', 'urgente'])) {
    if (maisPrecisados.isEmpty) {
      return 'O painel "Necessidades" mostra o que a Casa da Criança mais precisa agora, '
          'com a prioridade e a quantidade que ainda falta. Doar o que está lá é o que mais ajuda.';
    }
    return 'Agora a Casa da Criança mais precisa de:\n'
        '${maisPrecisados.map((n) => '- $n').join('\n')}\n'
        'Veja todos em "Necessidades" e toque em "Quero doar".';
  }
  if (tem(['validade', 'vencid', 'vence', 'vencimento', 'prazo'])) {
    return 'Itens perecíveis precisam ter data de validade, e itens vencidos não devem ser doados. '
        'Cada necessidade mostra no formulário a validade mínima recomendada; abaixo dela, a doação '
        'segue "sujeita a avaliação" da equipe. Prefira sempre validades longas.';
  }
  if (tem(['protocolo', 'status', 'acompanh', 'aprovad', 'pendente', 'cancel', 'recibo', 'qr', 'recusad'])) {
    return 'Cada doação ganha um protocolo (DOA-ANO-NÚMERO) e passa por Pendente, Aprovada e Recebida. '
        'Acompanhe na aba "Doações": depois da aprovação aparece o QR Code para mostrar na entrega. '
        'Você pode cancelar enquanto estiver Pendente ou Aprovada e, depois do recebimento, baixar o recibo em PDF.';
  }
  if (tem(['entreg', 'endereco', 'onde', 'horario', 'levar', 'ponto', 'local'])) {
    return 'O endereço, os horários e as instruções do ponto de entrega aparecem no formulário de doação '
        '(passo "Entrega") e na tela de acompanhamento da doação. Na entrega, mostre o QR Code da doação '
        'para a equipe conferir.';
  }
  if (tem(['como doar', 'como faco', 'como faço', 'quero doar', 'passo', 'como funciona'])) {
    return 'É rápido:\n'
        '- Abra "Necessidades" ou "Quero doar";\n'
        '- Informe o item, a quantidade e a validade;\n'
        '- Escolha o ponto e o dia de entrega;\n'
        '- Aceite os termos e envie.\n'
        'A equipe avalia e você acompanha tudo em "Doações".';
  }
  if (tem(['posso doar', 'aceit', 'o que doar', 'que tipo', 'roupa', 'aliment', 'limpeza', 'higiene',
      'escolar', 'brinquedo', 'movel', 'eletro'])) {
    return 'A Casa da Criança aceita alimentos, bebidas, produtos de limpeza, higiene pessoal, material '
        'escolar, roupas e outros itens úteis. O que está em "Necessidades" é o que mais ajuda agora, '
        'mas você também pode oferecer outro item: a equipe avalia.';
  }
  if (tem(['anonim', 'privacidade', 'meus dados', 'lgpd', 'excluir'])) {
    return 'Seus dados ficam visíveis só para você e para a equipe autorizada. Você pode doar de forma '
        'anônima (preferência no Perfil), baixar seus dados ou pedir a exclusão deles na mesma tela.';
  }
  if (tem(['obrigad', 'valeu'])) {
    return 'Eu que agradeço! Cada doação faz diferença para as crianças atendidas.';
  }
  if (tem(['oi', 'ola', 'bom dia', 'boa tarde', 'boa noite'])) {
    return 'Olá! Posso ajudar com o que doar, a validade dos itens, como doar, a entrega e o '
        'acompanhamento da sua doação.';
  }
  return 'Posso ajudar com: o que doar, o que a ONG mais precisa, validade dos itens, como doar, '
      'entrega e acompanhamento da doação. Para outros assuntos, fale com a equipe pelo canal oficial '
      'da Casa da Criança.';
}

String _normalizar(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final ch in texto.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    buffer.write(i >= 0 ? para[i] : ch);
  }
  return ' ${buffer.toString()} ';
}
