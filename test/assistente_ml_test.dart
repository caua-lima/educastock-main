// Assistente do doador: classificador de intenções (Machine Learning no aparelho).
// As perguntas abaixo NÃO estão nos exemplos de treino: medem se o modelo generaliza.
import 'package:educastock/features/chatbot/domain/info_ong.dart';
import 'package:educastock/features/chatbot/domain/respostas_locais.dart';
import 'package:flutter_test/flutter_test.dart';

const _naoVistas = <(String, String)>[
  ('Bom dia! Tudo certo?', 'saudacao'),
  ('Muito obrigada pela atenção', 'agradecimento'),
  ('Que horas vocês abrem?', 'horario_funcionamento'),
  ('qual horario de funcionamneto da casa', 'horario_funcionamento'),
  ('Vocês funcionam sábado de manhã?', 'horario_funcionamento'),
  ('a ong fecha que horas?', 'horario_funcionamento'),
  ('Qual o horário de atendimento ao público?', 'horario_funcionamento'),
  ('Em que horário posso deixar minha doação?', 'horario_entrega'),
  ('Até que horas posso entregar os itens?', 'horario_entrega'),
  ('Onde fica a Casa da Criança?', 'endereco'),
  ('me passa o endereço por favor', 'endereco'),
  ('Qual bairro vocês ficam?', 'endereco'),
  ('Qual é o número de telefone?', 'contato'),
  ('vcs tem zap?', 'contato'),
  ('Qual o instagram da ONG?', 'contato'),
  ('Quero doar dinheiro, como faço?', 'dinheiro'),
  ('Vocês têm conta para depósito?', 'dinheiro'),
  ('Qual é a chave pix?', 'pix'),
  ('dá pra mandar um pix?', 'pix'),
  ('Quando a Casa da Criança foi criada?', 'historia'),
  ('Quem criou a instituição?', 'historia'),
  ('Quantas crianças vocês atendem?', 'quem_atende'),
  ('Qual a faixa etária atendida?', 'quem_atende'),
  ('O que vocês fazem com as crianças?', 'quem_atende'),
  ('Vocês aceitam roupas de criança?', 'o_que_doar'),
  ('Posso doar sabonete e shampoo?', 'o_que_doar'),
  ('Aceitam cadernos e lápis?', 'o_que_doar'),
  ('O que está em falta agora?', 'necessidades'),
  ('Do que a ONG mais precisa hoje?', 'necessidades'),
  ('Posso doar leite que vence semana que vem?', 'validade'),
  ('Aceitam alimento com validade curta?', 'validade'),
  ('Como faço pra doar pelo aplicativo?', 'como_doar'),
  ('Quero fazer uma doação, por onde começo?', 'como_doar'),
  ('Onde eu levo os alimentos?', 'entrega'),
  ('Vocês podem buscar aqui em casa?', 'retirada'),
  ('Como vejo se minha doação foi aprovada?', 'acompanhamento'),
  ('Minha doação ainda está pendente, é normal?', 'acompanhamento'),
  ('Preciso cancelar a doação que fiz', 'cancelar'),
  ('Onde acho o QR code?', 'qr_code'),
  ('Vocês dão comprovante da doação?', 'recibo'),
  ('Dá para doar sem mostrar meu nome?', 'anonimato'),
  ('Quero apagar todos os meus dados', 'privacidade'),
  ('Gostaria de ser voluntária', 'voluntariado'),
  ('Vocês recolhem óleo usado?', 'oleo_bazar'),
  ('Minha empresa pode fazer doações?', 'empresa'),
  ('Esqueci a senha, e agora?', 'conta'),
  ('Vou te passar o número do meu cartão', 'dados_sensiveis'),
  ('Qual time vai ganhar o campeonato?', 'fora_escopo'),
  ('tchau, até amanhã', 'despedida'),
  ('Vocês aceitam comida já aberta?', 'nao_aceitos'),
  ('Posso doar remédios?', 'nao_aceitos'),
  ('Dá para doar arroz e feijão na mesma doação?', 'varios_itens'),
  ('Por que o app não deixa eu fazer mais uma doação?', 'varios_itens'),
  ('Quanto tempo vocês levam para aprovar?', 'prazo_avaliacao'),
  ('Recusaram minha doação, por quê?', 'recusada'),
  ('Como faço para receber avisos da doação?', 'notificacoes'),
  ('Como foi usada a doação que eu fiz?', 'impacto'),
  ('Para que serve o EducaStock?', 'sobre_app'),
  ('Tô falando com um robô?', 'bot'),
];

void main() {
  test('reconhece pelo menos 90% das perguntas que nunca viu', () {
    final erros = <String>[];
    for (final (pergunta, esperada) in _naoVistas) {
      final a = analisarPergunta(pergunta);
      // Fora do assunto: tanto faz reconhecer ou dizer que não entendeu (nada é inventado).
      if (esperada == 'fora_escopo' && !a.entendeu) continue;
      if (!a.entendeu || a.resultado.intencao != esperada) {
        erros.add(
            '"$pergunta": esperava $esperada, veio ${a.resultado}${a.entendeu ? '' : ' [não entendeu]'}');
      }
    }
    final acerto = 1 - erros.length / _naoVistas.length;
    // ignore: avoid_print
    print(
        'Acerto: ${(acerto * 100).toStringAsFixed(1)}% (${_naoVistas.length - erros.length}/${_naoVistas.length})\n${erros.join('\n')}');
    expect(acerto, greaterThanOrEqualTo(0.9));
  });

  test('pergunta sem sentido não recebe resposta inventada', () {
    expect(analisarPergunta('xkcd zzzz qwerty').entendeu, isFalse);
    expect(respostaLocal('asdfgh jkl'), contains('Não tenho certeza'));
  });

  test('horário: usa o que o administrador cadastrou, senão manda ligar', () {
    expect(
        respostaLocal('que horas abre?'), contains('ainda não foi informado'));
    expect(respostaLocal('que horas abre?'), contains('(19) 3863-0229'));
    const ong =
        InfoOng(horarioFuncionamento: 'de segunda a sexta, das 7h às 17h');
    expect(
        respostaLocal('que horas abre?', ong: ong), contains('das 7h às 17h'));
  });

  test('PIX e dinheiro: só os dados cadastrados', () {
    expect(respostaLocal('qual a chave pix?'),
        contains('não informou uma chave PIX'));
    expect(
        respostaLocal('qual a chave pix?',
            ong: const InfoOng(chavePix: 'doe@casa.org')),
        contains('doe@casa.org'));
    expect(
        respostaLocal('posso doar em dinheiro?'), contains('agência 0171-6'));
  });

  test('necessidades: lista o que está aberto no app', () {
    expect(
        respostaLocal('do que vocês mais precisam?',
            maisPrecisados: ['Leite integral: faltam 100 un']),
        contains('Leite integral: faltam 100 un'));
  });

  test('endereço e contato da Casa da Criança', () {
    expect(respostaLocal('onde fica a casa da criança?'),
        contains('Rua Sílvio Galizoni, 238'));
    expect(respostaLocal('qual o telefone?'), contains('(19) 3863-0229'));
  });
}
