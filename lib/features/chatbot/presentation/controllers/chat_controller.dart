import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/gemini_chat_service.dart';
import '../../domain/assistant_prompt.dart';
import '../../domain/chat_message.dart';
import '../../domain/info_ong.dart';
import '../../domain/respostas_locais.dart';
import 'info_ong_provider.dart';
import '../../../donations/presentation/controllers/donation_needs_provider.dart';

final geminiChatServiceProvider =
    Provider<GeminiChatService>((_) => GeminiChatService());

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

    // 1º o modelo de Machine Learning do próprio app (grátis, sem internet): reconhece a
    // intenção da pergunta e responde com os dados da ONG e as necessidades abertas.
    final ong = await _infoOng();
    final previa = classificadorAssistente.classificar(text);
    final mais = previa.confiavel && previa.intencao == 'necessidades'
        ? await _maisPrecisados()
        : const <String>[];
    final local = analisarPergunta(text, maisPrecisados: mais, ong: ong);
    final service = ref.read(geminiChatServiceProvider);
    if (local.entendeu || !service.isConfigured) {
      state = ChatState(
        messages: [
          ...state.messages,
          ChatMessage(role: ChatRole.model, text: local.resposta)
        ],
      );
      return;
    }

    // 2º só o que o modelo não entendeu vai para a IA externa (quando houver chave).
    try {
      final reply = await service.send(history, text);
      state = ChatState(
        messages: [
          ...state.messages,
          ChatMessage(role: ChatRole.model, text: reply)
        ],
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

  /// Dados da ONG cadastrados pelo administrador (ou os públicos, se não carregar).
  Future<InfoOng> _infoOng() async {
    try {
      return await ref
          .read(infoOngProvider.future)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      return InfoOng.padrao;
    }
  }

  /// As necessidades abertas mais urgentes, em texto. Vazio se não carregar a tempo.
  Future<List<String>> _maisPrecisados() async {
    try {
      await ref
          .read(donationNeedsProvider.future)
          .timeout(const Duration(seconds: 5));
      final abertas = ref.read(openNeedsProvider).valueOrNull ?? const [];
      return [
        for (final n in abertas.take(5))
          '${n.title}: faltam ${n.remainingQty} ${n.unit} (prioridade ${n.priority.label})',
      ];
    } catch (_) {
      return const [];
    }
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
