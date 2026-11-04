import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Converte um erro de carregamento numa mensagem em português, sem detalhes internos.
///
/// O erro técnico completo vai para o console ([debugPrint]) com [context], para que a
/// equipe consiga diagnosticar (ex.: qual consulta recebeu `permission-denied`).
String friendlyLoadError(Object error, {String context = 'dados'}) {
  debugPrint('[EducaStock] falha ao carregar $context: $error');
  final code = error is FirebaseException ? error.code : '';
  switch (code) {
    case 'permission-denied':
      return 'Sua conta não tem permissão para ver $context, ou a sessão expirou. '
          'Saia e entre de novo; se continuar, peça a um administrador para conferir '
          'se seu perfil está ativo.';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'Sem conexão com o servidor no momento. Verifique a internet e tente de novo.';
    case 'failed-precondition':
      return 'O servidor ainda está preparando esta consulta. Tente de novo em alguns minutos.';
    case 'unauthenticated':
      return 'Sua sessão expirou. Entre novamente para continuar.';
    default:
      return 'Não foi possível carregar $context agora. Tente de novo.';
  }
}
