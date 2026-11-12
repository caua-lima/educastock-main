import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/web/recomecar.dart'
    if (dart.library.html) '../../../../core/web/recomecar_web.dart';
import '../../../donations/domain/entities/donor_profile.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/app_user.dart';
import '../../../../core/firebase/firebase_providers.dart';

final authDatasourceProvider = Provider<AuthRemoteDatasource>(
  (ref) => AuthRemoteDatasource(firestore: ref.watch(firestoreProvider)),
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

/// Quem entrou de verdade (a conta do Firebase), sem a visão de outro perfil.
final usuarioRealProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Visão de outro perfil, só para o administrador (apresentações e conferência de telas):
/// o app passa a se comportar como o de outro papel, sem sair da conta. Os dados chegam com
/// a permissão do administrador; na visão de doador nada é gravado.
class VisaoPerfil {
  final UserRole papel;
  final String? doadorId;
  final String? doadorNome;

  const VisaoPerfil.equipe(this.papel)
      : doadorId = null,
        doadorNome = null;

  const VisaoPerfil.doador({required String id, required String nome})
      : papel = UserRole.doador,
        doadorId = id,
        doadorNome = nome;

  bool get ehDoador => papel == UserRole.doador;
}

final visaoPerfilProvider = StateProvider<VisaoPerfil?>((_) => null);

/// O usuário que as telas usam: o real ou, com a visão ativa, o do perfil escolhido.
final currentUserProvider = Provider<AppUser?>((ref) {
  final real = ref.watch(usuarioRealProvider);
  final visao = ref.watch(visaoPerfilProvider);
  if (real == null || visao == null || real.role != UserRole.admin) return real;
  if (visao.ehDoador) {
    return AppUser(
      id: visao.doadorId!,
      name: visao.doadorNome!,
      email: '',
      role: UserRole.doador,
      isActive: true,
      createdAt: real.createdAt,
    );
  }
  return AppUser(
    id: real.id,
    name: real.name,
    email: real.email,
    role: visao.papel,
    isActive: true,
    createdAt: real.createdAt,
    twoFactorEnabled: real.twoFactorEnabled,
  );
});

/// Administrador vendo o app como um doador: as gravações do portal ficam bloqueadas.
final emVisaoDoadorProvider = Provider<bool>((ref) {
  return ref.watch(usuarioRealProvider)?.role == UserRole.admin &&
      (ref.watch(visaoPerfilProvider)?.ehDoador ?? false);
});

/// Erro das ações bloqueadas na visão de doador.
class AcaoBloqueadaNaVisao implements Exception {
  const AcaoBloqueadaNaVisao();

  @override
  String toString() =>
      'Esta é a visão do doador: nada é gravado. Para fazer isso de verdade, '
      'entre com a conta do doador.';
}

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
    _recomecarJaLogado();
  }

  /// Depois de entrar pelo Google ou criar a conta, a web reabre o app já logado: o
  /// perfil (users/{uid}) é gravado logo depois do login, e as telas abertas antes disso
  /// ficavam vazias até sair e entrar de novo.
  void _recomecarJaLogado() {
    final user = state.valueOrNull;
    if (user == null) return;
    // Com 2FA ativo, quem segue é a tela do código (recarregar pularia essa etapa).
    if (user.twoFactorEnabled && AuthRemoteDatasource.otpDeliveryAvailable) return;
    recomecarEm(user.role == UserRole.doador ? '/doador' : '/dashboard');
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
    _recomecarJaLogado();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Na visão de outro perfil a conta é a do administrador: nunca trocar a senha dela.
    if (ref.read(visaoPerfilProvider) != null)
      throw const AcaoBloqueadaNaVisao();
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
    // Na visão de outro perfil, "Sair" volta para o administrador (não desloga).
    if (ref.read(visaoPerfilProvider) != null) {
      ref.read(visaoPerfilProvider.notifier).state = null;
      return;
    }
    final ds = ref.read(authDatasourceProvider);
    await ds.signOut();
    ref.read(pendingOtpProvider.notifier).state = false;
    state = const AsyncValue.data(null);
    // Web: recomeça o app no login. As leituras abertas na sessão que saiu falham por
    // permissão e ficariam presas em erro para a próxima pessoa; reabri-las todas de uma
    // vez provoca uma falha interna do SDK web do Firestore ("Unexpected state").
    recomecarNoLogin();
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<AppUser?>>(() => AuthNotifier());

final pendingOtpProvider = StateProvider<bool>((_) => false);
