import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../auth/presentation/utils/auth_error_mapper.dart';

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
                              message: 'As senhas nao conferem.',
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
                                  fallback: 'Nao foi possivel trocar a senha.',
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
    final isDark = themeMode == ThemeMode.dark;

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
                  title: 'Gerenciar Usuárias',
                  description: 'Toque para acessar a tela de gerenciamento de colaboradoras: cadastrar novas pessoas, definir o perfil (Admin/Estoquista/Voluntária/Consulta), ativar ou desativar acessos. Apenas administradoras enxergam essa opção.',
                  icon: Icons.manage_accounts_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '👑 Admin: acesso total — cria, edita, exclui',
                    '📦 Estoquista: opera o dia-a-dia (cadastro + saída)',
                    '🤝 Voluntária: ações básicas (entrada + consulta)',
                    '👀 Consulta: apenas leitura (relatórios)',
                  ],
                ),
                TutorialStep(
                  key: _keySettingsTheme,
                  title: 'Tema Claro / Escuro',
                  description: 'Alterne entre os dois modos visuais do app. O tema escuro reduz o cansaço visual em ambientes com pouca luz e economiza bateria em celulares com tela OLED/AMOLED. A preferência é salva por dispositivo.',
                  icon: Icons.dark_mode_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '☀️ Claro: ideal para ambientes bem iluminados',
                    '🌙 Escuro: confortável à noite, economiza bateria OLED',
                    '🎨 Cores e contrastes ajustam automaticamente',
                    '⚙️ Também acessível pelo ícone no header da app',
                  ],
                ),
                TutorialStep(
                  key: _keySettingsPassword,
                  title: 'Segurança da Conta',
                  description: 'Acesse opções de segurança: trocar senha, ver dispositivos conectados e sair do app. Use uma senha forte (mínimo 8 caracteres com letras, números e símbolos) e troque periodicamente.',
                  icon: Icons.lock_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    '🔐 Mínimo 6 caracteres (recomendado 8+)',
                    '🤫 Nunca compartilhe sua senha',
                    '🔄 Troque a cada 3-6 meses',
                    '📞 Esqueceu? Peça reset à administradora',
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

            const CasaSectionHeader(title: 'Sistema'),
            const SizedBox(height: AppSpacing.sm),
            KeyedSubtree(
              key: _keySettingsUsers,
              child: _SettingsTile(
                icon: Icons.people_outline_rounded,
                label: 'Gerenciar Usuários',
                onTap: () => context.push(AppRoutes.usersManagement),
              ),
            ),
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
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Configurações de Alertas',
              onTap: () => context.push(AppRoutes.alertsSettings),
            ),
            _SettingsTile(
              icon: Icons.approval_outlined,
              label: 'Aprovações de Ajuste',
              onTap: () => context.push(AppRoutes.adjustmentApprovals),
            ),
            const SizedBox(height: AppSpacing.lg),

            const CasaSectionHeader(title: 'Dados'),
            const SizedBox(height: AppSpacing.sm),
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
              child: _SettingsSwitchTile(
                icon: Icons.dark_mode_outlined,
                label: 'Tema escuro',
                value: isDark,
                onChanged: (v) async {
                  await ref.read(themeModeProvider.notifier).toggleDark(v);
                },
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

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                color: cs.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(icon, color: cs.onSurface, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
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
    final enabled = user?.twoFactorEnabled ?? false;

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
                    onChanged: _loading ? null : _toggle,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              enabled
                  ? 'Ativo — um código será exigido no próximo login.'
                  : 'Inativo — ative para exigir um código OTP a cada login.',
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
