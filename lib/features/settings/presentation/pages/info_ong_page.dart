import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../chatbot/domain/info_ong.dart';
import '../../../chatbot/presentation/controllers/info_ong_provider.dart';

/// O administrador informa o que o assistente do doador responde: horário, contatos,
/// PIX… Campo vazio = o assistente diz que não tem a informação e indica o telefone.
class InfoOngPage extends ConsumerStatefulWidget {
  const InfoOngPage({super.key});

  @override
  ConsumerState<InfoOngPage> createState() => _InfoOngPageState();
}

class _InfoOngPageState extends ConsumerState<InfoOngPage> {
  static const _campos = <(String, String, String, int)>[
    (
      'horarioFuncionamento',
      'Horário de funcionamento',
      'Ex.: de segunda a sexta, das 7h às 17h',
      2
    ),
    (
      'horarioEntregas',
      'Horário para receber doações',
      'Ex.: de segunda a sexta, das 8h às 16h',
      2
    ),
    ('telefone', 'Telefone', '(19) 3863-0229', 1),
    ('whatsapp', 'WhatsApp', 'Ex.: (19) 9 9999-9999', 1),
    ('email', 'E-mail', 'Ex.: contato@casadacrianca.org', 1),
    ('redeSocial', 'Rede social', '@celencinacaldassarkis', 1),
    ('endereco', 'Endereço', 'Rua, número, bairro, cidade e CEP', 2),
    ('chavePix', 'Chave PIX', 'Deixe vazio se não houver', 1),
    (
      'contaBancaria',
      'Conta bancária para doações',
      'Banco, agência, conta e favorecido',
      2
    ),
    (
      'publicoAtendido',
      'Quem a ONG atende',
      'Ex.: 147 crianças de 4 a 15 anos, no contraturno escolar',
      2
    ),
  ];

  final Map<String, TextEditingController> _c = {};
  bool _carregado = false;
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _preencher(InfoOng info) {
    if (_carregado) return;
    final m = info.toMap();
    for (final (chave, _, _, _) in _campos) {
      _c[chave] = TextEditingController(text: m[chave] as String? ?? '');
    }
    _carregado = true;
  }

  Future<void> _salvar(InfoOng atual) async {
    setState(() => _salvando = true);
    final m = atual.toMap();
    for (final (chave, _, _, _) in _campos) {
      m[chave] = _c[chave]!.text.trim();
    }
    try {
      await ref
          .read(firestoreProvider)
          .collection('settings')
          .doc('ong_info')
          .set(m);
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Informações salvas: o assistente já usa os dados novos.',
          isSuccess: true);
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Não foi possível salvar agora. Tente de novo.',
          isError: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    if (user?.role != UserRole.admin) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.settings)),
          title: const Text('Informações da ONG'),
        ),
        body: const Center(
          child: CasaEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Só o administrador edita',
            description:
                'Peça ao administrador para atualizar estas informações.',
          ),
        ),
      );
    }
    final info = ref.watch(infoOngProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.settings)),
        title: const Text('Informações da ONG'),
      ),
      body: info.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _formulario(cs, InfoOng.padrao),
        data: (i) => _formulario(cs, i),
      ),
    );
  }

  Widget _formulario(ColorScheme cs, InfoOng info) {
    _preencher(info);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'É o que o assistente do Portal do Doador responde quando perguntam sobre horário, '
          'contato, endereço ou doação em dinheiro. Campo vazio: o assistente diz que não tem a '
          'informação e indica o telefone.',
          style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final (chave, rotulo, dica, linhas) in _campos) ...[
          TextField(
            controller: _c[chave],
            maxLines: linhas,
            decoration: InputDecoration(labelText: rotulo, hintText: dica),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.sm),
        CasaButton(
          label: 'Salvar informações',
          icon: Icons.save_rounded,
          isLoading: _salvando,
          onPressed: _salvando ? null : () => _salvar(info),
        ),
      ],
    );
  }
}
