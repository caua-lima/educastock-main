// Intenções do assistente do doador: frases de treino do classificador e a resposta de
// cada uma. As respostas usam só o que o app faz e os dados de [InfoOng]; nada é inventado.
import '../info_ong.dart';

/// Contexto da resposta: dados da ONG e as necessidades abertas (em texto).
class ContextoResposta {
  final InfoOng ong;
  final List<String> maisPrecisados;
  const ContextoResposta(
      {this.ong = InfoOng.padrao, this.maisPrecisados = const []});
}

class Intencao {
  final String id;
  final List<String> exemplos;
  final String Function(ContextoResposta c) responder;
  const Intencao(this.id, this.exemplos, this.responder);
}

String _horario(ContextoResposta c) {
  final o = c.ong;
  if (o.horarioFuncionamento.isNotEmpty) {
    return 'A Casa da Criança funciona ${o.horarioFuncionamento}.'
        '${o.horarioEntregas.isNotEmpty ? ' Doações são recebidas ${o.horarioEntregas}.' : ''}'
        ' Em feriados o horário pode mudar: se puder, ${o.ondePerguntar} antes de ir.';
  }
  return 'O horário de funcionamento ainda não foi informado pela Casa da Criança. '
      'Antes de ir até lá, ${o.ondePerguntar}. Para entregar uma doação, siga a janela de dias '
      'que aparece na sua doação, na aba "Doações".';
}

String _horarioEntrega(ContextoResposta c) {
  final o = c.ong;
  final janela =
      'Cada doação tem uma janela de dias para a entrega, que aparece no passo "Entrega" '
      'e na tela da doação, na aba "Doações".';
  if (o.horarioEntregas.isNotEmpty) {
    return 'As doações são recebidas ${o.horarioEntregas}. $janela';
  }
  if (o.horarioFuncionamento.isNotEmpty) {
    return '$janela A Casa da Criança funciona ${o.horarioFuncionamento}.';
  }
  return '$janela O horário de atendimento não foi informado: ${o.ondePerguntar} para confirmar.';
}

final List<Intencao> kIntencoes = [
  Intencao(
      'saudacao',
      [
        'oi',
        'olá',
        'ola tudo bem',
        'bom dia',
        'boa tarde',
        'boa noite',
        'e aí',
        'oi tudo bem?',
        'olá, preciso de ajuda',
        'oi assistente',
        'opa',
        'eae',
        'hello',
        'oii',
        'bom diaa',
        'oi, tudo bom?',
        'olá, boa tarde',
        'oi, quero tirar uma dúvida',
        'salve',
        'boa noite, tudo certo?',
      ],
      (c) =>
          'Olá! Sou o assistente da Casa da Criança. Posso ajudar com o horário, o endereço, '
          'o que doar, como doar, a entrega e o acompanhamento da sua doação. O que você quer saber?'),
  Intencao(
      'agradecimento',
      [
        'obrigado',
        'obrigada',
        'muito obrigado',
        'valeu',
        'agradeço',
        'brigado',
        'obg',
        'vlw',
        'obrigado pela ajuda',
        'ajudou muito, obrigada',
        'show, valeu',
        'perfeito, obrigado',
        'entendi, obrigado',
      ],
      (c) =>
          'Eu que agradeço! Cada doação faz diferença para as crianças da Casa da Criança. '
          'Se precisar de mais alguma coisa, é só perguntar.'),
  Intencao(
      'despedida',
      [
        'tchau',
        'até mais',
        'até logo',
        'falou',
        'até a próxima',
        'adeus',
        'tenha um bom dia',
        'fui',
        'flw',
        'até amanhã',
        'até breve',
        'obrigado, tchau',
        'era só isso, até mais',
        'tchauzinho',
      ],
      (c) =>
          'Até mais! Quando quiser doar ou tirar outra dúvida, é só voltar aqui.'),
  Intencao(
      'horario_funcionamento',
      [
        'qual o horário de funcionamento',
        'que horas abre',
        'que horas fecha',
        'qual o horário de vocês',
        'vocês abrem que horas',
        'até que horas funciona',
        'horário de atendimento',
        'abre no sábado',
        'funciona no domingo',
        'abre aos fins de semana',
        'qual horario de funcionamneto',
        'orario de funcionamento',
        'que horas posso ir aí',
        'vocês estão abertos agora',
        'a casa abre hoje',
        'funcionam em feriado',
        'qual o expediente',
        'horario de abertura',
        'que hora fecha a ong',
        'hora que abre',
      ],
      _horario),
  Intencao(
      'horario_entrega',
      [
        'qual horário para entregar a doação',
        'que horas posso levar a doação',
        'até que horas recebem doações',
        'qual o horário de receber doações',
        'quando posso entregar',
        'em que dia levo a doação',
        'qual a janela de entrega',
        'posso entregar no sábado',
        'horário para deixar as doações',
        'que dia vocês recebem doação',
        'prazo para entregar a doação',
      ],
      _horarioEntrega),
  Intencao(
      'endereco',
      [
        'onde fica',
        'qual o endereço',
        'qual o endereço da casa da criança',
        'onde vocês ficam',
        'como chego aí',
        'qual a localização',
        'em que bairro fica',
        'qual o cep',
        'endereço da ong',
        'onde é a sede',
        'fica em itapira',
        'qual rua',
        'como faço para chegar',
        'localização no mapa',
        'endereco',
      ],
      (c) => 'A ${c.ong.nome} fica na ${c.ong.endereco}. '
          'O ponto de entrega de cada doação também aparece na tela da doação.'),
  Intencao('contato', [
    'qual o telefone',
    'telefone de vocês',
    'como entro em contato',
    'tem whatsapp',
    'qual o whatsapp',
    'qual o e-mail',
    'email para contato',
    'quero falar com alguém',
    'falar com a equipe',
    'número para ligar',
    'como falo com a ong',
    'tem instagram',
    'redes sociais',
    'contato da casa da criança',
    'zap de vocês',
    'qual o whatsapp da ong',
    'como falo com vocês',
    'tem telefone',
    'qual o email da ong',
    'número de contato',
  ], (c) {
    final o = c.ong;
    final faltam = [
      if (o.whatsapp.isEmpty) 'WhatsApp',
      if (o.email.isEmpty) 'e-mail'
    ];
    return 'Fale com a Casa da Criança: ${o.contatos}.'
        '${o.redeSocial.isNotEmpty ? ' Nas redes sociais: ${o.redeSocial}.' : ''}'
        '${faltam.isNotEmpty ? ' ${faltam.join(' e ')} não ${faltam.length > 1 ? 'foram informados' : 'foi informado'}.' : ''}';
  }),
  Intencao('dinheiro', [
    'posso doar dinheiro',
    'como doar em dinheiro',
    'qual a conta bancária',
    'aceitam transferência',
    'quero fazer um depósito',
    'dados bancários',
    'como contribuir financeiramente',
    'doação em dinheiro',
    'tem conta no banco',
    'posso ajudar com dinheiro',
    'como faço uma doação financeira',
    'como faço transferência para vocês',
    'qual a conta da ong',
    'posso depositar um valor',
    'aceitam doação em dinheiro',
    'quero contribuir com dinheiro',
  ], (c) {
    final o = c.ong;
    final partes = <String>[];
    if (o.chavePix.isNotEmpty) partes.add('PIX: ${o.chavePix}');
    if (o.contaBancaria.isNotEmpty) partes.add('conta: ${o.contaBancaria}');
    if (partes.isEmpty) {
      return 'Para doar em dinheiro, ${o.ondePerguntar}: a equipe passa os dados.';
    }
    return 'Dá sim! ${partes.join('. ')}. Em caso de dúvida, ${o.ondePerguntar}.';
  }),
  Intencao('pix', [
    'qual a chave pix',
    'tem pix',
    'aceita pix',
    'posso mandar pix',
    'pix da ong',
    'chave pix de vocês',
    'doar por pix',
    'qual o pix de vocês',
    'vocês aceitam pix',
    'manda a chave pix',
    'como faço um pix para a ong',
    'pix para doação',
  ], (c) {
    final o = c.ong;
    if (o.chavePix.isNotEmpty) {
      return 'A chave PIX da Casa da Criança é ${o.chavePix}. Obrigado pela ajuda!';
    }
    return 'A Casa da Criança não informou uma chave PIX. Você pode doar pela conta bancária'
        '${o.contaBancaria.isNotEmpty ? ' (${o.contaBancaria})' : ''} ou ${o.ondePerguntar}.';
  }),
  Intencao(
      'historia',
      [
        'qual a história da casa da criança',
        'quando foi fundada',
        'quem fundou',
        'há quanto tempo existe',
        'me conta sobre a ong',
        'quem é a casa da criança',
        'o que é a casa da criança',
        'quem são vocês',
        'quantos anos tem a instituição',
        'quem foi celencina caldas sarkis',
        'fale sobre a instituição',
        'quando a ong foi fundada',
        'em que ano começou a casa da criança',
        'quem fundou a instituição',
        'a casa da criança é antiga',
        'conta a história de vocês',
        'em que ano a ong foi criada',
        'qual o ano de fundação',
        'desde quando a ong existe',
      ],
      (c) =>
          'A Casa da Criança "Celencina Caldas Sarkis" foi fundada em 27 de julho de 1945, em Itapira, '
          'por dona Celencina Caldas Sarkis, e foi a primeira creche da cidade. Está na sede atual desde 1979 '
          'e completou 80 anos em 2025.'),
  Intencao(
      'quem_atende',
      [
        'quem vocês atendem',
        'quantas crianças são atendidas',
        'qual a idade das crianças',
        'o que a ong faz',
        'que atividades as crianças fazem',
        'como funciona a casa da criança',
        'atendem adolescentes',
        'qual o trabalho de vocês',
        'qual a missão',
        'quantas crianças vocês ajudam',
        'é creche',
        'quais projetos vocês têm',
        'crianças de que idade',
        'qual a idade de quem é atendido',
        'faixa de idade das crianças',
        'atendem crianças pequenas',
        'quantas crianças são atendidas',
        'qual a idade das crianças atendidas',
        'que atividades as crianças fazem',
        'vocês atendem adolescentes',
        'quais projetos a ong tem',
      ],
      (c) =>
          'A Casa da Criança atende ${c.ong.publicoAtendido}, com atividades educacionais, culturais '
          'e esportivas e o projeto "Afetividade e Moralidade". A missão é educar crianças através da '
          'moralidade, para que se tornem cidadãos.'),
  Intencao(
      'o_que_doar',
      [
        'o que posso doar',
        'o que vocês aceitam',
        'quais itens aceitam',
        'aceitam alimentos',
        'posso doar roupas',
        'aceitam produtos de limpeza',
        'aceitam material escolar',
        'que tipo de doação vocês recebem',
        'posso doar higiene pessoal',
        'aceitam bebidas',
        'quais doações são aceitas',
        'posso doar fralda',
        'vocês aceitam roupa usada',
        'aceita brinquedo',
        'posso doar móveis',
        'o que dá pra doar',
        'que itens posso doar',
        'o que eu posso levar de doação',
        'que coisas vocês recebem',
        'posso doar roupa de criança',
        'aceitam material de higiene',
        'que tipos de itens vocês aceitam',
        'posso doar alimentos não perecíveis',
        'vocês aceitam produtos de limpeza usados em bom estado',
        'aceitam sabão e detergente',
        'posso doar escova de dente',
        'posso doar pasta de dente e papel higiênico',
      ],
      (c) =>
          'A Casa da Criança aceita alimentos, bebidas, produtos de limpeza, higiene pessoal, '
          'material escolar, roupas e outros itens úteis, novos ou usados em bom estado. O que está em '
          '"Precisa" é o que mais ajuda agora, mas você também pode oferecer outro item: a equipe avalia.'),
  Intencao('necessidades', [
    'do que vocês mais precisam',
    'o que está faltando',
    'qual a necessidade mais urgente',
    'o que precisa agora',
    'quais as prioridades',
    'o que é mais urgente',
    'o que falta na ong',
    'lista de necessidades',
    'o que vocês estão precisando',
    'qual item é prioridade',
  ], (c) {
    if (c.maisPrecisados.isEmpty) {
      return 'A aba "Precisa" mostra o que a Casa da Criança mais precisa agora, com a prioridade e a '
          'quantidade que falta. Doar o que está lá é o que mais ajuda.';
    }
    return 'Agora a Casa da Criança mais precisa de:\n${c.maisPrecisados.map((n) => '- $n').join('\n')}\n'
        'Veja todos em "Precisa" e toque em "Doar".';
  }),
  Intencao(
      'validade',
      [
        'qual a validade mínima',
        'posso doar alimento perto de vencer',
        'aceitam produto vencido',
        'qual o prazo de validade',
        'precisa ter validade',
        'quantos dias de validade',
        'alimento vencido pode',
        'validade mínima dos alimentos',
        'aceitam comida que vence semana que vem',
        'qual a validade mínima',
        'posso doar perto do vencimento',
        'aceitam produto vencendo',
        'validade curta pode',
        'quanto tempo de validade precisa',
      ],
      (c) =>
          'Itens perecíveis precisam ter data de validade, e itens vencidos não devem ser doados. '
          'Cada necessidade mostra a validade mínima recomendada; abaixo dela, a doação fica "sujeita a '
          'avaliação" da equipe. Prefira sempre validades longas.'),
  Intencao(
      'como_doar',
      [
        'como faço para doar',
        'como doar',
        'quero doar',
        'como funciona a doação',
        'passo a passo para doar',
        'como registro uma doação',
        'como faço uma doação pelo app',
        'quero ajudar como faço',
        'como posso ajudar',
        'onde clico para doar',
        'por onde começo para doar',
        'como inicio uma doação',
        'primeira vez doando, como faz',
        'como faço uma doação pelo app',
        'quais os passos para doar',
        'como começo a doar',
        'como cadastro minha doação',
        'me explica como doar',
      ],
      (c) =>
          'É rápido:\n- Toque em "Quero doar" (ou em "Doar" num item de "Precisa");\n'
          '- Informe o item, a quantidade e a validade;\n- Escolha o ponto e os dias de entrega;\n'
          '- Aceite os termos e envie.\nA equipe avalia e você acompanha tudo em "Doações".'),
  Intencao(
      'entrega',
      [
        'como funciona a entrega',
        'onde entrego a doação',
        'onde levo os itens',
        'como entrego',
        'qual o ponto de entrega',
        'preciso levar a doação',
        'o que mostro na entrega',
        'entrega da doação',
        'onde deixo as coisas doadas',
        'para onde levo as doações',
        'onde deixo os alimentos doados',
        'onde entrego as roupas',
        'onde deixo os itens',
        'onde entrego os alimentos',
        'qual o ponto de entrega',
        'pra onde levo a doação',
        'onde faço a entrega',
      ],
      (c) =>
          'O ponto de entrega, os dias e as instruções aparecem no passo "Entrega" do formulário e '
          'na tela da sua doação. Na entrega, mostre o QR Code da doação para a equipe conferir. '
          'A sede fica na ${c.ong.endereco}.'),
  Intencao(
      'retirada',
      [
        'vocês buscam em casa',
        'podem retirar a doação',
        'fazem coleta',
        'buscam a doação no meu endereço',
        'não consigo levar, vocês buscam',
        'tem retirada',
        'passam para pegar',
        'vocês vêm buscar',
        'dá pra buscarem aqui em casa',
        'tem como retirar no meu endereço',
        'vocês retiram doação',
        'não tenho como levar, podem pegar',
      ],
      (c) =>
          'O app não agenda retirada: a entrega é feita no ponto indicado na doação. Se não puder '
          'levar, ${c.ong.ondePerguntar} para combinar outra forma.'),
  Intencao(
      'acompanhamento',
      [
        'como acompanho minha doação',
        'qual o status da minha doação',
        'minha doação foi aprovada',
        'onde vejo meu protocolo',
        'o que significa pendente',
        'minha doação está pendente',
        'cadê minha doação',
        'como sei se aprovaram',
        'onde vejo minhas doações',
        'qual meu protocolo',
        'como vejo o status da doação',
        'minha doação foi aprovada?',
        'onde acompanho minha doação',
        'cadê a minha doação',
        'status da doação',
      ],
      (c) =>
          'Cada doação ganha um protocolo (DOA-ANO-NÚMERO) e passa por Pendente, Aprovada e Recebida. '
          'Acompanhe na aba "Doações": é lá que aparece o QR Code para mostrar na entrega.'),
  Intencao(
      'cancelar',
      [
        'como cancelo minha doação',
        'quero cancelar',
        'posso desistir da doação',
        'cancelar doação',
        'não vou conseguir entregar',
        'errei a doação, e agora',
        'como desfaço a doação',
        'quero cancelar minha doação',
        'como desisto da doação',
        'preciso desfazer a doação',
        'dá para cancelar depois de aprovada',
        'cancelar doação pendente',
      ],
      (c) =>
          'Você pode cancelar enquanto a doação estiver Pendente ou Aprovada: abra a doação na aba '
          '"Doações" e toque em "Cancelar doação".'),
  Intencao(
      'qr_code',
      [
        'onde está o qr code',
        'para que serve o qr code',
        'cadê o qr da doação',
        'preciso do qr code',
        'como mostro o qr',
        'o qr não aparece',
        'onde está o qr code da doação',
        'pra que serve o qr code',
        'como uso o qr code na entrega',
        'não acho o qr code',
        'qr code da doação',
      ],
      (c) =>
          'O QR Code fica na tela da sua doação, na aba "Doações". Mostre-o na entrega: a equipe lê '
          'o código no app ou digita o protocolo.'),
  Intencao(
      'recibo',
      [
        'como pego o recibo',
        'tem comprovante',
        'quero o recibo da doação',
        'emitem recibo',
        'baixar comprovante',
        'recibo em pdf',
        'nota da doação',
        'como sei para onde foi minha doação',
        'como baixo o recibo',
        'tem comprovante da doação',
        'onde pego o comprovante',
        'recibo da doação em pdf',
        'preciso do recibo',
      ],
      (c) =>
          'Depois que a doação é recebida, a equipe registra o destino dela. Você vê o impacto e '
          'baixa o recibo em PDF na tela da doação, na aba "Doações".'),
  Intencao(
      'anonimato',
      [
        'posso doar anônimo',
        'não quero aparecer',
        'doação anônima',
        'esconder meu nome',
        'meu nome aparece',
        'quero ficar anônimo',
        'posso doar sem me identificar',
        'quero que meu nome não apareça',
        'doar de forma anônima',
        'como fico anônimo',
        'dá pra esconder meu nome',
      ],
      (c) =>
          'Pode, sim: em "Perfil", ligue "Doar de forma anônima". A equipe e os agradecimentos '
          'passam a mostrar "Doador anônimo".'),
  Intencao(
      'privacidade',
      [
        'meus dados estão seguros',
        'quem vê meus dados',
        'como apago meus dados',
        'lgpd',
        'excluir minha conta',
        'baixar meus dados',
        'privacidade',
        'quero excluir meu cadastro',
        'quero excluir meus dados',
        'vocês compartilham meus dados',
        'meus dados ficam guardados',
        'como funciona a privacidade',
        'posso apagar minha conta',
      ],
      (c) =>
          'Seus dados ficam visíveis só para você e para a equipe autorizada. Em "Perfil" você pode '
          'baixar seus dados ou pedir a exclusão deles (LGPD).'),
  Intencao(
      'voluntariado',
      [
        'posso ser voluntário',
        'como faço para ser voluntária',
        'vocês precisam de voluntários',
        'quero ajudar como voluntário',
        'trabalho voluntário',
        'posso ajudar pessoalmente',
        'quero ser voluntário',
        'como faço para ser voluntária',
        'vocês precisam de voluntários',
        'posso trabalhar como voluntário',
        'quero ajudar como voluntário',
      ],
      (c) =>
          'Que bom que você quer ajudar! O voluntariado é combinado direto com a equipe: '
          '${c.ong.ondePerguntar}.'),
  Intencao(
      'oleo_bazar',
      [
        'aceitam óleo de cozinha',
        'onde levo óleo usado',
        'tem bazar',
        'como funciona o bazar',
        'posso doar para o bazar',
        'coleta de óleo',
        'reciclagem de óleo',
        'vocês recolhem óleo de cozinha usado',
        'tem bazar na ong',
        'posso doar coisas para o bazar',
        'onde descarto óleo usado',
        'vocês fazem bazar de roupas',
      ],
      (c) =>
          'A Casa da Criança recolhe óleo de cozinha usado (projeto desde 2007) e tem um bazar de '
          'móveis, antiguidades, roupas e artesanato. Para combinar, ${c.ong.ondePerguntar}.'),
  Intencao(
      'empresa',
      [
        'sou empresa, posso doar',
        'doação de pessoa jurídica',
        'minha empresa quer ajudar',
        'doação com cnpj',
        'empresa pode doar',
        'campanha na minha empresa',
        'sou empresa, posso doar',
        'como uma empresa faz doação',
        'doação de cnpj',
        'minha loja pode doar',
        'empresa pode se cadastrar como doadora',
      ],
      (c) =>
          'Pode sim! No "Perfil", escolha "Pessoa jurídica" e informe a razão social. A doação segue '
          'o mesmo caminho pelo app. Para campanhas ou volumes grandes, ${c.ong.ondePerguntar}.'),
  Intencao(
      'conta',
      [
        'esqueci minha senha',
        'não consigo entrar',
        'como troco a senha',
        'não recebi o email de verificação',
        'meu email não foi verificado',
        'como verifico meu email',
        'problema no login',
        'não lembro minha senha',
        'como troco minha senha',
        'não consigo fazer login',
        'minha conta está bloqueada',
        'como recupero minha conta',
      ],
      (c) =>
          'Para entrar de novo, use "Esqueci" na tela de login. Para trocar a senha, vá em "Perfil" › '
          '"Trocar senha". Para doar, o e-mail precisa estar verificado: confira o link na sua caixa de entrada.'),
  Intencao(
      'dados_sensiveis',
      [
        'posso mandar meu cpf',
        'quer o número do meu cartão',
        'vou passar minha senha',
        'meu rg é',
        'te mando os dados do cartão',
        'preciso informar documento',
        'vou mandar o número do meu cartão',
        'posso te passar minha senha',
        'meu cpf é',
        'aqui está meu documento',
        'anota meus dados bancários',
      ],
      (c) =>
          'Por segurança, não peço nem recebo senhas, cartões ou documentos. Para doar, basta usar '
          'o formulário "Quero doar".'),
  Intencao(
      'nao_aceitos',
      [
        'o que vocês não aceitam',
        'aceitam produto aberto',
        'posso doar comida estragada',
        'o que não posso doar',
        'aceitam remédio',
        'posso doar item quebrado',
        'aceitam roupa rasgada',
        'aceitam comida feita em casa',
        'o que é recusado',
        'tem algo que não pode doar',
        'vocês recebem medicamento',
        'doação de remédio pode',
        'aceitam vitaminas e medicamentos',
        'vocês aceitam coisa vencida',
        'posso doar remédio vencido',
        'aceitam produto sem embalagem',
        'o que não pode ser doado',
        'tem itens proibidos',
      ],
      (c) =>
          'Não doe itens vencidos, estragados, abertos ou quebrados. Itens perecíveis precisam de validade. '
          'Remédios, comida feita em casa e outros casos especiais precisam ser combinados antes: '
          '${c.ong.ondePerguntar}. Na dúvida, ofereça pelo app: a equipe avalia antes de aprovar.'),
  Intencao(
      'varios_itens',
      [
        'posso doar vários itens de uma vez',
        'dá para colocar mais de um item',
        'como adiciono outro item',
        'quantos itens posso doar',
        'limite de itens por doação',
        'quantas doações posso fazer',
        'posso ter mais de uma doação aberta',
        'por que não consigo fazer outra doação',
        'limite de doações',
        'posso juntar produtos diferentes numa doação',
        'mais de um produto na mesma doação',
        'colocar leite e açúcar juntos',
        'dá pra doar mais de um produto',
        'como coloco vários itens na doação',
        'posso doar arroz e feijão juntos',
        'limite de doações abertas',
        'por que não posso abrir outra doação',
      ],
      (c) =>
          'Pode sim: no formulário, toque em "Adicionar à lista" e depois em "Adicionar outro item" '
          '(até 20 itens por doação). Cada doador pode ter até 3 doações abertas ao mesmo tempo; quando '
          'uma é recebida ou cancelada, abre espaço para outra. A equipe pode ajustar esses limites.'),
  Intencao(
      'prazo_avaliacao',
      [
        'quanto tempo demora para aprovar',
        'quando minha doação será aprovada',
        'demora quanto a análise',
        'em quanto tempo respondem',
        'já faz dias e não aprovaram',
        'quanto tempo leva a avaliação',
        'em quanto tempo aprovam',
        'demora para aprovar a doação',
        'quantos dias leva a avaliação',
        'quando vão avaliar minha doação',
        'a aprovação é rápida',
      ],
      (c) =>
          'A equipe avalia as doações pela ordem de chegada; não há um prazo fixo informado. Você '
          'acompanha o status na aba "Doações" e, se ligar as notificações no Perfil, recebe um aviso '
          'quando for aprovada. Se tiver pressa, ${c.ong.ondePerguntar}.'),
  Intencao(
      'recusada',
      [
        'minha doação foi recusada',
        'por que recusaram minha doação',
        'doação recusada o que faço',
        'qual o motivo da recusa',
        'não aprovaram minha doação',
        'minha doação foi negada',
        'por que minha doação foi recusada',
        'recusaram minha doação',
        'minha doação não foi aceita',
        'o que faço se recusarem',
        'motivo da recusa',
      ],
      (c) =>
          'Quando a equipe recusa uma doação, o motivo aparece na tela dela, na aba "Doações". '
          'Normalmente é algo que não está sendo necessário agora ou com validade curta. Você pode '
          'registrar uma nova doação com os itens de "Precisa" ou ${c.ong.ondePerguntar}.'),
  Intencao(
      'notificacoes',
      [
        'vou receber aviso',
        'como ativo as notificações',
        'não recebo notificações',
        'me avisam quando aprovar',
        'desligar notificações',
        'recebo email da doação',
        'quero ser avisado',
        'como recebo alertas sobre minha doação',
        'avisos no celular',
        'vocês mandam notificação',
        'como ativo os avisos',
        'vou ser avisado quando aprovarem',
        'recebo mensagem quando receberem',
        'desligar notificações',
      ],
      (c) =>
          'Em "Perfil", ligue "Receber notificações": você recebe um aviso quando a doação for '
          'aprovada ou recebida. O status também fica sempre na aba "Doações".'),
  Intencao(
      'impacto',
      [
        'para onde vai minha doação',
        'como minha doação foi usada',
        'quero saber o impacto da minha doação',
        'a doação chegou às crianças',
        'onde usaram os itens que doei',
        'relatório de impacto',
        'o que fizeram com minha doação',
        'como foi usada minha doação',
        'quero ver o impacto',
        'minha doação ajudou quem',
        'relatório de impacto',
      ],
      (c) =>
          'Depois do recebimento, a equipe registra o destino da doação. Na tela da doação aparece o '
          '"Relatório de impacto" com o setor e a mensagem da equipe, e você pode baixar o recibo em PDF.'),
  Intencao(
      'sobre_app',
      [
        'o que é o educastock',
        'para que serve esse aplicativo',
        'o que dá pra fazer no app',
        'como funciona o aplicativo',
        'quem fez esse app',
        'o que é esse portal',
        'o que é esse aplicativo',
        'pra que serve o educastock',
        'o que o app faz',
        'como funciona esse portal',
        'quem desenvolveu o aplicativo',
      ],
      (c) =>
          'O EducaStock é o sistema de estoque e doações da Casa da Criança. No Portal do Doador você '
          'vê o que a ONG precisa, registra doações, acompanha o status, mostra o QR Code na entrega e '
          'recebe o recibo e o impacto da doação.'),
  Intencao(
      'bot',
      [
        'você é um robô',
        'você é humano',
        'estou falando com uma pessoa',
        'você é uma ia',
        'quem é você',
        'você é inteligente',
        'é um bot',
        'você é uma pessoa de verdade',
        'você é um robô ou humano',
        'estou falando com um bot',
        'é inteligência artificial',
        'quem está respondendo',
      ],
      (c) =>
          'Sou o assistente virtual da Casa da Criança: um modelo de Machine Learning que roda no '
          'próprio aplicativo. Respondo as dúvidas mais comuns sobre doações; para falar com uma pessoa, '
          '${c.ong.ondePerguntar}.'),
  Intencao(
      'doacao_recorrente',
      [
        'quero doar todo mês',
        'posso fazer doação mensal',
        'como ser doador fixo',
        'doação recorrente',
        'dá pra doar sempre',
        'quero ajudar todo mês',
        'posso programar doações',
        'quero doar com frequência',
        'minha empresa quer doar todo mês',
        'doação periódica',
        'quero doar mensalmente',
        'dá pra doar todo mês',
        'quero ser doador fixo',
        'doações todo mês',
        'posso ajudar sempre',
      ],
      (c) =>
          'Que ótimo! O app não agenda doações automáticas, mas você pode registrar uma nova doação '
          'sempre que quiser. As necessidades em "Precisa" mudam com o estoque, então vale olhar antes '
          'de cada doação. Para combinar doações frequentes, ${c.ong.ondePerguntar}.'),
  Intencao(
      'elogio_reclamacao',
      [
        'quero fazer uma reclamação',
        'tenho uma sugestão',
        'quero elogiar a equipe',
        'fui mal atendido',
        'achei um erro no aplicativo',
        'o app está com problema',
        'parabéns pelo trabalho',
        'quero dar uma sugestão de melhoria',
        'tive um problema na entrega',
        'adorei o atendimento',
        'quero deixar uma reclamação',
        'tenho uma crítica',
        'gostaria de fazer um elogio',
        'o atendimento foi ruim',
        'encontrei um problema no app',
      ],
      (c) =>
          'Obrigado por contar! Elogios, sugestões e reclamações ajudam a Casa da Criança a melhorar. '
          'Para registrar, ${c.ong.ondePerguntar}. Se for um problema no aplicativo, diga o que '
          'aconteceu e em qual tela.'),
  Intencao(
      'visita',
      [
        'posso visitar a ong',
        'posso conhecer a casa da criança',
        'dá pra fazer uma visita',
        'posso levar meus filhos para conhecer',
        'agendar uma visita',
        'posso ir conhecer o trabalho de vocês',
        'vocês recebem visitas',
        'posso passar aí para conhecer',
      ],
      (c) =>
          'Visitas são combinadas antes com a equipe, para não atrapalhar as atividades das crianças. '
          'Para agendar, ${c.ong.ondePerguntar}. A sede fica na ${c.ong.endereco}.'),
  Intencao(
      'imposto',
      [
        'a doação abate no imposto de renda',
        'posso deduzir do imposto',
        'vocês emitem nota fiscal',
        'o recibo serve para imposto de renda',
        'dedução fiscal da doação',
        'preciso de documento fiscal',
        'dá para abater no imposto',
        'tem benefício fiscal',
      ],
      (c) =>
          'O recibo em PDF do app comprova a entrega da doação, mas não é um documento fiscal. Se você '
          'precisa de um comprovante para imposto de renda ou para a contabilidade da empresa, '
          '${c.ong.ondePerguntar}: a equipe informa o que a Casa da Criança pode emitir.'),
  Intencao(
      'fora_escopo',
      [
        'quem ganhou o jogo ontem',
        'qual a previsão do tempo',
        'me conta uma piada',
        'quanto é dois mais dois',
        'qual a capital da frança',
        'me ajuda com a lição',
        'qual o melhor celular',
        'quem é o presidente',
      ],
      (c) =>
          'Só consigo ajudar com doações para a Casa da Criança e com o uso do aplicativo. '
          'Pergunte, por exemplo, sobre o horário, o endereço, o que doar ou como doar.'),
];

/// Pergunta legível de cada intenção: vira botão de sugestão ("Você quis dizer…" e
/// "Talvez você também queira saber"). Intenções sem pergunta aqui não viram botão.
const Map<String, String> kPerguntaDaIntencao = {
  'horario_funcionamento': 'Qual o horário de funcionamento?',
  'horario_entrega': 'Que horas posso entregar a doação?',
  'endereco': 'Onde fica a Casa da Criança?',
  'contato': 'Qual o telefone de vocês?',
  'dinheiro': 'Posso doar em dinheiro?',
  'pix': 'Vocês têm chave PIX?',
  'historia': 'Quando a Casa da Criança foi fundada?',
  'quem_atende': 'Quem a Casa da Criança atende?',
  'o_que_doar': 'O que posso doar?',
  'necessidades': 'Do que vocês mais precisam?',
  'validade': 'Qual a validade mínima dos alimentos?',
  'como_doar': 'Como faço para doar?',
  'entrega': 'Onde entrego a doação?',
  'retirada': 'Vocês buscam a doação?',
  'acompanhamento': 'Como acompanho minha doação?',
  'cancelar': 'Como cancelo uma doação?',
  'qr_code': 'Onde fica o QR Code?',
  'recibo': 'Como pego o recibo?',
  'anonimato': 'Posso doar sem mostrar meu nome?',
  'privacidade': 'Meus dados estão seguros?',
  'voluntariado': 'Como posso ser voluntário?',
  'empresa': 'Minha empresa pode doar?',
  'nao_aceitos': 'O que vocês não aceitam?',
  'varios_itens': 'Posso doar vários itens de uma vez?',
  'prazo_avaliacao': 'Quanto tempo leva para aprovar?',
  'impacto': 'Como vejo o impacto da minha doação?',
  'doacao_recorrente': 'Posso doar todo mês?',
  'visita': 'Posso visitar a Casa da Criança?',
  'imposto': 'A doação abate no imposto de renda?',
};

/// Próximas dúvidas mais comuns depois de cada assunto (viram botões de sugestão).
const Map<String, List<String>> kIntencoesRelacionadas = {
  'saudacao': ['necessidades', 'como_doar', 'horario_funcionamento'],
  'horario_funcionamento': ['endereco', 'horario_entrega'],
  'horario_entrega': ['entrega', 'endereco'],
  'endereco': ['horario_funcionamento', 'entrega'],
  'contato': ['horario_funcionamento', 'endereco'],
  'dinheiro': ['pix', 'imposto'],
  'pix': ['dinheiro', 'imposto'],
  'historia': ['quem_atende', 'visita'],
  'quem_atende': ['necessidades', 'visita'],
  'o_que_doar': ['necessidades', 'nao_aceitos'],
  'necessidades': ['como_doar', 'validade'],
  'validade': ['necessidades', 'nao_aceitos'],
  'como_doar': ['entrega', 'acompanhamento'],
  'entrega': ['horario_entrega', 'qr_code'],
  'retirada': ['entrega', 'contato'],
  'acompanhamento': ['prazo_avaliacao', 'qr_code'],
  'cancelar': ['acompanhamento'],
  'qr_code': ['entrega', 'acompanhamento'],
  'recibo': ['impacto', 'imposto'],
  'impacto': ['recibo'],
  'empresa': ['doacao_recorrente', 'imposto'],
  'doacao_recorrente': ['necessidades', 'empresa'],
  'visita': ['horario_funcionamento', 'voluntariado'],
  'imposto': ['recibo'],
  'voluntariado': ['contato', 'visita'],
  'nao_aceitos': ['o_que_doar', 'validade'],
};

/// Resposta quando o modelo não tem segurança suficiente.
String respostaNaoEntendi(ContextoResposta c) =>
    'Não tenho certeza se entendi. Posso ajudar com: horário e endereço da Casa da Criança, '
    'contato, o que doar, o que mais precisam, como doar, entrega, acompanhamento e recibo. '
    'Se preferir falar com uma pessoa, ${c.ong.ondePerguntar}.';
