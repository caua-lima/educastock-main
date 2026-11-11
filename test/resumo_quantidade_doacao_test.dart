// Resumo de quantidade da doação: nunca somar quilos com unidades.
import 'package:educastock/features/donations/domain/entities/donation.dart';
import 'package:educastock/features/donations/domain/entities/donation_item.dart';
import 'package:educastock/features/donations/domain/entities/donation_status.dart';
import 'package:flutter_test/flutter_test.dart';

Donation _doacao(List<DonationItem> itens) => Donation(
      id: 'd1',
      protocol: 'DOA-2026-000001',
      donorId: 'u1',
      donorSnapshot: const DonorSnapshot(displayName: 'Ana'),
      status: DonationStatus.pendente,
      pointId: 'p1',
      items: itens,
    );

void main() {
  test('mesma unidade: soma com a unidade', () {
    expect(
      _doacao(const [
        DonationItem(category: 'alimento', description: 'Leite 1 L', quantity: 24, hasExpiry: false),
        DonationItem(category: 'alimento', description: 'Arroz 5 kg', quantity: 10, hasExpiry: false),
      ]).resumoQuantidade,
      '34 unidades',
    );
    expect(
      _doacao(const [
        DonationItem(category: 'alimento', description: 'Leite', quantity: 1, hasExpiry: false),
      ]).resumoQuantidade,
      '1 unidade',
    );
    expect(
      _doacao(const [
        DonationItem(category: 'alimento', description: 'Batata', quantity: 16, unit: 'kg', hasExpiry: false),
      ]).resumoQuantidade,
      '16 kg',
    );
  });

  test('unidades diferentes: conta os itens', () {
    expect(
      _doacao(const [
        DonationItem(category: 'alimento', description: 'Batata', quantity: 10, unit: 'kg', hasExpiry: false),
        DonationItem(category: 'alimento', description: 'Leite', quantity: 6, hasExpiry: false),
      ]).resumoQuantidade,
      '2 itens',
    );
  });
}
