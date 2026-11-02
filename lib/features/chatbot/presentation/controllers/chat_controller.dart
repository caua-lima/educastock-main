import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/gemini_chat_service.dart';
import '../../domain/assistant_prompt.dart';
import '../../domain/chat_message.dart';

final geminiChatServiceProvider = Provider<GeminiChatService>((_) => GeminiChatService());

class ChatState {
  final List<ChatMessage> messages;
  final bool sending;

  const ChatState({required this.messages, this.sending = false});

  /// Só a saudação do assistente: ainda não houve conversa.
  bool get isFresh => messages.length <= 1;
}

const _greeting = ChatMessage(role: ChatRole.model, text: kAssistantGreeting);

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() => const ChatState(messages: [_greeting]);

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending) return;

    final history = state.messages;
    state = ChatState(
      messages: [...history, ChatMessage(role: ChatRole.user, text: text)],
      sending: true,
    );

    try {
      final reply = await ref.read(geminiChatServiceProvider).send(history, text);
      state = ChatState(
        messages: [...state.messages, ChatMessage(role: ChatRole.model, text: reply)],
      );
    } on ChatServiceException catch (e) {
      state = ChatState(
        messages: [
          ...state.messages,
          ChatMessage(role: ChatRole.model, text: e.message, isError: true),
        ],
      );
    }
  }

  /// Tenta de novo a última pergunta depois de um erro.
  Future<void> retry() async {
    final messages = [...state.messages];
    if (messages.isEmpty || !messages.last.isError) return;
    messages.removeLast();
    final lastUser = messages.lastIndexWhere((m) => m.isUser);
    if (lastUser < 0) return;
    final text = messages[lastUser].text;
    state = ChatState(messages: messages.sublist(0, lastUser));
    await send(text);
  }

  void reset() => state = const ChatState(messages: [_greeting]);
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
