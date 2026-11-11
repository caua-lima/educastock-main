import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../widgets/escolha_visao_perfil.dart';
import '../../../auth/presentation/utils/auth_error_mapper.dart';
import '../../../auth/data/datasources/auth_remote_datasource.dart';

final _keySettingsTheme = GlobalKey();
final _keySettingsPassword = GlobalKey();
final _keySettingsUsers = GlobalKey();

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Trocar senha'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CasaTextField(
                      label: 'Senha atual',
                      controller: currentController,
                      obscureText: obscureCurrent,
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: 'Nova senha',
                      controller: newController,
                      obscureText: obscureNew,
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(
                          () => obscureNew = !obscureNew,
                        ),
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: 'Confirmar nova senha',
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final current = currentController.text;
                          final next = newController.text;
                          final confirm = confirmController.text;

                          if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                            showCasaSnackbar(
                              context,
                              message: 'Preencha todos os campos.',
                              isError: true,
                            );
                            return;
                          }
                          if (next.length < 6) {
                            showCasaSnackbar(
                              context,
                              message: 'Nova senha deve ter pelo menos 6 caracteres.',
                              isError: true,
                            );
                            return;
                          }
                          if (next != confirm) {
                            showCasaSnackbar(
                              context,
                              message: 'As senhas não conferem.',
                              isError: true,
                            );
                            return;
                          }

                          setStateDialog(() => loading = true);
                          try {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .changePassword(
                                  currentPassword: current,
                                  newPassword: next,
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              showCasaSnackbar(
                                context,
                                message: 'Senha alterada com sucesso.',
                                isSuccess: true,
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              showCasaSnackbar(
                                context,
                                message: mapAuthError(
                                  error,
                                  fallback: 'Não foi possível trocar a senha.',
                                ),
                                isError: true,
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setStateDialog(() => loading = false);
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Itens conforme o papel (o mesmo que as regras do banco permitem). Com a visão de
    // outro perfil ativa, vale o papel da visão.
    final papel = user?.role;
    final ehAdmin = papel == UserRole.admin;
    final ehOps = ehAdmin || papel == UserRole.estoquista;
    final adminDeVerdade = ref.watch(usuarioRealProvider)?.role == UserRole.admin;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Configurações',
        subtitle: 'Preferências e conta',
        pageIcon: Icons.settings_rounded,
        iconColor: const Color(0xFF94A3B8),
        profileName: user?.name,
        onProfileTap: () {},
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keySettingsUsers,
                  title: 'Gerenciar Usuários',
                  description: 'Toque para gerenciar a equipe: cadastrar pessoas, definir o perfil (Administrador/Estoquista/Voluntário/Consulta), ativar ou desativar acessos. Só administradores veem esta opção.',
                  icon: Icons.manage_accounts_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Admin: acesso total — cria, edita, exclui',
                    'Estoquista: opera o dia-a-dia (cadastro + saída)',
                    'Voluntário: ações básicas (entrada + consulta)',
                    'Consulta: apenas leitura (relatórios)',
                  ],
                ),
                TutorialStep(
                  key: _keySettingsTheme,
                  title: 'Tema Claro / Escuro',
                  description: 'Alterne entre os dois modos visuais do app. O tema escuro reduz o cansaço visual em ambientes com pouca luz e economiza bateria em celulares com tela OLED/AMOLED. A preferência é salva por dispositivo.',
                  icon: Icons.dark_mode_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Claro: ideal para ambientes bem iluminados',
                    'Escuro: confortável à noite, economiza bateria OLED',
                    'Cores e contrastes ajustam automaticamente',
                    'Também acessível pelo ícone no header da app',
                  ],
                ),
                TutorialStep(
                  key: _keySettingsPassword,
                  title: 'Segurança da Conta',
                  description: 'Acesse opções de segurança: trocar senha, ver dispositivos conectados e sair do app. Use uma senha forte (mínimo 8 caracteres com letras, números e símbolos) e troque periodicamente.',
                  icon: Icons.lock_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Mínimo 6 caracteres (recomendado 8+)',
                    'Nunca compartilhe sua senha',
                    'Troque a cada 3-6 meses',
                    'Esqueceu? Peça a um administrador para redefinir',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Perfil do usuário
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    radius: 28,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: AppTypography.headingMedium
                          .copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Usuário',
                          style: AppTypography.headingSmall
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          user?.email ?? '',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          _roleLabel(user?.role.name ?? ''),
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            if (adminDeVerdade) ...[
              const CasaSectionHeader(title: 'Apresentação'),
              const SizedBox(height: AppSpacing.sm),
              _SettingsTile(
                icon: Icons.visibility_rounded,
                label: 'Ver o app como outro perfil',
                onTap: () => abrirEscolhaDeVisao(context, ref),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (ehOps) ...[
            const CasaSectionHeader(title: 'Sistema'),
            const SizedBox(height: AppSpacing.sm),
            if (ehAdmin)
            KeyedSubtree(
              key: _keySettingsUsers,
              child: _SettingsTile(
                icon: Icons.people_outline_rounded,
                label: 'Gerenciar Usuários',
                onTap: () => context.push(AppRoutes.usersManagement),
              ),
            ),
            if (ehAdmin)
            _SettingsTile(
              icon: Icons.category_outlined,
              label: 'Categorias',
              onTap: () => context.push(AppRoutes.categoriesSettings),
            ),
            _SettingsTile(
              icon: Icons.location_on_outlined,
              label: 'Localizações / Prateleiras',
              onTap: () => context.push(AppRoutes.locations),
            ),
            if (ehAdmin)
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Configurações de Alertas',
              onTap: () => context.push(AppRoutes.alertsSettings),
            ),
            if (ehAdmin)
            _SettingsTile(
              icon: Icons.approval_outlined,
              label: 'Aprovações de Ajuste',
              onTap: () => context.push(AppRoutes.adjustmentApprovals),
            ),
            const SizedBox(height: AppSpacing.lg),
            ],

            const CasaSectionHeader(title: 'Dados'),
            const SizedBox(height: AppSpacing.sm),
            if (ehOps)
            _SettingsTile(
              icon: Icons.history_rounded,
              label: 'Auditoria',
              onTap: () => context.push(AppRoutes.audit),
            ),
            _SettingsTile(
              icon: Icons.bar_chart_rounded,
              label: 'Relatórios',
              onTap: () => context.push(AppRoutes.reports),
            ),
            const SizedBox(height: AppSpacing.lg),

            const CasaSectionHeader(title: 'Conta'),
            const SizedBox(height: AppSpacing.sm),
            KeyedSubtree(
              key: _keySettingsTheme,
              child: _TemaTile(
                escolhido: themeMode,
                onEscolher: (modo) => ref.read(themeModeProvider.notifier).setThemeMode(modo),
              ),
            ),
            KeyedSubtree(
              key: _keySettingsPassword,
              child: _SettingsTile(
                icon: Icons.password_rounded,
                label: 'Trocar senha',
                onTap: () => _showChangePasswordDialog(context, ref),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            const CasaSectionHeader(title: 'Segurança'),
            const SizedBox(height: AppSpacing.sm),
            const _TwoFASwitchTile(),
            const SizedBox(height: AppSpacing.lg),

            const CasaSectionHeader(title: 'Sessão'),
            const SizedBox(height: AppSpacing.sm),
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Sair',
              color: AppColors.danger600,
              onTap: () async {
                final confirm = await CasaDialogConfirmacao.show(
                  context: context,
                  title: 'Sair',
                  message: 'Deseja encerrar sua sessão?',
                  confirmLabel: 'Sair',
                  isDanger: true,
                );
                if (confirm == true && context.mounted) {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go(AppRoutes.login);
                }
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            Center(
              child: Text(
                'EducaStock v1.0.0 • ONG Casa da Criança',
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      ]),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'admin' => 'Administrador',
        'estoquista' => 'Estoquista',
        'voluntario' => 'Voluntário Autorizado',
        'consulta' => 'Consulta',
        _ => role,
      };
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(icon, color: c, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLarge.copyWith(color: c),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoFASwitchTile extends ConsumerStatefulWidget {
  const _TwoFASwitchTile();

  @override
  ConsumerState<_TwoFASwitchTile> createState() => _TwoFASwitchTileState();
}

class _TwoFASwitchTileState extends ConsumerState<_TwoFASwitchTile> {
  bool _loading = false;

  Future<void> _toggle(bool enabled) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    if (!enabled) {
      final confirmed = await CasaDialogConfirmacao.show(
        context: context,
        title: 'Desativar autenticação de dois fatores',
        message:
            'Tem certeza? Sua conta ficará menos protegida sem o segundo fator.',
        confirmLabel: 'Desativar',
        isDanger: true,
      );
      if (confirmed != true) return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(authDatasourceProvider)
          .enable2FA(user.id, enabled: enabled);
      ref.invalidate(authStateProvider);
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: enabled
            ? 'Autenticação de dois fatores ativada. Será exigida no próximo login.'
            : 'Autenticação de dois fatores desativada.',
        isSuccess: true,
      );
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Não foi possível atualizar a configuração.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;
    // Sem envio real do código (e-mail pelo servidor) o 2FA não pode ser exigido.
    const disponivel = AuthRemoteDatasource.otpDeliveryAvailable;
    final enabled = disponivel && (user?.twoFactorEnabled ?? false);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.brandPrimary600,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Autenticação de dois fatores',
                    style: AppTypography.bodyLarge.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: enabled,
                    onChanged: (_loading || !disponivel) ? null : _toggle,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              !disponivel
                  ? 'Indisponível por enquanto: o envio do código por e-mail depende do '
                      'servidor (Cloud Functions). O acesso segue protegido pela senha e '
                      'pelas regras de cada perfil.'
                  : enabled
                      ? 'Ativo — um código será exigido no próximo login.'
                      : 'Inativo — ative para exigir um código a cada login.',
              style: AppTypography.bodySmall.copyWith(
                color: enabled
                    ? AppColors.success600
                    : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tema: Claro, Escuro ou Sistema. O seletor mostra o modo ESCOLHIDO; o texto
/// abaixo explica o modo EM USO (no "Sistema", segue o aparelho).
class _TemaTile extends StatelessWidget {
  final ThemeMode escolhido;
  final ValueChanged<ThemeMode> onEscolher;
  const _TemaTile({required this.escolhido, required this.onEscolher});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final escuroAgora = Theme.of(context).brightness == Brightness.dark;
    const opcoes = [
      (ThemeMode.light, 'Claro', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Escuro', Icons.dark_mode_outlined),
      (ThemeMode.system, 'Sistema', Icons.brightness_auto_outlined),
    ];
    final explicacao = switch (escolhido) {
      ThemeMode.system => 'Segue o aparelho — agora ${escuroAgora ? 'escuro' : 'claro'}.',
      ThemeMode.dark => 'Sempre escuro.',
      ThemeMode.light => 'Sempre claro.',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: cs.onSurface, size: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text('Tema', style: AppTypography.bodyLarge.copyWith(color: cs.onSurface)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              label: 'Tema do aplicativo',
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final (modo, rotulo, icone) in opcoes)
                    ChoiceChip(
                      selected: escolhido == modo,
                      onSelected: (_) => onEscolher(modo),
                      avatar: Icon(icone, size: 18),
                      label: Text(rotulo),
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(explicacao, style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
