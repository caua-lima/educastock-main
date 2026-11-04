import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../donations/domain/entities/donation.dart';
import '../../../donations/domain/entities/donation_status.dart';
import '../../data/donation_ops_repository.dart';
import '../../../../core/firebase/firebase_providers.dart';

final donationOpsRepositoryProvider = Provider<DonationOpsRepository>(
  (ref) => DonationOpsRepository(db: ref.watch(firestoreProvider)),
);

/// Administrador e estoquista operam as doações (mesma regra do Firestore: `isOps`).
bool canOperateDonations(AppUser? user) =>
    user != null &&
    user.isActive &&
    (user.role == UserRole.admin || user.role == UserRole.estoquista);

/// Fila da equipe (S01). Vazia para quem não opera doações.
final donationQueueProvider = StreamProvider<List<Donation>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (!canOperateDonations(user)) return const Stream<List<Donation>>.empty();
  return ref.watch(donationOpsRepositoryProvider).watchQueue();
});

/// Aba "Triagem": intenções pendentes, da mais antiga para a mais nova (quem espera há
/// mais tempo aparece primeiro).
final triageDonationsProvider = Provider<AsyncValue<List<Donation>>>((ref) {
  return ref.watch(donationQueueProvider).whenData((list) {
    final pending = list.where((d) => d.status == DonationStatus.pendente).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(2100)).compareTo(b.createdAt ?? DateTime(2100)));
    return pending;
  });
});

/// Aba "Para destinar": aprovadas aguardando a entrega física e recebidas sem destino.
final toAllocateDonationsProvider = Provider<AsyncValue<List<Donation>>>((ref) {
  return ref.watch(donationQueueProvider).whenData(
        (list) => list
            .where((d) => d.status == DonationStatus.aprovada || d.needsDestination)
            .toList(),
      );
});

/// Quantidade de intenções pendentes (selo da aba de doações).
final pendingDonationsCountProvider = Provider<int>((ref) {
  return ref.watch(triageDonationsProvider).valueOrNull?.length ?? 0;
});

/// Ações da equipe sobre uma doação. Os erros de regra de negócio chegam como
/// [DonationOpsException] com texto pronto para mostrar ao usuário.
class DonationOpsActions extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AppUser _actor() {
    final user = ref.read(currentUserProvider);
    if (!canOperateDonations(user)) {
      throw const DonationOpsException('Seu perfil não pode operar doações.');
    }
    return user!;
  }

  Future<void> decide({
    required String donationId,
    required bool approve,
    String? message,
    String? refusalReason,
  }) =>
      _run(() => ref.read(donationOpsRepositoryProvider).decide(
            donationId: donationId,
            approve: approve,
            actor: _actor(),
            message: message,
            refusalReason: refusalReason,
          ));

  Future<void> receive({
    required Donation donation,
    required List<ReceivedItemInput> received,
    String? sector,
    String? impactMessage,
    DateTime? usedAt,
  }) =>
      _run(() => ref.read(donationOpsRepositoryProvider).receive(
            donation: donation,
            actor: _actor(),
            received: received,
            sector: sector,
            impactMessage: impactMessage,
            usedAt: usedAt,
          ));

  Future<void> saveImpact({
    required Donation donation,
    required String sector,
    required String message,
    DateTime? usedAt,
  }) =>
      _run(() => ref.read(donationOpsRepositoryProvider).saveImpact(
            donation: donation,
            actor: _actor(),
            sector: sector,
            message: message,
            usedAt: usedAt,
          ));

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    if (state.hasError) {
      final error = state.error!;
      state = const AsyncData(null);
      throw error;
    }
  }
}

final donationOpsActionsProvider =
    AsyncNotifierProvider<DonationOpsActions, void>(DonationOpsActions.new);
