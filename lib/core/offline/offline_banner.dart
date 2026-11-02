import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'offline_sync_controller.dart';

/// Faixa fixa no topo do app com o estado da conexão e da fila de envio.
/// Some sozinha quando está online, sem pendências e sem avisos.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(offlineSyncProvider);

    final String? text;
    final Color color;
    final IconData icon;
    VoidCallback? onTap;

    if (s.conflicts.isNotEmpty) {
      text = s.conflicts.length == 1
          ? 'Um registro feito offline não pôde ser aplicado: ${s.conflicts.first} (toque para dispensar)'
          : '${s.conflicts.length} registros feitos offline não puderam ser aplicados (toque para dispensar)';
      color = const Color(0xFFB45309);
      icon = Icons.warning_amber_rounded;
      onTap = () => ref.read(offlineSyncProvider.notifier).dismissConflicts();
    } else if (!s.online) {
      text = s.pending > 0
          ? 'Sem conexão — ${s.pending} ${s.pending == 1 ? 'registro será enviado' : 'registros serão enviados'} quando a internet voltar'
          : 'Sem conexão — o que você registrar será enviado quando a internet voltar';
      color = const Color(0xFF475569);
      icon = Icons.cloud_off_rounded;
    } else if (s.syncing || s.pending > 0) {
      text = 'Enviando ${s.pending} ${s.pending == 1 ? 'registro' : 'registros'} feitos offline…';
      color = const Color(0xFF0E7490);
      icon = Icons.cloud_sync_rounded;
    } else {
      return const SizedBox.shrink();
    }

    return Semantics(
      liveRegion: true,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
