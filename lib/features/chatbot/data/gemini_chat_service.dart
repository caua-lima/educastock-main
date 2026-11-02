import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../domain/assistant_prompt.dart';
import '../domain/chat_message.dart';

/// Chave da API lida em tempo de compilação, sem ficar no código-fonte:
///
/// ```
/// flutter run -d chrome --dart-define=GEMINI_API_KEY=SUA_CHAVE
/// ```
const String _kGeminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

/// Erro com texto pronto para o usuário.
class ChatServiceException implements Exception {
  final String message;
  const ChatServiceException(this.message);

  @override
  String toString() => message;
}

/// Envia a pergunta a um modelo específico. Separado para permitir testes sem rede.
typedef ModelSender = Future<String> Function(
  String model,
  List<ChatMessage> history,
  String text,
);

/// Conversa com o Gemini (pacote `google_generative_ai`).
///
/// Instancia o `gemini-2.5-flash` com instruções de sistema para agir como o assistente
/// do EducaStock. Se o Google devolver "modelo indisponível" (ele já foi desativado para
/// contas novas) ou sobrecarga, tenta o próximo da lista e lembra qual funcionou.
class GeminiChatService {
  static const List<String> models = [
    'gemini-2.5-flash',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
  ];

  final String apiKey;
  final ModelSender _send;
  int _preferred = 0;

  GeminiChatService({String? apiKey, ModelSender? sender})
      : apiKey = apiKey ?? _kGeminiApiKey,
        _send = sender ?? _defaultSender(apiKey ?? _kGeminiApiKey);

  bool get isConfigured => apiKey.isNotEmpty;

  static ModelSender _defaultSender(String key) {
    return (model, history, text) async {
      final generative = GenerativeModel(
        model: model,
        apiKey: key,
        systemInstruction: Content.system(kAssistantSystemPrompt),
        generationConfig: GenerationConfig(temperature: 0.5, maxOutputTokens: 700),
      );
      final chat = generative.startChat(history: [
        for (final m in history)
          if (!m.isError)
            m.isUser ? Content.text(m.text) : Content.model([TextPart(m.text)]),
      ]);
      final response = await chat.sendMessage(Content.text(text));
      return (response.text ?? '').trim();
    };
  }

  /// Histórico sem a saudação e sem balões de erro; precisa começar por uma fala do usuário.
  static List<ChatMessage> prepareHistory(List<ChatMessage> messages) {
    final clean = messages.where((m) => !m.isError).toList();
    final firstUser = clean.indexWhere((m) => m.isUser);
    return firstUser < 0 ? const [] : clean.sublist(firstUser);
  }

  Future<String> send(List<ChatMessage> history, String text) async {
    if (!isConfigured) {
      throw const ChatServiceException(
        'O assistente ainda não foi configurado. Inicie o app com '
        '--dart-define=GEMINI_API_KEY=SUA_CHAVE.',
      );
    }
    final prepared = prepareHistory(history);

    ChatServiceException? last;
    for (var step = 0; step < models.length; step++) {
      final index = (_preferred + step) % models.length;
      try {
        final reply = await _send(models[index], prepared, text);
        if (reply.isEmpty) {
          last = const ChatServiceException(
            'Não consegui formular uma resposta. Pode reescrever a pergunta?',
          );
          continue;
        }
        _preferred = index;
        return reply;
      } on GenerativeAIException catch (e) {
        debugPrint('[Chat] ${models[index]}: ${e.message}');
        if (_isKeyProblem(e.message)) {
          throw const ChatServiceException(
            'A chave do Gemini não é válida. Confira o valor de GEMINI_API_KEY.',
          );
        }
        last = const ChatServiceException(
          'O assistente está indisponível agora. Tente de novo em instantes.',
        );
      } catch (e) {
        debugPrint('[Chat] ${models[index]}: $e');
        last = const ChatServiceException(
          'Não consegui falar com o assistente. Verifique sua conexão e tente de novo.',
        );
      }
    }
    throw last ??
        const ChatServiceException('Não consegui responder agora. Tente de novo.');
  }

  static bool _isKeyProblem(String message) {
    final m = message.toLowerCase();
    return m.contains('api key') || m.contains('api_key') || m.contains('permission_denied');
  }
}
