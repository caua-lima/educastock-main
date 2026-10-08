import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../data/datasources/donations_remote_datasource.dart';
import '../../domain/entities/donation.dart';
import '../../domain/entities/donation_point.dart';
import '../../domain/entities/donation_rules.dart';
import '../../domain/entities/donation_status.dart';

final donationsDatasourceProvider = Provider<DonationsRemoteDatasource>(
  (_) => DonationsRemoteDatasource(),
);

/// Doações do doador logado (`donorId == auth.uid`), mais recentes primeiro.
final myDonationsProvider = StreamProvider<List<Donation>>((ref) {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) return const Stream<List<Donation>>.empty();
  return ref.watch(donationsDatasourceProvider).watchByDonor(uid);
});

final donationByIdProvider =
    StreamProvider.family<Donation?, String>((ref, id) {
  return ref.watch(donationsDatasourceProvider).watchById(id);
});

/// Quantas doações do doador ainda estão em andamento (pendente ou aprovada).
final openDonationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(myDonationsProvider).valueOrNull ?? const <Donation>[];
  return list.where((d) => d.status.isOpen).length;
});

final donationPointsProvider = StreamProvider<List<DonationPoint>>((ref) {
  return ref.watch(donationsDatasourceProvider).watchActivePoints();
});

final donationPointByIdProvider =
    Provider.family<DonationPoint?, String>((ref, id) {
  final points = ref.watch(donationPointsProvider).valueOrNull ?? const <DonationPoint>[];
  for (final p in points) {
    if (p.id == id) return p;
  }
  return null;
});

/// Regras de doação com padrões seguros enquanto o documento não existir.
final donationRulesProvider = StreamProvider<DonationRules>((ref) {
  return ref.watch(donationsDatasourceProvider).watchRules();
});

// ─── Filtro por status (D08) ─────────────────────────────────────────────────

enum DonationStatusFilter {
  todas('Todas'),
  emAndamento('Em andamento'),
  concluidas('Concluídas'),
  encerradas('Encerradas');

  const DonationStatusFilter(this.label);
  final String label;

  bool matches(DonationStatus status) => switch (this) {
        DonationStatusFilter.todas => true,
        DonationStatusFilter.emAndamento => status.isOpen,
        DonationStatusFilter.concluidas => status.isConcluded,
        DonationStatusFilter.encerradas => status.isClosedWithoutDelivery,
      };
}

final donationStatusFilterProvider =
    StateProvider<DonationStatusFilter>((_) => DonationStatusFilter.todas);

final filteredDonationsProvider = Provider<AsyncValue<List<Donation>>>((ref) {
  final filter = ref.watch(donationStatusFilterProvider);
  return ref.watch(myDonationsProvider).whenData(
        (list) => list.where((d) => filter.matches(d.status)).toList(),
      );
});

// ─── Cancelamento (D09) ──────────────────────────────────────────────────────

class CancelDonationNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> cancel(String donationId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(donationsDatasourceProvider).cancel(donationId);
    });
  }
}

final cancelDonationProvider =
    AsyncNotifierProvider<CancelDonationNotifier, void>(CancelDonationNotifier.new);
