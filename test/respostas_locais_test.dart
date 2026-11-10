// Assistente sem a chave do Gemini (site publicado): responde as dúvidas comuns sem IA,
// em vez de mostrar uma mensagem técnica de configuração ao doador.
import 'package:educastock/features/chatbot/data/gemini_chat_service.dart';
import 'package:educastock/features/chatbot/domain/assistant_prompt.dart';
import 'package:educastock/features/chatbot/domain/respostas_locais.dart';
import 'package:educastock/features/chatbot/presentation/controllers/chat_controller.dart';
import 'package:educastock/features/donations/presentation/controllers/donation_needs_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('as perguntas sugeridas caem no assunto certo', () {
    expect(respostaLocal(kAssistantSuggestions[0]), contains('aceita alimentos'));
    expect(respostaLocal(kAssistantSuggestions[1]), contains('validade mínima'));
    expect(respostaLocal(kAssistantSuggestions[2]), contains('ponto de entrega'));
  });

  test('"o que vocês mais precisam" lista as necessidades abertas do app', () {
    final r = respostaLocal('O que vocês mais precisam agora?',
        maisPrecisados: ['Leite UHT integral: faltam 240 un (prioridade Crítica)']);
    expect(r, contains('- Leite UHT integral: faltam 240 un'));
    expect(respostaLocal('o que esta faltando?'), contains('"Necessidades"'));
  });

  test('protocolo e QR, dados sensíveis e assunto desconhecido', () {
    expect(respostaLocal('Cadê o QR da minha doação?'), contains('QR Code'));
    expect(respostaLocal('posso mandar meu cartão?'), contains('não peço'));
    expect(respostaLocal('quem ganhou o jogo ontem?'), contains('Posso ajudar com'));
  });

  test('o chat sem chave responde sem balão de erro', () async {
    final container = ProviderContainer(overrides: [
      geminiChatServiceProvider.overrideWithValue(
          GeminiChatService(apiKey: '', sender: (_, __, ___) async => 'não usar')),
      donationNeedsProvider.overrideWith((ref) => Stream.value(const [])),
    ]);
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).send('O que posso doar?');
    final ultima = container.read(chatControllerProvider).messages.last;
    expect(ultima.isError, isFalse);
    expect(ultima.text, contains('aceita alimentos'));
  });
}
