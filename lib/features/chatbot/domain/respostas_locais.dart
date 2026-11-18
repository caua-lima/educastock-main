import 'info_ong.dart';
import 'ml/classificador_intencoes.dart';
import 'ml/intencoes.dart';

/// Classificador treinado uma vez (na primeira pergunta) com as frases de [kIntencoes].
final ClassificadorIntencoes classificadorAssistente =
    ClassificadorIntencoes.treinar({
  for (final i in kIntencoes) i.id: i.exemplos,
});
final Map<String, Intencao> _porId = {for (final i in kIntencoes) i.id: i};

/// Resposta do assistente pelo modelo local (Machine Learning no aparelho, sem custo e
/// sem internet). [maisPrecisados] traz as necessidades abertas já em texto (ex.:
/// "Leite UHT integral: faltam 240 un (prioridade Crítica)").
String respostaLocal(String pergunta,
        {List<String> maisPrecisados = const [],
        InfoOng ong = InfoOng.padrao}) =>
    analisarPergunta(pergunta, maisPrecisados: maisPrecisados, ong: ong)
        .resposta;

/// Intenção reconhecida e resposta (útil para testes e para decidir se chama a IA externa).
({ResultadoIntencao resultado, String resposta, bool entendeu})
    analisarPergunta(
  String pergunta, {
  List<String> maisPrecisados = const [],
  InfoOng ong = InfoOng.padrao,
}) {
  final contexto = ContextoResposta(ong: ong, maisPrecisados: maisPrecisados);
  final r = classificadorAssistente.classificar(pergunta);
  if (!r.confiavel)
    return (
      resultado: r,
      resposta: respostaNaoEntendi(contexto),
      entendeu: false
    );
  return (
    resultado: r,
    resposta: _porId[r.intencao]!.responder(contexto),
    entendeu: true
  );
}
