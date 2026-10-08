import 'package:firebase_auth/firebase_auth.dart';

String mapAuthError(Object error, {String fallback = 'Erro inesperado.'}) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Este e-mail ja esta em uso.';
      case 'invalid-email':
        return 'E-mail invalido.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'operation-not-allowed':
        return 'Metodo de autenticacao desabilitado no Firebase.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde e tente novamente.';
      case 'requires-recent-login':
        return 'Por seguranca, faca login novamente e tente trocar a senha.';
      case 'network-request-failed':
        return 'Sem conexao. Verifique sua internet.';
      case 'popup-closed-by-user':
        return 'Login com Google cancelado.';
      case 'popup-blocked':
        return 'Popup bloqueado pelo navegador. Permita popups e tente de novo.';
      default:
        final msg = error.message?.trim();
        if (msg != null && msg.isNotEmpty) return msg;
        return 'Erro de autenticacao (${error.code}).';
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Permissao negada no Firestore. Revise as regras de users.';
      case 'unavailable':
        return 'Servico indisponivel no momento. Tente novamente.';
      default:
        final msg = error.message?.trim();
        if (msg != null && msg.isNotEmpty) return msg;
        return 'Erro do Firebase (${error.code}).';
    }
  }

  final raw = error.toString().trim();
  if (raw.isNotEmpty && raw != 'Exception' && raw != 'Erro') return raw;
  return fallback;
}
