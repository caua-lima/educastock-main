import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../donations/domain/entities/donor_profile.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/app_user.dart';

final authDatasourceProvider = Provider<AuthRemoteDatasource>(
  (_) => AuthRemoteDatasource(),
);

final authStateProvider = StreamProvider<AppUser?>((ref) async* {
  final ds = ref.watch(authDatasourceProvider);

  await for (final firebaseUser in ds.authStateChanges) {
    if (firebaseUser == null) {
      yield null;
    } else {
      yield await ds.getCurrentUser();
    }
  }
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value;
});

// Auth notifier para login/logout
class AuthNotifier extends Notifier<AsyncValue<AppUser?>> {
  @override
  AsyncValue<AppUser?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> signIn(
    String email,
    String password, {
    bool rememberLogin = true,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(authDatasourceProvider);
      return ds.signIn(
        email: email,
        password: password,
        rememberLogin: rememberLogin,
      );
    });
  }

  Future<void> signInWithGoogle({bool rememberLogin = true}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(authDatasourceProvider);
      return ds.signInWithGoogle(rememberLogin: rememberLogin);
    });
  }

  /// Cadastro autônomo do doador (RF16 / tela D02).
  Future<void> registerDonor({
    required String name,
    required String email,
    required String password,
    required DonorType donorType,
    required String phone,
    required String city,
    bool rememberLogin = true,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(authDatasourceProvider);
      return ds.createDonor(
        email: email,
        password: password,
        name: name,
        donorType: donorType,
        phone: phone,
        city: city,
        rememberLogin: rememberLogin,
      );
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final ds = ref.read(authDatasourceProvider);
    await ds.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    final ds = ref.read(authDatasourceProvider);
    await ds.sendPasswordReset(email);
  }

  Future<void> signOut() async {
    final ds = ref.read(authDatasourceProvider);
    await ds.signOut();
    ref.read(pendingOtpProvider.notifier).state = false;
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<AppUser?>>(() => AuthNotifier());

final pendingOtpProvider = StateProvider<bool>((_) => false);
