import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/gemini_chat_service.dart';
import '../../domain/assistant_prompt.dart';
import '../../domain/chat_message.dart';
import '../../domain/info_ong.dart';
import '../../domain/ml/conversa.dart';
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
    // intenção (ou várias), procura o item nas necessidades abertas e usa a pergunta
    // anterior como contexto.
    final ong = await _infoOng();
    final necessidades = await _necessidades();
    final local = responderConversa(
      text,
      ong: ong,
      necessidades: necessidades,
      perguntaAnterior: _ultimaEntendida,
    );
    if (local.entendeu) _ultimaEntendida = text;
    final service = ref.read(geminiChatServiceProvider);
    if (local.entendeu || !service.isConfigured) {
      state = ChatState(
        messages: [
          ...state.messages,
          ChatMessage(
            role: ChatRole.model,
            text: local.texto,
            sugestoes: local.sugestoes,
          ),
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

  /// Última pergunta que o modelo entendeu: contexto para "e no sábado?".
  String? _ultimaEntendida;

  void reset() {
    _ultimaEntendida = null;
    state = const ChatState(messages: [_greeting]);
  }

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

  /// As necessidades abertas, das mais urgentes para as menos. Vazio se não carregar a
  /// tempo (o assistente responde sem a lista).
  Future<List<NecessidadeChat>> _necessidades() async {
    try {
      await ref
          .read(donationNeedsProvider.future)
          .timeout(const Duration(seconds: 4));
      final abertas = ref.read(openNeedsProvider).valueOrNull ?? const [];
      return [
        for (final n in abertas)
          NecessidadeChat(
            titulo: n.title,
            falta: n.remainingQty,
            unidade: n.unit,
            prioridade: n.priority.label,
            validadeMinimaDias: n.minShelfLifeDays,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);
