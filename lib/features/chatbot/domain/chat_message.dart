/// Quem escreveu a mensagem do chat.
enum ChatRole { user, model }

class ChatMessage {
  final ChatRole role;
  final String text;

  /// Mensagem de erro mostrada no balão do assistente (não entra no histórico enviado à IA).
  final bool isError;

  const ChatMessage({required this.role, required this.text, this.isError = false});

  bool get isUser => role == ChatRole.user;
}
