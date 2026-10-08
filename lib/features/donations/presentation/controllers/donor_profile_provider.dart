import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../data/datasources/donor_profile_datasource.dart';
import '../../domain/entities/donor_profile.dart';

final donorProfileDatasourceProvider = Provider<DonorProfileDatasource>(
  (_) => DonorProfileDatasource(),
);

/// Perfil do doador logado (null enquanto não existe `donors/{uid}`).
final donorProfileProvider = StreamProvider<DonorProfile?>((ref) {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null) return const Stream<DonorProfile?>.empty();
  return ref.watch(donorProfileDatasourceProvider).watchProfile(uid);
});

/// Ações sobre o perfil do doador (D02 e D11).
class DonorProfileNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save(DonorProfile profile) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(donorProfileDatasourceProvider).updateProfile(profile);
    });
  }

  /// Cria o perfil após login com Google, já com o aceite dos termos.
  Future<void> ensureProfile({
    required String uid,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(donorProfileDatasourceProvider)
          .ensureProfile(uid: uid, displayName: displayName);
    });
  }

  Future<void> requestDeletion() async {
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(donorProfileDatasourceProvider).requestDeletion(uid);
    });
  }
}

final donorProfileNotifierProvider =
    AsyncNotifierProvider<DonorProfileNotifier, void>(DonorProfileNotifier.new);
