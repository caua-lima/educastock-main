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
        ' Se puder, ${o.ondePerguntar} antes de ir.';
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
  if (o.horarioEntregas.isNotEmpty)
    return 'As doações são recebidas ${o.horarioEntregas}. $janela';
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
  ], (c) {
    final o = c.ong;
    final partes = <String>[];
    if (o.chavePix.isNotEmpty) partes.add('PIX: ${o.chavePix}');
    if (o.contaBancaria.isNotEmpty) partes.add('conta: ${o.contaBancaria}');
    if (partes.isEmpty)
      return 'Para doar em dinheiro, ${o.ondePerguntar}: a equipe passa os dados.';
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
  ], (c) {
    final o = c.ong;
    if (o.chavePix.isNotEmpty)
      return 'A chave PIX da Casa da Criança é ${o.chavePix}. Obrigado pela ajuda!';
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
    'o que dá pra doar', 'que itens posso doar', 'o que eu posso levar de doação', 'que coisas vocês recebem',
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
      ],
      (c) =>
          'Por segurança, não peço nem recebo senhas, cartões ou documentos. Para doar, basta usar '
          'o formulário "Quero doar".'),
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

/// Resposta quando o modelo não tem segurança suficiente.
String respostaNaoEntendi(ContextoResposta c) =>
    'Não tenho certeza se entendi. Posso ajudar com: horário e endereço da Casa da Criança, '
    'contato, o que doar, o que mais precisam, como doar, entrega, acompanhamento e recibo. '
    'Se preferir falar com uma pessoa, ${c.ong.ondePerguntar}.';
