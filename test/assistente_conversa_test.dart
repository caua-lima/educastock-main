// Assistente do doador: conversa (busca de item, várias perguntas, contexto, sugestões)
// e avaliação do classificador por validação cruzada (deixa-um-de-fora).
import 'package:educastock/features/chatbot/domain/ml/classificador_intencoes.dart';
import 'package:educastock/features/chatbot/domain/ml/conversa.dart';
import 'package:educastock/features/chatbot/domain/ml/intencoes.dart';
import 'package:educastock/features/chatbot/domain/respostas_locais.dart';
import 'package:flutter_test/flutter_test.dart';

const _necessidades = [
  NecessidadeChat(
      titulo: 'Leite UHT integral · 1 L',
      falta: 240,
      unidade: 'un',
      prioridade: 'Crítica',
      validadeMinimaDias: 45),
  NecessidadeChat(
      titulo: 'Arroz agulhinha tipo 1 · 5 kg',
      falta: 40,
      unidade: 'un',
      prioridade: 'Alta',
      validadeMinimaDias: 90),
  NecessidadeChat(
      titulo: 'Sabonete em barra · 90 g',
      falta: 24,
      unidade: 'un',
      prioridade: 'Normal'),
];

void main() {
  group('busca de item nas necessidades', () {
    test('item que está na lista: responde com quanto falta e a prioridade', () {
      final r = responderConversa('vocês precisam de arroz?',
          necessidades: _necessidades);
      expect(r.entendeu, isTrue);
      expect(r.texto, contains('Arroz agulhinha'));
      expect(r.texto, contains('faltam 40 un'));
      expect(r.texto, contains('validade mínima de 90 dias'));
    });

    test('plural e erro de digitação também encontram o item', () {
      expect(
          responderConversa('aceitam sabonetes?', necessidades: _necessidades)
              .texto,
          contains('Sabonete em barra'));
      expect(
          responderConversa('tá faltando leiite?', necessidades: _necessidades)
              .texto,
          contains('Leite UHT'));
    });

    test('item fora da lista: não inventa, sugere oferecer', () {
      final r = responderConversa('vocês precisam de fralda?',
          necessidades: _necessidades);
      expect(r.texto, contains('não está entre as necessidades abertas'));
      expect(r.texto, contains('Leite UHT'));
    });

    test('sem a lista carregada, responde o assunto geral', () {
      final r = responderConversa('vocês aceitam roupas de criança?');
      expect(r.entendeu, isTrue);
      expect(r.texto, contains('aceita alimentos'));
    });

    test('perguntas com resposta própria não viram busca de item', () {
      expect(
          responderConversa('aceitam remédio?', necessidades: _necessidades)
              .intencoes,
          ['nao_aceitos']);
      expect(
          responderConversa('posso doar leite que vence semana que vem?',
                  necessidades: _necessidades)
              .intencoes,
          ['validade']);
    });
  });

  group('várias perguntas na mesma mensagem', () {
    test('endereço e horário', () {
      final r = responderConversa('qual o endereço e o horário?');
      expect(r.intencoes, containsAll(['endereco', 'horario_funcionamento']));
      expect(r.texto, contains('Rua Sílvio Galizoni'));
      expect(r.texto, contains('das 7h'));
    });

    test('duas perguntas com interrogação', () {
      final r = responderConversa('Tem pix? Qual o telefone?');
      expect(r.intencoes, containsAll(['pix', 'contato']));
    });

    test('"arroz e feijão na mesma doação" continua uma pergunta só', () {
      final r =
          responderConversa('dá para doar arroz e feijão na mesma doação?');
      expect(r.intencoes, ['varios_itens']);
    });
  });

  test('contexto: "e no sábado?" continua o assunto anterior', () {
    final r = responderConversa('e no sábado?',
        perguntaAnterior: 'que horas vocês abrem?');
    expect(r.entendeu, isTrue);
    expect(r.intencoes, ['horario_funcionamento']);
  });

  test('sugestões: próximas dúvidas depois de responder', () {
    final r = responderConversa('como faço para doar?');
    expect(r.sugestoes, isNotEmpty);
    expect(r.sugestoes, isNot(contains(kPerguntaDaIntencao['como_doar'])));
  });

  test('não entendeu: oferece assuntos em botões, sem inventar resposta', () {
    final r = responderConversa('xkcd zzzz qwerty');
    expect(r.entendeu, isFalse);
    expect(r.texto, contains('Não tenho certeza'));
    expect(r.sugestoes, isNotEmpty);
  });

  test('novos assuntos reconhecidos em frases que o modelo nunca viu', () {
    const casos = <(String, String)>[
      ('Quero ser doadora todo mês, dá?', 'doacao_recorrente'),
      ('minha empresa quer fazer doações periódicas', 'doacao_recorrente'),
      ('Gostaria de deixar um elogio pra equipe', 'elogio_reclamacao'),
      ('quero reclamar do atendimento', 'elogio_reclamacao'),
      ('Posso agendar uma visita com meus filhos?', 'visita'),
      ('dá pra conhecer a ONG pessoalmente?', 'visita'),
      ('Doação deduz do imposto de renda?', 'imposto'),
      ('vocês dão nota fiscal?', 'imposto'),
    ];
    final erros = [
      for (final (p, esperada) in casos)
        if (analisarPergunta(p).resultado.intencao != esperada ||
            !analisarPergunta(p).entendeu)
          '"$p": esperava $esperada, veio ${analisarPergunta(p).resultado}',
    ];
    expect(erros.length, lessThanOrEqualTo(1), reason: erros.join('\n'));
  });

  test('validação cruzada deixa-um-de-fora: acerto de pelo menos 70%', () {
    // Treina sem cada frase de exemplo e testa nela: mede se o modelo generaliza para
    // frases que não viu, intenção por intenção.
    final exemplos = {for (final i in kIntencoes) i.id: i.exemplos};
    var total = 0, acertos = 0;
    final porIntencao = <String, List<int>>{};
    exemplos.forEach((id, frases) {
      for (var k = 0; k < frases.length; k++) {
        final treino = {
          for (final e in exemplos.entries)
            e.key: e.key == id
                ? [
                    for (var j = 0; j < e.value.length; j++)
                      if (j != k) e.value[j]
                  ]
                : e.value,
        };
        final modelo = ClassificadorIntencoes.treinar(treino);
        final r = modelo.classificar(frases[k]);
        total++;
        final ok = r.intencao == id;
        if (ok) acertos++;
        porIntencao.putIfAbsent(id, () => [0, 0])
          ..[0] += ok ? 1 : 0
          ..[1] += 1;
      }
    });
    final acerto = acertos / total;
    final piores = (porIntencao.entries.toList()
          ..sort((a, b) =>
              (a.value[0] / a.value[1]).compareTo(b.value[0] / b.value[1])))
        .take(5)
        .map((e) => '${e.key}: ${e.value[0]}/${e.value[1]}')
        .join(', ');
    // ignore: avoid_print
    print('Validação cruzada: ${(acerto * 100).toStringAsFixed(1)}% '
        '($acertos/$total). Intenções mais difíceis: $piores');
    expect(acerto, greaterThanOrEqualTo(0.70));
  });
}
