import 'package:firebase_auth/firebase_auth.dart';

String mapAuthError(Object error, {String fallback = 'Erro inesperado.'}) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está em uso.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'operation-not-allowed':
        return 'Esta forma de entrar está desativada no momento.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde e tente novamente.';
      case 'requires-recent-login':
        return 'Por segurança, entre de novo e tente trocar a senha.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet.';
      case 'popup-closed-by-user':
        return 'Login com Google cancelado.';
      case 'popup-blocked':
        return 'O navegador bloqueou a janela do Google. Permita pop-ups para este site e tente de novo.';
      default:
        final msg = error.message?.trim();
        if (msg != null && msg.isNotEmpty) return msg;
        return 'Não foi possível entrar (${error.code}).';
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Sua conta não tem permissão para esta ação.';
      case 'unavailable':
        return 'Serviço indisponível no momento. Tente novamente.';
      default:
        final msg = error.message?.trim();
        if (msg != null && msg.isNotEmpty) return msg;
        return 'Não foi possível concluir agora (${error.code}).';
    }
  }

  final raw = error.toString().trim();
  if (raw.isNotEmpty && raw != 'Exception' && raw != 'Erro') return raw;
  return fallback;
}
