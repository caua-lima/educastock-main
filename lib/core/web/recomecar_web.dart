import 'package:web/web.dart' as web;

/// Web: recarrega o app na tela de login, sem nenhuma leitura da sessão anterior.
void recomecarNoLogin() => web.window.location.assign('/login');

/// Web: recarrega o app já logado em [caminho]. Usado depois de criar a conta (e-mail ou
/// Google): o login acontece antes de o perfil ser gravado no banco, e as leituras abertas
/// nesse instante voltam "sem permissão" e não se refazem (telas vazias até sair e entrar).
void recomecarEm(String caminho) => web.window.location.assign(caminho);
