// RF17 — exportação dos dados do doador (LGPD): o arquivo JSON traz o perfil e todas as
// doações, é JSON válido e não perde nenhuma doação.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:educastock/features/donations/domain/donor_data_export.dart';
import 'package:educastock/features/donations/domain/entities/donation.dart';
import 'package:educastock/features/donations/domain/entities/donor_profile.dart';
import 'package:flutter_test/flutter_test.dart';

Donation _doacao(String id, String status, DateTime criada) => Donation.fromMap({
      'protocol': 'DOA-2026-00000$id',
      'donorId': 'd1',
      'donorSnapshot': {'displayName': 'Ana'},
      'status': status,
      'items': [
        {'description': 'Leite UHT', 'category': 'alimento', 'quantity': 12, 'unit': 'L', 'hasExpiry': true,
         'expiryDate': Timestamp.fromDate(DateTime(2027, 1, 10))},
      ],
      'pointId': 'ponto-sede',
      'createdAt': Timestamp.fromDate(criada),
      if (status == 'recebida')
        'impact': {'sector': 'Cozinha', 'message': 'Virou o café da manhã', 'byName': 'Neusa'},
    }, id);

void main() {
  test('gera JSON válido com perfil e todas as doações, da mais nova para a mais antiga', () {
    final perfil = DonorProfile(
      uid: 'd1',
      displayName: 'Ana Souza',
      donorType: DonorType.pf,
      phone: '(19) 99999-0000',
      city: 'Itapira',
      consentAt: DateTime(2026, 3, 1),
      prefs: const DonorPrefs(anonimo: true, notificacoes: false),
    );
    final texto = buildDonorDataExport(
      email: 'ana@exemplo.test',
      profile: perfil,
      donations: [
        _doacao('1', 'recebida', DateTime(2026, 5, 1)),
        _doacao('2', 'pendente', DateTime(2026, 9, 1)),
      ],
      now: DateTime(2026, 11, 9),
    );
    final json = jsonDecode(texto) as Map<String, dynamic>;
    expect(json['perfil']['nome'], 'Ana Souza');
    expect(json['perfil']['email'], 'ana@exemplo.test');
    expect(json['perfil']['doacaoAnonima'], isTrue);
    final doacoes = json['doacoes'] as List;
    expect(doacoes, hasLength(2));
    expect(doacoes.first['protocolo'], 'DOA-2026-000002', reason: 'mais nova primeiro');
    expect(doacoes.last['impacto']['setor'], 'Cozinha');
    expect(doacoes.last['itens'].single['quantidade'], 12);
  });

  test('doador sem doações ainda recebe o arquivo com o perfil', () {
    final texto = buildDonorDataExport(
      email: 'x@exemplo.test',
      profile: const DonorProfile(uid: 'x', displayName: 'Xis', donorType: DonorType.pj),
      donations: const [],
    );
    final json = jsonDecode(texto) as Map<String, dynamic>;
    expect(json['doacoes'], isEmpty);
    expect(json['perfil']['tipo'], DonorType.pj.label);
  });
}
