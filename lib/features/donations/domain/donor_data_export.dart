import 'dart:convert';

import 'entities/donation.dart';
import 'entities/donor_profile.dart';

/// Portabilidade dos dados (LGPD, art. 18, V): tudo o que o EducaStock guarda sobre o
/// doador e as doações dele, num arquivo JSON legível (RF17).
///
/// Função pura — monta o conteúdo; quem chama decide como entregar (download ou
/// compartilhamento).
String buildDonorDataExport({
  required String email,
  required DonorProfile profile,
  required List<Donation> donations,
  DateTime? now,
}) {
  String? iso(DateTime? d) => d?.toIso8601String();
  final ordered = [...donations]
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));

  final data = {
    'geradoEm': iso(now ?? DateTime.now()),
    'origem': 'EducaStock — Portal do Doador (ONG Casa da Criança, Itapira/SP)',
    'perfil': {
      'nome': profile.displayName,
      'email': email,
      'tipo': profile.donorType.label,
      'telefone': profile.phone,
      'cidade': profile.city,
      'versaoDosTermos': profile.termsVersion,
      'consentimentoEm': iso(profile.consentAt),
      'doacaoAnonima': profile.prefs.anonimo,
      'receberNotificacoes': profile.prefs.notificacoes,
      'exclusaoSolicitadaEm': iso(profile.deletionRequestedAt),
    },
    'doacoes': [
      for (final d in ordered)
        {
          'protocolo': d.protocol.isEmpty ? null : d.protocol,
          'situacao': d.status.label,
          'criadaEm': iso(d.createdAt),
          'atualizadaEm': iso(d.updatedAt),
          'pontoDeEntrega': d.pointId,
          'janelaDeEntrega': d.window == null
              ? null
              : {'de': iso(d.window!.from), 'ate': iso(d.window!.to)},
          'itens': [
            for (final i in d.items)
              {
                'descricao': i.description,
                'categoria': i.category,
                'quantidade': i.quantity,
                'unidade': i.unit,
                'validade': i.hasExpiry ? iso(i.expiryDate) : null,
                'estado': i.condition.label,
              },
          ],
          'mensagemDaEquipe': d.approvalMessage,
          'motivoDaRecusa': d.refusalReason,
          'motivoDoCancelamento': d.cancelReason,
          'recebidaEm': iso(d.receivedAt),
          'itensRecebidos': [
            for (final r in d.receivedItems)
              {'item': r.index + 1, 'quantidadeRecebida': r.receivedQty, 'observacao': r.note},
          ],
          'impacto': d.impact == null
              ? null
              : {
                  'setor': d.impact!.sector,
                  'mensagem': d.impact!.message,
                  'usadaEm': iso(d.impact!.usedAt),
                },
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(data);
}
