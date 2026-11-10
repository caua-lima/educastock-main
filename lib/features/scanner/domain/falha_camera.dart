// Por que a câmera não abriu — cada caso tem mensagem e ação próprias.
// Antes, toda falha final aparecia como "permita o acesso à câmera".

enum FalhaCamera {
  /// A pessoa (ou o navegador) negou o acesso à câmera.
  permissaoNegada,

  /// Nenhuma câmera encontrada no aparelho/computador.
  semCamera,

  /// A câmera existe, mas outro aplicativo/aba está usando.
  ocupada,

  /// O navegador/aparelho não oferece câmera para páginas (ex.: sem HTTPS).
  naoSuportada,

  /// O leitor de códigos não carregou (rede) — a câmera em si pode estar ok.
  leitorIndisponivel,

  /// A câmera não respondeu dentro do tempo (pedido de permissão esquecido
  /// aberto, driver travado).
  semResposta,

  /// Outra falha.
  desconhecida,
}

/// Classifica a falha a partir do erro lançado pelo mobile_scanner/navegador.
/// Usa o texto do erro porque a web só informa o nome do DOMException
/// (NotAllowedError, NotFoundError, NotReadableError…) dentro da mensagem.
FalhaCamera classificarFalhaCamera(Object erro) {
  final t = erro.toString().toLowerCase();
  bool tem(List<String> termos) => termos.any(t.contains);
  if (tem(['notallowederror', 'permissiondenied', 'permission denied', 'permission', 'denied', 'securityerror'])) {
    return FalhaCamera.permissaoNegada;
  }
  if (tem(['notreadableerror', 'trackstarterror', 'could not start video source', 'in use', 'busy', 'aborterror'])) {
    return FalhaCamera.ocupada;
  }
  if (tem(['notfounderror', 'devicesnotfounderror', 'requested device not found', 'no camera', 'overconstrainederror'])) {
    return FalhaCamera.semCamera;
  }
  if (tem(['notsupportederror', 'unsupported', 'not supported', 'mediadevices', 'insecure'])) {
    return FalhaCamera.naoSuportada;
  }
  return FalhaCamera.desconhecida;
}

extension FalhaCameraTexto on FalhaCamera {
  /// Vale a pena tentar de novo sozinho (ex.: iOS liberando a câmera)?
  bool get repetirAutomaticamente =>
      this == FalhaCamera.ocupada || this == FalhaCamera.desconhecida;

  String get titulo => switch (this) {
        FalhaCamera.permissaoNegada => 'Sem permissão para usar a câmera',
        FalhaCamera.semCamera => 'Nenhuma câmera encontrada',
        FalhaCamera.ocupada => 'A câmera está em uso',
        FalhaCamera.naoSuportada => 'Câmera indisponível neste navegador',
        FalhaCamera.leitorIndisponivel => 'Leitor de códigos não carregou',
        FalhaCamera.semResposta => 'A câmera não respondeu',
        FalhaCamera.desconhecida => 'Não foi possível abrir a câmera',
      };

  String get explicacao => switch (this) {
        FalhaCamera.permissaoNegada =>
          'Libere a câmera para este site nas permissões do navegador (ícone de cadeado ao lado do endereço) e toque em Tentar novamente.',
        FalhaCamera.semCamera =>
          'Conecte uma câmera ou use outro aparelho. Você pode digitar o código.',
        FalhaCamera.ocupada =>
          'Feche outros aplicativos ou abas que estejam usando a câmera e toque em Tentar novamente.',
        FalhaCamera.naoSuportada =>
          'Abra o EducaStock pelo endereço seguro (https) em um navegador atualizado, ou digite o código.',
        FalhaCamera.leitorIndisponivel =>
          'Verifique a internet e toque em Tentar novamente. Enquanto isso, digite o código.',
        FalhaCamera.semResposta =>
          'Se o navegador pediu permissão, responda ao pedido e toque em Tentar novamente. Você também pode digitar o código.',
        FalhaCamera.desconhecida =>
          'Toque em Tentar novamente. Se continuar, digite o código.',
      };
}
