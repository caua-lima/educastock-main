import 'package:educastock/features/donations/domain/donation_validators.dart';
import 'package:educastock/features/donations/domain/entities/donation_item.dart';
import 'package:educastock/features/donations/domain/entities/donation_need.dart';
import 'package:educastock/features/donations/domain/entities/donation_point.dart';
import 'package:educastock/features/donations/domain/entities/donation_rules.dart';
import 'package:educastock/features/donations/domain/entities/donation_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 8, 12);
  const rules = DonationRules(); // validade mínima padrão: 30 dias

  DonationItem milk({DateTime? expiry, int qty = 24, bool hasExpiry = true}) =>
      DonationItem(
        category: 'alimento',
        description: 'Leite integral 1 L',
        quantity: qty,
        expiryDate: expiry,
        hasExpiry: hasExpiry,
      );

  group('DonationStatus (máquina de estados)', () {
    test('pendente pode ser aprovada, recusada, cancelada ou expirada', () {
      expect(DonationStatus.pendente.canTransitionTo(DonationStatus.aprovada), isTrue);
      expect(DonationStatus.pendente.canTransitionTo(DonationStatus.recusada), isTrue);
      expect(DonationStatus.pendente.canTransitionTo(DonationStatus.cancelada), isTrue);
      expect(DonationStatus.pendente.canTransitionTo(DonationStatus.expirada), isTrue);
    });

    test('pendente não pula direto para recebida', () {
      expect(DonationStatus.pendente.canTransitionTo(DonationStatus.recebida), isFalse);
    });

    test('estados terminais não saem do lugar', () {
      for (final s in [
        DonationStatus.recebida,
        DonationStatus.recebidaParcial,
        DonationStatus.recusada,
        DonationStatus.cancelada,
        DonationStatus.expirada,
      ]) {
        expect(s.isTerminal, isTrue);
        expect(s.canTransitionTo(DonationStatus.pendente), isFalse);
      }
    });

    test('valor gravado de recebida_parcial usa underscore e valor desconhecido cai em pendente', () {
      expect(DonationStatus.recebidaParcial.value, 'recebida_parcial');
      expect(DonationStatus.fromValue('recebida_parcial'), DonationStatus.recebidaParcial);
      expect(DonationStatus.fromValue('???'), DonationStatus.pendente);
    });
  });

  group('validateDonationItem (RN-D03)', () {
    test('item perecível sem validade é bloqueado', () {
      final r = validateDonationItem(milk(), rules: rules, now: now);
      expect(r.isValid, isFalse);
    });

    test('validade já vencida é bloqueada', () {
      final r = validateDonationItem(
        milk(expiry: DateTime(2026, 10, 1)),
        rules: rules,
        now: now,
      );
      expect(r.isValid, isFalse);
    });

    test('validade abaixo do mínimo não bloqueia, mas fica sujeita a avaliação', () {
      final r = validateDonationItem(
        milk(expiry: DateTime(2026, 10, 18)), // 10 dias < 30
        rules: rules,
        now: now,
      );
      expect(r.isValid, isTrue);
      expect(r.subjectToReview, isTrue);
    });

    test('validade acima do mínimo é aceita normalmente', () {
      final r = validateDonationItem(
        milk(expiry: DateTime(2027, 1, 20)), // > 30 dias
        rules: rules,
        now: now,
      );
      expect(r.isValid, isTrue);
      expect(r.subjectToReview, isFalse);
    });

    test('item sem validade (hasExpiry = false) dispensa a data', () {
      final r = validateDonationItem(milk(hasExpiry: false), rules: rules, now: now);
      expect(r.isValid, isTrue);
    });

    test('quantidade zero é bloqueada', () {
      final r = validateDonationItem(
        milk(qty: 0, hasExpiry: false),
        rules: rules,
        now: now,
      );
      expect(r.isValid, isFalse);
    });

    test('mínimo da necessidade tem precedência sobre o padrão', () {
      const need = DonationNeed(
        id: 'n1',
        categoryId: 'alimento',
        title: 'Arroz',
        priority: NeedPriority.alta,
        priorityRank: 2,
        suggestedQty: 100,
        pledgedQty: 0,
        remainingQty: 100,
        minShelfLifeDays: 90,
      );
      final r = validateDonationItem(
        milk(expiry: DateTime(2027, 1, 20)), // ~104 dias
        rules: rules,
        need: need,
        now: now,
      );
      expect(r.minShelfLifeDays, 90);
      expect(r.subjectToReview, isFalse);
    });

    test('oferta acima do restante a cobrir vira excedente sujeito a avaliação', () {
      const need = DonationNeed(
        id: 'n2',
        categoryId: 'alimento',
        title: 'Leite',
        priority: NeedPriority.critica,
        priorityRank: 1,
        suggestedQty: 100,
        pledgedQty: 90,
        remainingQty: 10,
      );
      final r = validateDonationItem(
        milk(qty: 24, hasExpiry: false),
        rules: rules,
        need: need,
        now: now,
      );
      expect(r.isValid, isTrue);
      expect(r.subjectToReview, isTrue);
    });
  });

  group('DonationPoint.acceptsWindow', () {
    // 2026-10-10 é sábado (weekday 6).
    const point = DonationPoint(
      id: 'p1',
      name: 'Sede',
      address: 'Rua A, 1',
      hours: [PointHours(weekday: 6, from: '09:00', to: '12:00')],
    );

    test('janela dentro do horário é aceita', () {
      expect(
        point.acceptsWindow(DateTime(2026, 10, 10, 9), DateTime(2026, 10, 10, 11)),
        isTrue,
      );
    });

    test('janela fora do horário ou em outro dia da semana é recusada', () {
      expect(
        point.acceptsWindow(DateTime(2026, 10, 10, 13), DateTime(2026, 10, 10, 15)),
        isFalse,
      );
      expect(
        point.acceptsWindow(DateTime(2026, 10, 9, 9), DateTime(2026, 10, 9, 11)),
        isFalse,
      );
    });
  });

  group('NeedPriority', () {
    test('crítica vem antes de alta e de normal', () {
      expect(NeedPriority.critica.rank, lessThan(NeedPriority.alta.rank));
      expect(NeedPriority.alta.rank, lessThan(NeedPriority.normal.rank));
    });
  });
}
