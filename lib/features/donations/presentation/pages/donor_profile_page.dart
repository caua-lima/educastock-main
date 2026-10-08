import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../auth/presentation/utils/auth_error_mapper.dart';
import '../../domain/entities/donor_profile.dart';
import '../controllers/donor_profile_provider.dart';
import '../widgets/donor_header.dart';

/// D11 — Perfil e privacidade do doador (RF17): edita dados de contato e
/// preferências, troca a senha, pede exclusão dos dados e sai da conta.
class DonorProfilePage extends ConsumerWidget {
  const DonorProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(donorProfileProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          const DonorHeader(
            title: 'Meu perfil',
            subtitle: 'Seus dados e preferências de privacidade',
          ),
          Expanded(
            child: profile.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  CasaLoadingSkeleton(height: 52),
                  SizedBox(height: AppSpacing.md),
                  CasaLoadingSkeleton(height: 52),
                  SizedBox(height: AppSpacing.md),
                  CasaLoadingSkeleton(height: 52),
                ],
              ),
              error: (_, __) => CasaEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Não foi possível carregar seu perfil',
                ctaLabel: 'Tentar de novo',
                onCta: () => ref.invalidate(donorProfileProvider),
              ),
              data: (value) {
                if (value == null) {
                  return CasaEmptyState(
                    icon: Icons.person_off_rounded,
                    title: 'Perfil de doador não encontrado',
                    description: 'Saia e entre novamente para criar o seu perfil.',
                    ctaLabel: 'Sair',
                    onCta: () =>
                        ref.read(authNotifierProvider.notifier).signOut(),
                  );
                }
                return _ProfileForm(key: ValueKey(value.uid), profile: value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  final DonorProfile profile;

  const _ProfileForm({super.key, required this.profile});

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _city;
  late final TextEditingController _email;
  late DonorType _type;
  late bool _anonimo;
  late bool _notificacoes;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.displayName);
    _phone = TextEditingController(text: p.phone ?? '');
    _city = TextEditingController(text: p.city ?? '');
    _email = TextEditingController(text: ref.read(currentUserProvider)?.email ?? '');
    _type = p.donorType;
    _anonimo = p.prefs.anonimo;
    _notificacoes = p.prefs.notificacoes;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    _email.dispose();
    super.dispose();
  }

  bool get _dirty {
    final p = widget.profile;
    return _name.text.trim() != p.displayName ||
        _phone.text.trim() != (p.phone ?? '') ||
        _city.text.trim() != (p.city ?? '') ||
        _type != p.donorType ||
        _anonimo != p.prefs.anonimo ||
        _notificacoes != p.prefs.notificacoes;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final updated = widget.profile.copyWith(
      displayName: _name.text.trim(),
      donorType: _type,
      phone: _phone.text.trim(),
      city: _city.text.trim(),
      prefs: DonorPrefs(anonimo: _anonimo, notificacoes: _notificacoes),
    );
    await ref.read(donorProfileNotifierProvider.notifier).save(updated);
    if (!mounted) return;
    ref.read(donorProfileNotifierProvider).whenOrNull(
          data: (_) => showCasaSnackbar(context,
              message: 'Perfil atualizado.', isSuccess: true),
          error: (error, _) => showCasaSnackbar(
            context,
            message: mapAuthError(error,
                fallback: 'Não foi possível salvar. Tente novamente.'),
            isError: true,
          ),
        );
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Trocar senha'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CasaTextField(
                label: 'Senha atual',
                controller: current,
                obscureText: true,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Informe a senha atual' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CasaTextField(
                label: 'Nova senha',
                controller: next,
                obscureText: true,
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Use pelo menos 8 caracteres' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CasaTextField(
                label: 'Confirmar nova senha',
                controller: confirm,
                obscureText: true,
                validator: (v) => v != next.text ? 'As senhas não conferem' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    final currentPassword = current.text;
    final newPassword = next.text;
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (submitted != true || !mounted) return;

    try {
      await ref.read(authNotifierProvider.notifier).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (!mounted) return;
      showCasaSnackbar(context, message: 'Senha alterada.', isSuccess: true);
    } catch (error) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: mapAuthError(error, fallback: 'Não foi possível trocar a senha.'),
        isError: true,
      );
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Solicitar exclusão dos meus dados?'),
        content: const Text(
          'Seus dados pessoais serão anonimizados. O histórico das doações já '
          'recebidas é mantido sem identificação, para fins de estoque e auditoria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger600),
            child: const Text('Solicitar exclusão'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(donorProfileNotifierProvider.notifier).requestDeletion();
    if (!mounted) return;
    ref.read(donorProfileNotifierProvider).whenOrNull(
          data: (_) => showCasaSnackbar(
            context,
            message: 'Pedido registrado. A ONG vai concluir a exclusão em breve.',
            isSuccess: true,
          ),
          error: (error, _) => showCasaSnackbar(
            context,
            message: mapAuthError(error,
                fallback: 'Não foi possível registrar o pedido agora.'),
            isError: true,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saving = ref.watch(donorProfileNotifierProvider).isLoading;
    final isCompany = _type == DonorType.pj;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SegmentedButton<DonorType>(
            segments: [
              for (final t in DonorType.values)
                ButtonSegment(value: t, label: Text(t.label)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          CasaTextField(
            label: isCompany ? 'Razão social ou responsável' : 'Nome completo',
            controller: _name,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v == null || v.trim().length < 3) ? 'Informe o nome' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          CasaTextField(
            label: 'E-mail',
            controller: _email,
            readOnly: true,
            helperText: 'O e-mail de acesso não pode ser alterado aqui.',
          ),
          const SizedBox(height: AppSpacing.md),
          CasaTextField(
            label: 'Telefone / WhatsApp',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length < 10 ? 'Informe o telefone com DDD' : null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          CasaTextField(
            label: 'Cidade',
            controller: _city,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Informe a cidade' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Doar de forma anônima'),
            subtitle: const Text('A equipe e os agradecimentos verão “Doador anônimo”.'),
            value: _anonimo,
            onChanged: (v) => setState(() => _anonimo = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Receber notificações'),
            subtitle: const Text('Avisos quando a doação for aprovada ou recebida.'),
            value: _notificacoes,
            onChanged: (v) => setState(() => _notificacoes = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          CasaButton(
            label: 'Salvar alterações',
            icon: Icons.save_rounded,
            isLoading: saving,
            onPressed: _dirty ? _save : null,
          ),
          const SizedBox(height: AppSpacing.md),
          CasaButton(
            label: 'Trocar senha',
            variant: CasaButtonVariant.secondary,
            icon: Icons.lock_reset_rounded,
            onPressed: _changePassword,
          ),
          const SizedBox(height: AppSpacing.md),
          CasaButton(
            label: 'Sair da conta',
            variant: CasaButtonVariant.ghost,
            icon: Icons.logout_rounded,
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Zona de privacidade ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.danger600.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacidade e exclusão',
                    style: AppTypography.labelLarge.copyWith(color: cs.onSurface)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.profile.deletionRequested
                      ? 'Você já pediu a exclusão dos seus dados. A ONG está processando.'
                      : 'Você pode pedir a anonimização dos seus dados pessoais a qualquer momento (LGPD).',
                  style: AppTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!widget.profile.deletionRequested)
                  CasaButton(
                    label: 'Solicitar exclusão dos meus dados',
                    variant: CasaButtonVariant.danger,
                    onPressed: _requestDeletion,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
