import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../auth/presentation/widgets/faixa_visao_perfil.dart';

/// Doador que dá para escolher na visão de doador (os que mais doaram, para a tela ter
/// conteúdo na demonstração).
typedef DoadorParaVisao = ({String id, String nome, int doacoes});

final doadoresParaVisaoProvider =
    FutureProvider.autoDispose<List<DoadorParaVisao>>((ref) async {
  final snap = await bancoDaSessao(ref)
      .collection('donations')
      .orderBy('createdAt', descending: true)
      .limit(300)
      .get();
  final porDoador = <String, ({String nome, int doacoes})>{};
  for (final d in snap.docs) {
    final data = d.data();
    final id = data['donorId'] as String?;
    if (id == null || id.isEmpty) continue;
    final nome = ((data['donorSnapshot'] as Map?)?['displayName'] as String?)?.trim();
    final atual = porDoador[id];
    porDoador[id] = (
      nome: atual?.nome ?? ((nome == null || nome.isEmpty) ? 'Doador' : nome),
      doacoes: (atual?.doacoes ?? 0) + 1,
    );
  }
  final lista = [
    for (final e in porDoador.entries) (id: e.key, nome: e.value.nome, doacoes: e.value.doacoes),
  ]..sort((a, b) => b.doacoes.compareTo(a.doacoes));
  return lista.take(12).toList();
});

const _papeisDaEquipe = [
  (UserRole.estoquista, Icons.inventory_2_rounded, 'Entradas, saídas, doações e alertas'),
  (UserRole.voluntario, Icons.volunteer_activism_rounded, 'Consulta estoque, histórico e alertas'),
  (UserRole.consulta, Icons.visibility_rounded, 'Só leitura: estoque, histórico e relatórios'),
];

/// Abre a escolha do perfil para ver o app (só administrador).
Future<void> abrirEscolhaDeVisao(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _EscolhaVisao(),
  );
}

class _EscolhaVisao extends ConsumerWidget {
  const _EscolhaVisao();

  void _escolher(BuildContext context, WidgetRef ref, VisaoPerfil visao) {
    ref.read(visaoPerfilProvider.notifier).state = visao;
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(visao.ehDoador ? AppRoutes.donorHome : AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final doadores = ref.watch(doadoresParaVisaoProvider);
    final atual = ref.watch(visaoPerfilProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        children: [
          Text('Ver o app como…',
              style: AppTypography.headingSmall.copyWith(color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(
            'Mostra as telas, os menus e as permissões de cada perfil, sem sair da sua conta. '
            'Uma faixa roxa no topo indica a visão e tem o botão para voltar.',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Equipe', style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
          for (final (papel, icone, descricao) in _papeisDaEquipe)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(icone, color: cs.primary),
              title: Text(rotuloDoPapel(papel)),
              subtitle: Text(descricao),
              trailing: atual?.papel == papel ? const Icon(Icons.check_rounded) : null,
              onTap: () => _escolher(context, ref, VisaoPerfil.equipe(papel)),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text('Doador', style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
          Text(
            'Escolha de quem é o portal. Na visão de doador nada é gravado.',
            style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          ...doadores.when(
            loading: () => const [
              Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (_, __) => [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text('Não foi possível carregar os doadores agora.',
                    style: AppTypography.bodySmall.copyWith(color: cs.error)),
              ),
            ],
            data: (lista) => lista.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text('Ainda não há doações de nenhum doador.',
                          style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  ]
                : [
                    for (final d in lista)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.favorite_rounded, color: cs.primary),
                        title: Text(d.nome),
                        subtitle: Text('${d.doacoes} ${d.doacoes == 1 ? 'doação' : 'doações'}'),
                        trailing: atual?.doadorId == d.id ? const Icon(Icons.check_rounded) : null,
                        onTap: () => _escolher(context, ref, VisaoPerfil.doador(id: d.id, nome: d.nome)),
                      ),
                  ],
          ),
        ],
      ),
    );
  }
}
