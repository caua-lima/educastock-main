// Conversa do assistente do doador: usa o classificador de intenções (Naive Bayes no
// aparelho) e acrescenta quatro habilidades, todas sem servidor e sem chave de API:
//
// 1. Busca de item: "vocês precisam de arroz?" responde com a necessidade real (quanto
//    falta, prioridade e validade mínima) a partir do estoque da ONG.
// 2. Várias perguntas numa mensagem: "qual o endereço e o horário?" responde as duas.
// 3. Contexto: "e no sábado?" depois de "que horas abre?" continua o mesmo assunto.
// 4. Sugestões: quando não tem certeza, oferece os assuntos mais prováveis em botões;
//    quando responde, sugere as próximas dúvidas mais comuns.
//
// Nada é inventado: as respostas vêm das intenções cadastradas, de [InfoOng] e das
// necessidades abertas no app.
import '../info_ong.dart';
import '../respostas_locais.dart';
import 'classificador_intencoes.dart';
import 'intencoes.dart';

/// Necessidade aberta, no formato que o assistente usa.
class NecessidadeChat {
  final String titulo;
  final int falta;
  final String unidade;
  final String prioridade;
  final int validadeMinimaDias;

  const NecessidadeChat({
    required this.titulo,
    required this.falta,
    required this.unidade,
    required this.prioridade,
    this.validadeMinimaDias = 0,
  });

  String get resumo =>
      '$titulo: faltam $falta $unidade (prioridade $prioridade)';
}

/// Resposta do assistente para uma mensagem.
class RespostaAssistente {
  final String texto;

  /// O modelo local entendeu (senão a pergunta pode ir para a IA externa).
  final bool entendeu;

  /// Intenções respondidas, em ordem (vazio quando não entendeu).
  final List<String> intencoes;

  /// Perguntas sugeridas, mostradas como botões abaixo da resposta.
  final List<String> sugestoes;

  const RespostaAssistente({
    required this.texto,
    required this.entendeu,
    this.intencoes = const [],
    this.sugestoes = const [],
  });
}

/// Responde [pergunta] considerando a [perguntaAnterior] (contexto) e as
/// [necessidades] abertas.
RespostaAssistente responderConversa(
  String pergunta, {
  InfoOng ong = InfoOng.padrao,
  List<NecessidadeChat> necessidades = const [],
  String? perguntaAnterior,
}) {
  final contexto = ContextoResposta(
    ong: ong,
    maisPrecisados: [for (final n in necessidades.take(5)) n.resumo],
  );
  final geral = classificadorAssistente.classificar(pergunta);

  // 1. Item específico ("precisam de arroz?", "aceitam fralda?").
  final item = _respostaDeItem(pergunta, geral, necessidades, contexto);
  if (item != null) return item;

  // 2. Várias perguntas na mesma mensagem.
  final varias = _respostaDeVarias(pergunta, geral, contexto);
  if (varias != null) return varias;

  if (geral.confiavel) return _responder([geral.intencao], contexto);

  // 3. Continuação curta do assunto anterior ("e no sábado?", "e o telefone?").
  final anterior = perguntaAnterior?.trim() ?? '';
  final palavras = ClassificadorIntencoes.palavrasDe(pergunta);
  if (anterior.isNotEmpty && palavras.isNotEmpty && palavras.length <= 5) {
    final junto = classificadorAssistente.classificar('$anterior $pergunta');
    if (junto.confiavel) return _responder([junto.intencao], contexto);
  }

  // 4. Não entendeu: sugere os assuntos mais prováveis.
  final provaveis = [
    if (geral.confianca >= 0.15) geral.intencao,
    if (geral.segunda != null) geral.segunda!,
  ];
  final sugestoes = [
    for (final id in provaveis)
      if (kPerguntaDaIntencao[id] != null) kPerguntaDaIntencao[id]!,
  ];
  return RespostaAssistente(
    texto: sugestoes.isEmpty
        ? respostaNaoEntendi(contexto)
        : '${respostaNaoEntendi(contexto)}\n\nVocê quis perguntar algo assim?',
    entendeu: false,
    sugestoes: sugestoes.isEmpty
        ? [
            kPerguntaDaIntencao['necessidades']!,
            kPerguntaDaIntencao['como_doar']!,
            kPerguntaDaIntencao['horario_funcionamento']!,
          ]
        : sugestoes,
  );
}

RespostaAssistente _responder(List<String> ids, ContextoResposta contexto) {
  final textos = [for (final id in ids) respostaDaIntencao(id, contexto)];
  return RespostaAssistente(
    texto: textos.join('\n\n'),
    entendeu: true,
    intencoes: ids,
    sugestoes: _relacionadas(ids),
  );
}

/// Até duas próximas dúvidas comuns, sem repetir o que acabou de ser respondido.
List<String> _relacionadas(List<String> ids) {
  final vistas = <String>{};
  final out = <String>[];
  for (final id in ids) {
    for (final r in kIntencoesRelacionadas[id] ?? const <String>[]) {
      if (ids.contains(r) || !vistas.add(r)) continue;
      final p = kPerguntaDaIntencao[r];
      if (p != null) out.add(p);
      if (out.length == 2) return out;
    }
  }
  return out;
}

// ─── 1. Busca de item ──────────────────────────────────────────────────────

/// Palavras que pedem um item ("precisam", "aceitam", "falta", "doar"…).
final _pedeItem = RegExp(
    r'\b(precis\w*|aceit\w*|falt\w*|doar|doo|levar|mandar|querem|recebem|serve|servem|necessidade\w*)\b');

/// Palavras da pergunta que não são o nome do item.
const _naoItem = {
  'precisa',
  'precisam',
  'precisando',
  'aceita',
  'aceitam',
  'aceitar',
  'falta',
  'faltando',
  'faltam',
  'doar',
  'doo',
  'levar',
  'mandar',
  'querem',
  'recebem',
  'serve',
  'servem',
  'necessidade',
  'necessidades',
  'voces',
  'vcs',
  'voce',
  'ainda',
  'agora',
  'hoje',
  'tambem',
  'algum',
  'alguma',
  'item',
  'itens',
  'coisa',
  'coisas',
  'doacao',
  'doacoes',
  'produto',
  'produtos',
  'tipo',
  'tipos',
  'mesmo',
  'sim',
  'nao',
  'bem',
  'estao',
  'esta',
  'sao',
  'ser',
  'tenho',
  'quanto',
  'quantos',
  'quantas',
  'qual',
  'quais',
  'que',
  'posso',
  'pode',
  'podem',
  'eu',
  'meu',
  'minha',
  'uns',
  'umas',
  'ai',
  'la',
  'casa',
  'crianca',
  'ong',
  'pra',
  'para',
  'de',
  'da',
  'do',
  'das',
  'dos',
  'um',
  'uma',
  'o',
  'a',
  'os',
  'as',
  'e',
  'em',
  'no',
  'na',
  'com',
  'mais',
  'muito',
  'muita',
  'unidade',
  'unidades',
  'quilo',
  'quilos',
  'kg',
  'litro',
  'litros',
  'pacote',
  'pacotes',
  'caixa',
  'caixas',
  'lata',
  'latas',
};

/// Assuntos que mencionam itens mas têm resposta própria (não é "vocês precisam de X?").
const _intencoesSemBuscaDeItem = {
  'nao_aceitos',
  'validade',
  'varios_itens',
  'dinheiro',
  'pix',
  'cancelar',
  'acompanhamento',
  'recibo',
  'impacto',
  'retirada',
  'entrega',
  'horario_entrega',
  'imposto',
  'doacao_recorrente',
};

RespostaAssistente? _respostaDeItem(
  String pergunta,
  ResultadoIntencao geral,
  List<NecessidadeChat> necessidades,
  ContextoResposta contexto,
) {
  final normal = ClassificadorIntencoes.normalizar(pergunta);
  if (!_pedeItem.hasMatch(normal)) return null;
  if (geral.confiavel && _intencoesSemBuscaDeItem.contains(geral.intencao)) {
    return null;
  }
  final termos = [
    for (final p in ClassificadorIntencoes.palavrasDe(pergunta))
      if (p.length >= 3 && !_naoItem.contains(p) && int.tryParse(p) == null) p,
  ];
  if (termos.isEmpty) return null;

  final achadas = [
    for (final n in necessidades)
      if (termos.any((t) => _nomeTem(n.titulo, t))) n,
  ];
  if (achadas.isNotEmpty) {
    final linhas = [
      for (final n in achadas.take(3))
        '- ${n.titulo}: faltam ${n.falta} ${n.unidade}, prioridade ${n.prioridade}'
            '${n.validadeMinimaDias > 0 ? ', validade mínima de ${n.validadeMinimaDias} dias' : ''}',
    ];
    final um = achadas.length == 1;
    return RespostaAssistente(
      texto:
          'Sim! ${um ? 'Este item está' : 'Estes itens estão'} na lista da Casa da Criança:\n'
          '${linhas.join('\n')}\n'
          'Para doar, abra "Precisa", toque no item e depois em "Doar".',
      entendeu: true,
      intencoes: const ['necessidades'],
      sugestoes: [
        kPerguntaDaIntencao['como_doar']!,
        kPerguntaDaIntencao['entrega']!,
      ],
    );
  }

  // Item citado que não está na lista (só quando a lista carregou e a pergunta é
  // mesmo sobre o que doar): não inventa necessidade, sugere oferecer.
  final sobreDoar = !geral.confiavel ||
      geral.intencao == 'necessidades' ||
      geral.intencao == 'o_que_doar';
  if (necessidades.isEmpty || !sobreDoar) return null;
  return RespostaAssistente(
    texto:
        'Esse item não está entre as necessidades abertas agora. Você ainda pode oferecer: '
        'toque em "Quero doar", descreva o item e a equipe avalia antes de aprovar.\n\n'
        'O que mais ajuda neste momento:\n'
        '${[for (final n in necessidades.take(3)) '- ${n.resumo}'].join('\n')}',
    entendeu: true,
    intencoes: const ['o_que_doar'],
    sugestoes: [
      kPerguntaDaIntencao['nao_aceitos']!,
      kPerguntaDaIntencao['como_doar']!,
    ],
  );
}

/// O nome da necessidade contém o termo (aceita plural e um erro de digitação).
bool _nomeTem(String titulo, String termo) {
  final t = _singular(termo);
  for (final p in ClassificadorIntencoes.palavrasDe(titulo)) {
    if (p.length < 3) continue;
    final s = _singular(p);
    if (s == t) return true;
    if (t.length >= 5 && s.length >= 5 && _distancia(s, t) <= 1) return true;
  }
  return false;
}

String _singular(String p) {
  if (p.length > 4 && p.endsWith('oes')) {
    return '${p.substring(0, p.length - 3)}ao';
  }
  if (p.length > 4 && p.endsWith('es') && !p.endsWith('ees')) {
    final base = p.substring(0, p.length - 2);
    if (base.endsWith('r') || base.endsWith('z') || base.endsWith('s')) {
      return base;
    }
  }
  if (p.length > 3 && p.endsWith('s')) return p.substring(0, p.length - 1);
  return p;
}

/// Distância de edição (Levenshtein) entre duas palavras curtas.
int _distancia(String a, String b) {
  var anterior = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final atual = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final custo = a[i - 1] == b[j - 1] ? 0 : 1;
      atual[j] = [
        anterior[j] + 1,
        atual[j - 1] + 1,
        anterior[j - 1] + custo,
      ].reduce((x, y) => x < y ? x : y);
    }
    anterior = atual;
  }
  return anterior[b.length];
}

// ─── 2. Várias perguntas ───────────────────────────────────────────────────

/// Pontuação que separa perguntas (antes de normalizar, que apaga a pontuação).
final _pontuacao = RegExp(r'[?!;.]+');

/// Depois de normalizar: "também" e " e " seguido do começo de outra pergunta.
final _conector = RegExp(
    r'\s+tambem\s+|\s+e\s+(?=(?:qual|quais|como|onde|quando|que|o|a|os|as|tem|voces|vcs|me|aceitam|posso|da)\s)');

RespostaAssistente? _respostaDeVarias(
    String pergunta, ResultadoIntencao geral, ContextoResposta contexto) {
  if (geral.confiavel && geral.intencao == 'varios_itens') return null;
  final partes = [
    for (final trecho in pergunta.split(_pontuacao))
      ...ClassificadorIntencoes.normalizar(trecho).split(_conector),
  ].map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  if (partes.length < 2) return null;

  final ids = <String>[];
  for (final parte in partes) {
    final r = classificadorAssistente.classificar(parte);
    if (!r.confiavel || ids.contains(r.intencao)) continue;
    // Saudação e agradecimento junto de uma pergunta: responde só a pergunta.
    if (const {'saudacao', 'agradecimento', 'despedida'}.contains(r.intencao)) {
      continue;
    }
    ids.add(r.intencao);
  }
  if (ids.length < 2) return null;
  return _responder(ids.take(3).toList(), contexto);
}
