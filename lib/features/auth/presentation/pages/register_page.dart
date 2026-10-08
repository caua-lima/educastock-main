import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/observability/analytics_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../donations/domain/entities/donor_profile.dart';
import '../../../donations/presentation/controllers/donor_profile_provider.dart';
import '../controllers/auth_provider.dart';
import '../utils/auth_error_mapper.dart';
import '../widgets/auth_center_logo.dart';
import '../widgets/auth_shell.dart';

/// D02 — Cadastro autônomo do doador (RF16).
///
/// Coleta tipo (PF/PJ), nome, e-mail, telefone, cidade e senha, exige o aceite
/// dos termos e grava `users/{uid}` (papel `doador`) + `donors/{uid}`.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Estado apenas de formulário/UI.
  DonorType _donorType = DonorType.pf;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberLogin = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      showCasaSnackbar(
        context,
        message: 'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
        isError: true,
      );
      return;
    }

    await ref.read(authNotifierProvider.notifier).registerDonor(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          donorType: _donorType,
          phone: _phoneController.text.trim(),
          city: _cityController.text.trim(),
          rememberLogin: _rememberLogin,
        );

    final state = ref.read(authNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (user) {
        if (user == null) {
          showCasaSnackbar(
            context,
            message: 'Cadastro não finalizado. Tente novamente.',
            isError: true,
          );
          return;
        }
        ref.read(analyticsServiceProvider).logAuthRegister();
        showCasaSnackbar(
          context,
          message: 'Conta criada! Enviamos um link de confirmação ao seu e-mail.',
          isSuccess: true,
        );
        context.go(AppRoutes.donorHome);
      },
      error: (error, _) => showCasaSnackbar(
        context,
        message: mapAuthError(error, fallback: 'Não foi possível criar a conta.'),
        isError: true,
      ),
      loading: () {},
    );
  }

  Future<void> _signInWithGoogle() async {
    if (!_acceptedTerms) {
      showCasaSnackbar(
        context,
        message: 'Aceite os Termos de Uso e a Política de Privacidade para continuar.',
        isError: true,
      );
      return;
    }

    await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle(rememberLogin: _rememberLogin);
    final state = ref.read(authNotifierProvider);
    if (!mounted) return;

    if (state.hasError) {
      showCasaSnackbar(
        context,
        message: mapAuthError(state.error!, fallback: 'Falha ao entrar com Google.'),
        isError: true,
      );
      return;
    }
    final user = state.valueOrNull;
    if (user == null) {
      showCasaSnackbar(context, message: 'Login com Google cancelado.', isError: true);
      return;
    }

    ref.read(analyticsServiceProvider).logAuthLogin(method: 'google');
    if (user.isDonor) {
      // Garante o perfil `donors/{uid}` com o consentimento recém-aceito.
      await ref
          .read(donorProfileNotifierProvider.notifier)
          .ensureProfile(uid: user.id, displayName: user.name);
      if (!mounted) return;
    }
    context.go(user.isDonor ? AppRoutes.donorHome : AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final isCompany = _donorType == DonorType.pj;
    final cs = Theme.of(context).colorScheme;

    return AuthShell(
      eyebrow: 'EducaStock',
      title: 'Criar conta de doador',
      subtitle: 'Doe o que a Casa da Criança realmente precisa.',
      footerText: 'Já possui conta?',
      footerActionLabel: 'Entrar',
      onFooterAction: () => context.go(AppRoutes.login),
      showBrandPanel: false,
      compactBrandPanel: true,
      showFeatureBadges: false,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.center,
              child: AuthCenterLogo(
                title: 'Portal do Doador',
                subtitle: 'Rápido, simples e seguro',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Quem está doando?',
              style: AppTypography.headingSmall.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<DonorType>(
              segments: [
                for (final t in DonorType.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {_donorType},
              onSelectionChanged:
                  isLoading ? null : (s) => setState(() => _donorType = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            CasaTextField(
              label: isCompany ? 'Razão social ou responsável' : 'Nome completo',
              controller: _nameController,
              textInputAction: TextInputAction.next,
              prefixIcon: Icon(
                isCompany ? Icons.business_rounded : Icons.person_outline_rounded,
                size: 20,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Informe seu nome';
                if (value.trim().length < 3) return 'Nome muito curto';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CasaTextField(
              label: 'E-mail',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Informe o e-mail';
                if (!value.contains('@') || !value.contains('.')) {
                  return 'E-mail inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CasaTextField(
              label: 'Telefone / WhatsApp',
              hint: '(19) 99999-9999',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10) return 'Informe o telefone com DDD';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CasaTextField(
              label: 'Cidade',
              controller: _cityController,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Informe a cidade' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            CasaTextField(
              label: 'Senha',
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Informe a senha';
                if (value.length < 8) return 'Use pelo menos 8 caracteres';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CasaTextField(
              label: 'Confirmar senha',
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              prefixIcon: const Icon(Icons.verified_user_outlined, size: 20),
              suffixIcon: IconButton(
                tooltip: _obscureConfirmPassword ? 'Mostrar senha' : 'Ocultar senha',
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Confirme a senha';
                if (value != _passwordController.text) return 'As senhas não conferem';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Consentimento (RNF13): obrigatório ───────────────────────
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _acceptedTerms,
              onChanged: isLoading
                  ? null
                  : (v) => setState(() => _acceptedTerms = v ?? false),
              title: Text(
                'Li e aceito os Termos de Uso e a Política de Privacidade. '
                'Autorizo o uso dos meus dados para registrar e acompanhar doações (LGPD).',
                style: AppTypography.bodySmall.copyWith(color: cs.onSurface),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _rememberLogin,
              onChanged:
                  isLoading ? null : (v) => setState(() => _rememberLogin = v ?? true),
              title: Text('Manter login', style: AppTypography.bodySmall),
            ),
            const SizedBox(height: AppSpacing.lg),
            CasaButton(
              label: 'Criar conta',
              onPressed: (isLoading || !_acceptedTerms) ? null : _submit,
              isLoading: isLoading,
              icon: Icons.person_add_alt_1_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'ou',
                    style: AppTypography.labelMedium
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            CasaButton(
              label: 'Continuar com Google',
              variant: CasaButtonVariant.secondary,
              onPressed: (isLoading || !_acceptedTerms) ? null : _signInWithGoogle,
              icon: Icons.g_mobiledata_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
