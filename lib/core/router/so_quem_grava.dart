import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_provider.dart';
import '../design_system/design_system.dart';
import 'app_router.dart';

/// Telas que gravam no estoque (saída, lote, produto, receita, localização): só
/// administrador e estoquista gravam (a mesma regra do banco). Voluntário e consulta veem
/// o motivo, em vez de um formulário que terminaria em "sem permissão".
class SoQuemGrava extends ConsumerWidget {
  final String titulo;
  final Widget child;

  const SoQuemGrava({super.key, required this.titulo, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || user.canEdit) return child;
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: CasaEmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Seu perfil só consulta',
          description: 'Registrar entradas, saídas e cadastros é com o administrador ou o '
              'estoquista. Você pode ver o estoque, o histórico, os alertas e os relatórios.',
          ctaLabel: 'Voltar ao início',
          onCta: () => context.go(AppRoutes.dashboard),
        ),
      ),
    );
  }
}
