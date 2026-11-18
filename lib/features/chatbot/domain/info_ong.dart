/// O que o assistente sabe da Casa da Criança. Os valores padrão vêm de fontes públicas
/// (site oficial casadacriancaccs.com.br e imprensa de Itapira); o administrador completa
/// ou corrige em Configurações › Informações da ONG (documento `settings/ong_info`).
/// Campo vazio = o assistente diz que não tem a informação e indica o telefone.
class InfoOng {
  final String nome;
  final String endereco;
  final String telefone;
  final String whatsapp;
  final String email;
  final String redeSocial;
  final String horarioFuncionamento;
  final String horarioEntregas;
  final String chavePix;
  final String contaBancaria;
  final String publicoAtendido;
  final String observacoes;

  const InfoOng({
    this.nome = 'Casa da Criança "Celencina Caldas Sarkis"',
    this.endereco =
        'Rua Sílvio Galizoni, 238, bairro Cubatão, Itapira - SP, CEP 13972-340',
    this.telefone = '(19) 3863-0229',
    this.whatsapp = '',
    this.email = '',
    this.redeSocial = '@celencinacaldassarkis',
    this.horarioFuncionamento =
        'de segunda a quarta, das 7h às 17h, e às quintas e sextas, das 7h às 16h30 (fechada aos sábados e domingos)',
    this.horarioEntregas = '',
    this.chavePix = '',
    this.contaBancaria =
        'Banco do Brasil, agência 0171-6, conta corrente 12955-0, favorecido Casa da Criança '
            'Celencina Caldas Sarkis (CNPJ 49.917.651/0001-30)',
    this.publicoAtendido =
        'cerca de 147 crianças e adolescentes de 4 a 15 anos, no período contrário ao da escola',
    this.observacoes = '',
  });

  static const padrao = InfoOng();

  /// Lê `settings/ong_info`. Campo ausente mantém o padrão; texto vazio apaga o padrão.
  factory InfoOng.fromMap(Map<String, dynamic>? m) {
    if (m == null) return padrao;
    String v(String chave, String atual) {
      final x = m[chave];
      return x is String ? x.trim() : atual;
    }

    const p = padrao;
    return InfoOng(
      nome: v('nome', p.nome),
      endereco: v('endereco', p.endereco),
      telefone: v('telefone', p.telefone),
      whatsapp: v('whatsapp', p.whatsapp),
      email: v('email', p.email),
      redeSocial: v('redeSocial', p.redeSocial),
      horarioFuncionamento: v('horarioFuncionamento', p.horarioFuncionamento),
      horarioEntregas: v('horarioEntregas', p.horarioEntregas),
      chavePix: v('chavePix', p.chavePix),
      contaBancaria: v('contaBancaria', p.contaBancaria),
      publicoAtendido: v('publicoAtendido', p.publicoAtendido),
      observacoes: v('observacoes', p.observacoes),
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'endereco': endereco,
        'telefone': telefone,
        'whatsapp': whatsapp,
        'email': email,
        'redeSocial': redeSocial,
        'horarioFuncionamento': horarioFuncionamento,
        'horarioEntregas': horarioEntregas,
        'chavePix': chavePix,
        'contaBancaria': contaBancaria,
        'publicoAtendido': publicoAtendido,
        'observacoes': observacoes,
      };

  /// Como falar com a ONG, com o que estiver preenchido.
  String get contatos => [
        if (telefone.isNotEmpty) 'telefone $telefone',
        if (whatsapp.isNotEmpty) 'WhatsApp $whatsapp',
        if (email.isNotEmpty) 'e-mail $email',
      ].join(', ');

  /// "ligue para (19) …" ou, sem telefone, "fale com a equipe".
  String get ondePerguntar => telefone.isNotEmpty
      ? 'ligue para $telefone'
      : (whatsapp.isNotEmpty
          ? 'chame no WhatsApp $whatsapp'
          : 'fale com a equipe');
}
