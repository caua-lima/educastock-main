import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../domain/donation_validators.dart';
import '../../domain/entities/donation.dart';
import '../../domain/entities/donation_item.dart';
import '../../domain/entities/donation_rules.dart';
import '../../domain/entities/donation_status.dart';
import 'donation_draft_notifier.dart';
import 'donation_needs_provider.dart';
import 'donations_provider.dart';
import 'donor_profile_provider.dart';

/// Erro de negócio com mensagem pronta para o doador.
class DonationSubmitException implements Exception {
  final String message;
  const DonationSubmitException(this.message);

  @override
  String toString() => message;
}

/// Confirma a doação (passo 4): valida tudo, garante e-mail verificado (RN-D02),
/// grava em `donations` com status `pendente` e limpa o rascunho. O estado é o
/// ID da doação criada (null antes do envio).
class DonationSubmitNotifier extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  Future<void> submit() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_submit);
  }

  Future<String?> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw const DonationSubmitException('Sessão expirada. Entre novamente.');
    }

    final draft = ref.read(donationDraftProvider);
    final rules =
        ref.read(donationRulesProvider).valueOrNull ?? const DonationRules();
    final point = draft.pointId == null
        ? null
        : ref.read(donationPointByIdProvider(draft.pointId!));

    // RN-D03 / RN-D05 / RN-D06: nenhuma submissão inválida chega ao servidor.
    final errors = validateDonationDraft(
      items: draft.items,
      rules: rules,
      needsById: ref.read(needsByIdProvider),
      point: point,
      windowFrom: draft.window?.from,
      windowTo: draft.window?.to,
      termsAccepted: draft.termsAccepted,
      openDonationsCount: ref.read(openDonationsCountProvider),
    );
    if (errors.isNotEmpty) throw DonationSubmitException(errors.first);

    // RN-D02: e-mail verificado (também renova o token para as regras).
    final verified =
        await ref.read(authDatasourceProvider).refreshEmailVerified();
    if (!verified) {
      throw const DonationSubmitException(
        'Verifique seu e-mail para confirmar a doação. '
        'Enviamos um link quando você criou a conta.',
      );
    }

    final profile = ref.read(donorProfileProvider).valueOrNull ??
        await ref.read(donorProfileDatasourceProvider).getProfile(user.id);
    final snapshot = DonorSnapshot(
      displayName: profile?.publicName ?? user.name,
      phone: profile?.phone,
    );

    // Reavalia `subjectToReview` contra a data de entrega escolhida.
    final needsById = ref.read(needsByIdProvider);
    final items = draft.items.map((item) {
      final result = validateDonationItem(
        item,
        rules: rules,
        need: item.needId == null ? null : needsById[item.needId],
        referenceDate: draft.window?.from,
      );
      return item.copyWith(subjectToReview: result.subjectToReview);
    }).toList(growable: false);

    final donation = Donation(
      id: draft.clientId,
      donorId: user.id,
      donorSnapshot: snapshot,
      status: DonationStatus.pendente, // RF20: status inicial
      items: List<DonationItem>.unmodifiable(items),
      pointId: draft.pointId!,
      window: draft.window,
    );

    final id = await ref
        .read(donationsDatasourceProvider)
        .create(donation, draft.clientId);

    await ref.read(donationDraftProvider.notifier).clear();
    return id;
  }

  void reset() => state = const AsyncValue.data(null);
}

final donationSubmitProvider =
    NotifierProvider<DonationSubmitNotifier, AsyncValue<String?>>(
        DonationSubmitNotifier.new);
