/// Respostas do assistente sem IA, usadas quando o app não tem a chave do Gemini.
///
/// Cobrem as dúvidas mais comuns com as mesmas regras do prompt do assistente
/// ([kAssistantSystemPrompt]). Não inventam endereço, horário nem estoque: mandam o
/// doador para a tela certa. [maisPrecisados] traz as necessidades abertas do app,
/// já em texto (ex.: "Leite UHT integral: faltam 240 un (prioridade Crítica)").
String respostaLocal(String pergunta, {List<String> maisPrecisados = const []}) {
  final p = _normalizar(pergunta);
  bool tem(List<String> termos) => termos.any(p.contains);

  if (tem(['dinheiro', 'pix', 'deposit', 'transferen', 'conta bancaria', 'dados bancarios', 'banco do brasil', 'contribui'])) {
    return 'Dá sim! A doação em dinheiro vai para a conta da Casa da Criança no Banco do Brasil: '
        'agência 0171-6, conta corrente 12955-0, favorecido Casa da Criança Celencina Caldas Sarkis '
        '(CNPJ 49.917.651/0001-30). Não há chave PIX publicada. Em caso de dúvida, ligue (19) 3863-0229.';
  }
  if (tem(['senha', 'cartao', 'cpf', 'rg ', 'documento'])) {
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
  if (tem(['horario', 'que horas', ' abre', 'fecha', 'funcionamento'])) {
    return 'A Casa da Criança não publica o horário de funcionamento. Antes de ir até lá, ligue para '
        '(19) 3863-0229. Para entregar uma doação, siga a janela de dias que aparece na sua doação, '
        'na aba "Doações".';
  }
  if (tem(['telefone', 'contato', 'ligar', 'falar com', 'whatsapp', 'email', 'e-mail', 'instagram', 'rede social'])) {
    return 'Fale com a Casa da Criança pelo telefone (19) 3863-0229. Nas redes sociais, procure '
        '@celencinacaldassarkis. Endereço: Rua Sílvio Galizoni, 238, Cubatão, Itapira - SP.';
  }
  if (tem(['endereco', 'onde fica', 'localiza', 'sede', ' cep'])) {
    return 'A sede da Casa da Criança fica na Rua Sílvio Galizoni, 238, bairro Cubatão, Itapira - SP '
        '(CEP 13972-340). Telefone: (19) 3863-0229. O ponto de entrega de cada doação aparece na tela da doação.';
  }
  if (tem(['historia', 'quem e', 'quem sao', 'sobre a casa', 'sobre a ong', 'fundad', 'quantas criancas',
      'o que a casa faz', 'o que voces fazem', 'missao', 'quem voces atendem'])) {
    return 'A Casa da Criança "Celencina Caldas Sarkis" foi fundada em 27 de julho de 1945, em Itapira, '
        'e foi a primeira creche da cidade. Hoje atende cerca de 147 crianças e adolescentes de 4 a 15 anos '
        'no período contrário ao da escola, com atividades educacionais, culturais e esportivas e o projeto '
        '"Afetividade e Moralidade". Missão: educar crianças através da moralidade, para que se tornem cidadãos.';
  }
  if (tem(['oleo', 'bazar', 'voluntari', 'outra forma', 'ajudar de outro'])) {
    return 'Além das doações pelo app, dá para ajudar levando óleo de cozinha usado (projeto da Casa desde 2007), '
        'participando do bazar (móveis, antiguidades, roupas e artesanato) ou doando em dinheiro. '
        'Para combinar, ligue (19) 3863-0229.';
  }
  if (tem(['entreg', 'onde', 'levar', 'ponto', 'local'])) {
    return 'O ponto de entrega, a janela de dias e as instruções aparecem no formulário de doação '
        '(passo "Entrega") e na tela de acompanhamento da doação. Na entrega, mostre o QR Code da doação '
        'para a equipe conferir. A sede fica na Rua Sílvio Galizoni, 238, Cubatão, Itapira - SP.';
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
      'entrega, acompanhamento da doação e informações sobre a Casa da Criança (endereço, contato e '
      'história). Para outros assuntos, ligue para a Casa da Criança: (19) 3863-0229.';
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
