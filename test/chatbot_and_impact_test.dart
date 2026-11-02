import 'dart:convert';
import 'package:educastock/features/chatbot/data/gemini_chat_service.dart';
import 'package:educastock/features/chatbot/domain/chat_message.dart';
import 'package:educastock/features/donation_ops/domain/impact_message.dart';
import 'package:educastock/features/donations/data/donation_receipt_pdf.dart';
import 'package:educastock/features/donations/domain/entities/donation.dart';
import 'package:educastock/features/donations/domain/entities/donation_item.dart';
import 'package:educastock/features/donations/domain/entities/donation_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  group('GeminiChatService', () {
    const history = [
      ChatMessage(role: ChatRole.model, text: 'Olá!'),
      ChatMessage(role: ChatRole.user, text: 'O que posso doar?'),
      ChatMessage(role: ChatRole.model, text: 'Alimentos, higiene…'),
      ChatMessage(role: ChatRole.model, text: 'Erro', isError: true),
    ];

    test('sem chave configurada, explica como configurar', () {
      final service = GeminiChatService(apiKey: '', sender: (_, __, ___) async => 'x');
      expect(service.isConfigured, isFalse);
      expect(
        () => service.send(const [], 'oi'),
        throwsA(isA<ChatServiceException>().having((e) => e.message, 'mensagem', contains('GEMINI_API_KEY'))),
      );
    });

    test('usa o gemini-2.5-flash primeiro', () async {
      final tried = <String>[];
      final service = GeminiChatService(apiKey: 'k', sender: (model, _, __) async {
        tried.add(model);
        return 'Resposta';
      });
      expect(await service.send(const [], 'oi'), 'Resposta');
      expect(tried, ['gemini-2.5-flash']);
    });

    test('se o modelo estiver indisponível, tenta o próximo e lembra o que funcionou', () async {
      final tried = <String>[];
      final service = GeminiChatService(apiKey: 'k', sender: (model, _, __) async {
        tried.add(model);
        if (model == 'gemini-2.5-flash') {
          throw ServerException('models/gemini-2.5-flash is no longer available');
        }
        return 'Ok via $model';
      });

      expect(await service.send(const [], 'oi'), 'Ok via gemini-flash-lite-latest');
      expect(tried, ['gemini-2.5-flash', 'gemini-flash-lite-latest']);

      tried.clear();
      await service.send(const [], 'de novo');
      expect(tried, ['gemini-flash-lite-latest']); // não volta ao que falhou
    });

    test('chave inválida para na hora, sem tentar outros modelos', () async {
      var calls = 0;
      final service = GeminiChatService(apiKey: 'k', sender: (_, __, ___) async {
        calls++;
        throw InvalidApiKey('API key not valid');
      });
      await expectLater(
        service.send(const [], 'oi'),
        throwsA(isA<ChatServiceException>().having((e) => e.message, 'mensagem', contains('chave'))),
      );
      expect(calls, 1);
    });

    test('todos os modelos falhando devolve erro amigável', () async {
      final service = GeminiChatService(apiKey: 'k', sender: (_, __, ___) async {
        throw ServerException('overloaded');
      });
      await expectLater(service.send(const [], 'oi'), throwsA(isA<ChatServiceException>()));
    });

    test('histórico enviado começa pelo usuário e ignora balões de erro', () {
      final prepared = GeminiChatService.prepareHistory(history);
      expect(prepared.first.isUser, isTrue);
      expect(prepared.any((m) => m.isError), isFalse);
      expect(prepared.map((m) => m.text), ['O que posso doar?', 'Alimentos, higiene…']);
      expect(
        GeminiChatService.prepareHistory(const [ChatMessage(role: ChatRole.model, text: 'oi')]),
        isEmpty,
      );
    });
  });

  group('buildImpactMessage', () {
    test('um item, setor conhecido', () {
      final text = buildImpactMessage(
        donorName: 'João Ricardo Menezes',
        itemDescriptions: ['Leite integral 1 L'],
        sector: 'Cozinha da Creche (Lanches)',
      );
      expect(text, startsWith('João, o item "Leite integral 1 L" que você doou foi destinado'));
      expect(text, contains('à Cozinha da Creche, para o preparo dos lanches'));
      expect(text, contains('Casa da Criança'));
    });

    test('vários itens usam o plural', () {
      final text = buildImpactMessage(
        donorName: 'Ana',
        itemDescriptions: ['Arroz', 'Feijão', 'Macarrão', 'Óleo'],
        sector: 'Cestas Básicas para Famílias',
      );
      expect(text, contains('os itens "Arroz", "Feijão" e mais 2 que você doou foram destinados'));
    });

    test('setor livre e nome vazio não quebram', () {
      final text = buildImpactMessage(donorName: '', itemDescriptions: [], sector: 'Outro destino');
      expect(text, startsWith('Olá, o item'));
      expect(text, contains('a Outro destino'));
    });
  });

  group('DonationReceiptPdf', () {
    test('gera o recibo com itens aceitos e impacto', () async {
      final donation = Donation(
        id: 'd1',
        protocol: 'DOA-2026-000123',
        donorId: 'u1',
        donorSnapshot: const DonorSnapshot(displayName: 'João Menezes'),
        status: DonationStatus.recebida,
        pointId: 'p1',
        items: const [
          DonationItem(category: 'alimento', description: 'Leite 1 L', quantity: 24, hasExpiry: false),
        ],
        receivedItems: const [ReceivedItemInfo(index: 0, receivedQty: 24)],
        impact: DonationImpact(
          sector: 'Cozinha da Creche (Lanches)',
          message: 'Obrigado pelo leite!',
          usedAt: DateTime(2026, 11, 5),
        ),
      );
      final bytes = await DonationReceiptPdf.build(donation, now: DateTime(2026, 11, 6));
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1500));
    });
  });
}
