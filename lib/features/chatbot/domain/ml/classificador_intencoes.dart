import 'dart:math' as math;

/// Classificador de intenções do assistente: Naive Bayes multinomial treinado no
/// próprio aparelho, a partir das frases de exemplo de cada intenção. Não usa servidor
/// nem chave de API. Os atributos combinam palavras, pares de palavras e pedaços de 3 e
/// 4 letras de cada palavra; os pedaços deixam o modelo tolerante a erros de digitação
/// ("funcionamneto", "orario").
class ClassificadorIntencoes {
  final double alfa;
  final Map<String, Map<String, double>> _contagens = {};
  final Map<String, double> _totalPorIntencao = {};
  final Map<String, List<Map<String, double>>> _vetoresExemplos = {};
  final Set<String> _vocabulario = {};
  final Set<String> _palavrasConhecidas = {};

  ClassificadorIntencoes._(this.alfa);

  /// Treina com `{intenção: [frases de exemplo]}`.
  factory ClassificadorIntencoes.treinar(Map<String, List<String>> exemplos,
      {double alfa = 0.3}) {
    final c = ClassificadorIntencoes._(alfa);
    exemplos.forEach((intencao, frases) {
      final contagem = c._contagens.putIfAbsent(intencao, () => {});
      for (final frase in frases) {
        final atributos = atributosDe(frase);
        for (final a in atributos.entries) {
          contagem[a.key] = (contagem[a.key] ?? 0) + a.value;
          c._vocabulario.add(a.key);
        }
        c._palavrasConhecidas.addAll(palavrasDe(frase));
        c._vetoresExemplos
            .putIfAbsent(intencao, () => [])
            .add(_normalizarVetor(atributos));
      }
      c._totalPorIntencao[intencao] =
          contagem.values.fold(0.0, (s, v) => s + v);
    });
    return c;
  }

  Iterable<String> get intencoes => _contagens.keys;

  /// A intenção mais provável, a confiança (0 a 1) e a segunda colocada.
  ResultadoIntencao classificar(String texto) {
    final atributos = atributosDe(texto);
    final palavras = palavrasDe(texto);
    if (atributos.isEmpty) {
      return const ResultadoIntencao('desconhecida', 0, 0, null);
    }

    // Log-probabilidade de cada intenção (prioris iguais: as intenções têm o mesmo peso).
    final v = _vocabulario.length.toDouble();
    final pontuacao = <String, double>{};
    for (final intencao in _contagens.keys) {
      final contagem = _contagens[intencao]!;
      final total = _totalPorIntencao[intencao]!;
      var s = 0.0;
      atributos.forEach((a, n) {
        if (!_vocabulario.contains(a)) return;
        s += n * math.log(((contagem[a] ?? 0) + alfa) / (total + alfa * v));
      });
      pontuacao[intencao] = s;
    }
    // Probabilidades com "temperatura" pelo número de atributos: o Naive Bayes puro dá
    // certezas exageradas em textos longos.
    final nAtributos =
        atributos.values.fold(0.0, (s, n) => s + n).clamp(1.0, double.infinity);
    final escala = 6.0 / math.sqrt(nAtributos);
    final maior = pontuacao.values.reduce(math.max);
    final exp = {
      for (final e in pontuacao.entries)
        e.key: math.exp((e.value - maior) * escala)
    };
    final soma = exp.values.fold(0.0, (s, x) => s + x);
    final ordem = exp.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final melhor = ordem.first.key;

    // Semelhança com os exemplos da intenção vencedora: separa pergunta do assunto de
    // pergunta fora do assunto (o Naive Bayes sempre escolhe alguma intenção).
    final vetor = _normalizarVetor(atributos);
    final semelhanca = _vetoresExemplos[melhor]!
        .map((e) => _cosseno(vetor, e))
        .reduce(math.max);
    final conhecidas = palavras.where(_palavrasConhecidas.contains).length;
    final cobertura = palavras.isEmpty ? 0.0 : conhecidas / palavras.length;

    return ResultadoIntencao(
      melhor,
      ordem.first.value / soma,
      semelhanca * (0.5 + 0.5 * cobertura),
      ordem.length > 1 ? ordem[1].key : null,
    );
  }

  // ─── Atributos ────────────────────────────────────────────────────────────

  static const _paradas = {
    'a',
    'o',
    'as',
    'os',
    'um',
    'uma',
    'de',
    'do',
    'da',
    'dos',
    'das',
    'em',
    'no',
    'na',
    'nos',
    'nas',
    'e',
    'que',
    'para',
    'pra',
    'pro',
    'por',
    'com',
    'se',
    'me',
    'eu',
    'voce',
    'voces',
    'vc',
    'vcs',
    'ao',
    'ou',
    'mais',
    'muito',
    'esse',
    'essa',
    'isso',
    'este',
    'esta',
    'ai',
    'la',
    'ja',
    'tem',
    'sobre',
    'qual',
    'quais',
    'como',
    'quando',
    'onde',
    'favor',
    'gostaria',
    'saber',
    'queria',
    'quero',
    'poderia',
    'pode',
    'posso',
    'seria',
    'casa',
    'crianca',
    'ong',
    'instituicao',
    'educastock',
    'oi',
    'ola',
  };
  // Palavras de pergunta que mudam o sentido: ficam como atributo só quando sozinhas
  // não bastam ("onde fica" × "quando abre").
  static const _interrogativas = {
    'qual',
    'quais',
    'como',
    'quando',
    'onde',
    'posso',
    'pode',
    'que'
  };

  static String normalizar(String texto) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const para = 'aaaaaeeeeiiiiooooouuuuc';
    final b = StringBuffer();
    for (final ch in texto.toLowerCase().split('')) {
      final i = de.indexOf(ch);
      b.write(i >= 0 ? para[i] : ch);
    }
    return b
        .toString()
        .replaceAll('\u{1F60D}', ' amei ')
        .replaceAll('\u{2764}', ' amei ')
        .replaceAll('\u{1F64F}', ' obrigado ')
        .replaceAll('\u{1F44D}', ' ok ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  }

  static List<String> palavrasDe(String texto) => normalizar(texto)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  static Map<String, double> atributosDe(String texto) {
    final todas = palavrasDe(texto);
    final f = <String, double>{};
    void soma(String k, double v) => f[k] = (f[k] ?? 0) + v;
    final uteis = <String>[];
    for (final p in todas) {
      if (_interrogativas.contains(p)) soma('q:$p', 0.6);
      if (_paradas.contains(p)) continue;
      uteis.add(p);
      soma('w:$p', 1.0);
      final pad = '_${p}_';
      for (final n in const [3, 4]) {
        for (var i = 0; i + n <= pad.length; i++) {
          soma('c:${pad.substring(i, i + n)}', 0.25);
        }
      }
    }
    for (var i = 0; i + 1 < uteis.length; i++) {
      soma('b:${uteis[i]}_${uteis[i + 1]}', 0.8);
    }
    return f;
  }

  static Map<String, double> _normalizarVetor(Map<String, double> v) {
    final norma = math.sqrt(v.values.fold(0.0, (s, x) => s + x * x));
    if (norma == 0) return const {};
    return {for (final e in v.entries) e.key: e.value / norma};
  }

  static double _cosseno(Map<String, double> a, Map<String, double> b) {
    var s = 0.0;
    final (menor, maior) = a.length <= b.length ? (a, b) : (b, a);
    menor.forEach((k, x) {
      final y = maior[k];
      if (y != null) s += x * y;
    });
    return s;
  }
}

class ResultadoIntencao {
  final String intencao;

  /// Probabilidade da intenção vencedora entre as conhecidas (0 a 1).
  final double confianca;

  /// Quanto a pergunta se parece com os exemplos dessa intenção (0 a 1).
  final double semelhanca;
  final String? segunda;

  const ResultadoIntencao(
      this.intencao, this.confianca, this.semelhanca, this.segunda);

  /// Só responde quando o modelo está razoavelmente seguro e a pergunta é do assunto.
  bool get confiavel => confianca >= 0.45 && semelhanca >= 0.20;

  @override
  String toString() =>
      '$intencao (conf. ${(confianca * 100).round()}%, semelh. ${(semelhanca * 100).round()}%)';
}
