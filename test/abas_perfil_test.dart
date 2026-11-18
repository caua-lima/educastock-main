// Navegação principal: cada perfil vê só as abas que pode usar, e a aba destacada é a da
// tela atual (nenhuma em Configurações, Alertas, Auditoria…).
import 'package:educastock/core/router/app_navigation_shell.dart';
import 'package:educastock/core/router/app_router.dart';
import 'package:educastock/features/auth/domain/entities/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _u(UserRole papel) => AppUser(
      id: 'u1',
      name: 'Teste',
      email: 't@exemplo.org',
      role: papel,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

List<String> _rotas(UserRole papel) =>
    [for (final a in abasDoPerfil(_u(papel))) a.rota];

void main() {
  test('administrador e estoquista: todas as abas', () {
    for (final p in [UserRole.admin, UserRole.estoquista]) {
      expect(_rotas(p), [
        AppRoutes.dashboard,
        AppRoutes.productList,
        AppRoutes.movement,
        AppRoutes.history,
        AppRoutes.reports,
        AppRoutes.opsDonations,
      ]);
    }
  });

  test('voluntário e consulta: sem Saída e sem Doações', () {
    for (final p in [UserRole.voluntario, UserRole.consulta]) {
      expect(_rotas(p), [
        AppRoutes.dashboard,
        AppRoutes.productList,
        AppRoutes.history,
        AppRoutes.reports
      ]);
    }
  });

  test('aba destacada: a da tela atual, ou nenhuma', () {
    final abas = abasDoPerfil(_u(UserRole.admin));
    expect(indiceDaAba('/products/abc', abas), 1);
    expect(indiceDaAba(AppRoutes.movement, abas), 2);
    expect(indiceDaAba('/doacoes/nova-necessidade', abas), 5);
    expect(indiceDaAba(AppRoutes.settings, abas), -1);
    expect(indiceDaAba(AppRoutes.alerts, abas), -1);
    expect(indiceDaAba(AppRoutes.adjustmentApprovals, abas), -1);
    // Sem a aba Saída, Histórico passa a ser a terceira.
    expect(
        indiceDaAba(AppRoutes.history, abasDoPerfil(_u(UserRole.consulta))), 2);
  });
}
