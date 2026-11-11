import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_user.dart';
import '../controllers/auth_provider.dart';

/// Nome do papel para a interface.
String rotuloDoPapel(UserRole papel) => switch (papel) {
      UserRole.admin => 'Administrador',
      UserRole.estoquista => 'Estoquista',
      UserRole.voluntario => 'Voluntário',
      UserRole.consulta => 'Consulta',
      UserRole.doador => 'Doador',
    };

/// Faixa no topo de todas as telas enquanto o administrador vê o app como outro perfil,
/// com o botão para voltar. Some fora da visão.
class FaixaVisaoPerfil extends ConsumerWidget {
  const FaixaVisaoPerfil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visao = ref.watch(visaoPerfilProvider);
    final adminDeVerdade = ref.watch(usuarioRealProvider)?.role == UserRole.admin;
    if (visao == null || !adminDeVerdade) return const SizedBox.shrink();

    final quem = visao.ehDoador
        ? 'doador ${visao.doadorNome}'
        : rotuloDoPapel(visao.papel).toLowerCase();
    final texto = visao.ehDoador
        ? 'Você está vendo o app como o $quem. Nada é gravado.'
        : 'Você está vendo o app como $quem.';

    return Semantics(
      liveRegion: true,
      child: Material(
        color: const Color(0xFF6D28D9),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: LayoutBuilder(
              builder: (context, c) => Row(
                children: [
                  const Icon(Icons.visibility_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      texto,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => ref.read(visaoPerfilProvider.notifier).state = null,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(c.maxWidth < 560 ? 'Voltar' : 'Voltar ao administrador'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
