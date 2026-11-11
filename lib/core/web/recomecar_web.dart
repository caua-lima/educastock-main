import 'package:web/web.dart' as web;

/// Web: recarrega o app na tela de login, sem nenhuma leitura da sessão anterior.
void recomecarNoLogin() => web.window.location.assign('/login');
