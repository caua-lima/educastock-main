// Visão de outro perfil (administrador apresentando o app): o papel efetivo muda, a conta
// real não; na visão de doador nada é gravado e "Sair" só volta para o administrador.
import 'package:educastock/features/auth/domain/entities/app_user.dart';
import 'package:educastock/features/auth/presentation/controllers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _usuario(UserRole papel, {String id = 'u-admin'}) => AppUser(
      id: id,
      name: 'Marta',
      email: 'marta@exemplo.org',
      role: papel,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

Future<ProviderContainer> _container(AppUser real) async {
  final c = ProviderContainer(overrides: [
    authStateProvider.overrideWith((ref) => Stream.value(real)),
  ]);
  addTearDown(c.dispose);
  c.listen(currentUserProvider, (_, __) {});
  await c.read(authStateProvider.future);
  return c;
}

void main() {
  test('administrador vê como estoquista: papel muda, conta continua a dele', () async {
    final c = await _container(_usuario(UserRole.admin));
    c.read(visaoPerfilProvider.notifier).state = const VisaoPerfil.equipe(UserRole.estoquista);
    final efetivo = c.read(currentUserProvider)!;
    expect(efetivo.role, UserRole.estoquista);
    expect(efetivo.id, 'u-admin');
    expect(c.read(usuarioRealProvider)!.role, UserRole.admin);
    expect(c.read(emVisaoDoadorProvider), isFalse);
  });

  test('visão de doador usa o doador escolhido e bloqueia gravações', () async {
    final c = await _container(_usuario(UserRole.admin));
    c.read(visaoPerfilProvider.notifier).state =
        const VisaoPerfil.doador(id: 'd-1', nome: 'Supermercado Boa Compra');
    final efetivo = c.read(currentUserProvider)!;
    expect(efetivo.role, UserRole.doador);
    expect(efetivo.id, 'd-1');
    expect(efetivo.name, 'Supermercado Boa Compra');
    expect(c.read(emVisaoDoadorProvider), isTrue);
    await expectLater(
      c.read(authNotifierProvider.notifier).changePassword(currentPassword: 'a', newPassword: 'b'),
      throwsA(isA<AcaoBloqueadaNaVisao>()),
    );
  });

  test('"Sair" durante a visão só volta para o administrador', () async {
    final c = await _container(_usuario(UserRole.admin));
    c.read(visaoPerfilProvider.notifier).state = const VisaoPerfil.equipe(UserRole.consulta);
    await c.read(authNotifierProvider.notifier).signOut();
    expect(c.read(visaoPerfilProvider), isNull);
    expect(c.read(currentUserProvider)!.role, UserRole.admin);
  });

  test('quem não é administrador não consegue usar a visão', () async {
    final c = await _container(_usuario(UserRole.estoquista, id: 'u-est'));
    c.read(visaoPerfilProvider.notifier).state = const VisaoPerfil.doador(id: 'd-1', nome: 'X');
    expect(c.read(currentUserProvider)!.role, UserRole.estoquista);
    expect(c.read(emVisaoDoadorProvider), isFalse);
  });
}
