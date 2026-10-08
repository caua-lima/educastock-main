import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/observability/analytics_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../controllers/auth_provider.dart';
import '../utils/auth_error_mapper.dart';
import '../widgets/google_sign_in_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberLogin = true;

  late final AnimationController _entryAnim;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ds = ref.read(authDatasourceProvider);
      final remember = await ds.getRememberLogin();
      final rememberedEmail = await ds.getRememberedEmail();
      if (!mounted) return;
      setState(() {
        _rememberLogin = remember;
        if (rememberedEmail != null) {
          _emailController.text = rememberedEmail;
        }
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _entryAnim.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text,
          rememberLogin: _rememberLogin,
        );

    final state = ref.read(authNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (user) async {
        if (user != null) {
          ref.read(analyticsServiceProvider).logAuthLogin(method: 'password');
          if (user.twoFactorEnabled) {
            try {
              await ref.read(authDatasourceProvider).sendOtp(user.id);
            } catch (_) {
              if (!mounted) return;
              showCasaSnackbar(context,
                  message: 'Não foi possível enviar o código 2FA.',
                  isError: true);
              return;
            }
            if (!mounted) return;
            ref.read(pendingOtpProvider.notifier).state = true;
            context.go(AppRoutes.otpVerification);
          } else {
            ref.read(pendingOtpProvider.notifier).state = false;
            context.go(AppRoutes.dashboard);
          }
        } else {
          showCasaSnackbar(context,
              message: 'Não foi possível autenticar este usuário.',
              isError: true);
        }
      },
      error: (error, __) => showCasaSnackbar(context,
          message: mapAuthError(error, fallback: 'Falha ao entrar.'),
          isError: true),
      loading: () {},
    );
  }

  Future<void> _signInWithGoogle() async {
    await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle(rememberLogin: _rememberLogin);
    final state = ref.read(authNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (user) async {
        if (user != null) {
          ref.read(analyticsServiceProvider).logAuthLogin(method: 'google');
          if (user.twoFactorEnabled) {
            try {
              await ref.read(authDatasourceProvider).sendOtp(user.id);
            } catch (_) {
              if (!mounted) return;
              showCasaSnackbar(context,
                  message: 'Não foi possível enviar o código 2FA.',
                  isError: true);
              return;
            }
            if (!mounted) return;
            ref.read(pendingOtpProvider.notifier).state = true;
            context.go(AppRoutes.otpVerification);
          } else {
            ref.read(pendingOtpProvider.notifier).state = false;
            context.go(AppRoutes.dashboard);
          }
        }
        if (user == null) {
          showCasaSnackbar(context,
              message: 'Login com Google cancelado.', isError: true);
        }
      },
      error: (error, __) => showCasaSnackbar(context,
          message: mapAuthError(error,
              fallback: 'Falha ao entrar com Google.'),
          isError: true),
      loading: () {},
    );
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      showCasaSnackbar(context,
          message: 'Informe o e-mail para recuperar a senha.',
          isError: true);
      return;
    }
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .sendPasswordReset(_emailController.text.trim());
      ref.read(analyticsServiceProvider).logPasswordReset();
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Enviamos o link de redefinição para seu e-mail.',
          isSuccess: true);
    } catch (error, stackTrace) {
      ref.read(analyticsServiceProvider).recordHandledError(error, stackTrace,
          reason: 'auth_password_reset_failed');
      if (!mounted) return;
      showCasaSnackbar(context,
          message: mapAuthError(error,
              fallback: 'Não foi possível enviar o e-mail de recuperação.'),
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0A1426) : const Color(0xFFF5FAFF),
        body: Stack(
          children: [
            // ── Fundo decorativo com gradient + glows ──
            const Positioned.fill(child: _LoginBackdrop()),

            // ── Toggle dark/light no canto superior direito ──
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ThemeToggleFab(isDark: isDark),
                ),
              ),
            ),

            // ── Conteúdo central ──
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedBuilder(
                      animation: _entryAnim,
                      builder: (_, child) {
                        final t =
                            Curves.easeOutCubic.transform(_entryAnim.value);
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 24),
                            child: child,
                          ),
                        );
                      },
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ── Logo gigante com glow ──
                            const _BigLogo(),
                            const SizedBox(height: 20),
                            // ── Título + subtítulo ──
                            Text(
                              'Bem-vinda de volta',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F2444),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Entre para continuar gerenciando o estoque da Casa da Criança',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.65)
                                    : const Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── Card de login ──
                            _LoginCard(
                              isDark: isDark,
                              child: Column(
                                children: [
                                  CasaTextField(
                                    label: 'E-mail',
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    prefixIcon: const Icon(
                                        Icons.alternate_email_rounded,
                                        size: 20),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Informe o e-mail';
                                      }
                                      if (!v.contains('@')) {
                                        return 'E-mail inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  CasaTextField(
                                    label: 'Senha',
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _submit(),
                                    prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                        size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Informe a senha';
                                      }
                                      if (v.length < 6) {
                                        return 'Senha muito curta';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  // ── Manter login + esqueci senha ──
                                  Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: isLoading
                                              ? null
                                              : () => setState(() =>
                                                  _rememberLogin =
                                                      !_rememberLogin),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets
                                                .symmetric(vertical: 6),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: _rememberLogin,
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  onChanged: isLoading
                                                      ? null
                                                      : (v) => setState(() =>
                                                          _rememberLogin =
                                                              v ?? true),
                                                ),
                                                Text(
                                                  'Lembrar de mim',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: isDark
                                                        ? Colors.white
                                                            .withValues(
                                                                alpha: 0.75)
                                                        : const Color(0xFF475569),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed:
                                            isLoading ? null : _resetPassword,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Esqueci',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // ── Botão Entrar gradient ──
                                  _PrimaryLoginButton(
                                    onPressed: isLoading ? null : _submit,
                                    isLoading: isLoading,
                                  ),
                                  const SizedBox(height: 18),
                                  // ── Divisor "ou continue com" ──
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.10)
                                              : const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(
                                          'ou continue com',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.55)
                                                : const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.10)
                                              : const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // ── Google (real) — único método social ──
                                  GoogleSignInButton(
                                    onPressed: isLoading
                                        ? null
                                        : _signInWithGoogle,
                                    isLoading: false,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // ── Footer cadastro ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Ainda não tem conta?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.70)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      context.go(AppRoutes.register),
                                  child: const Text(
                                    'Criar agora',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Background com gradient + glows decorativos
// ═══════════════════════════════════════════════════════════════════════════

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF0A1426),
                  Color(0xFF0F2444),
                  Color(0xFF0A1426),
                ]
              : const [
                  Color(0xFFEAF4FF),
                  Color(0xFFFFFFFF),
                  Color(0xFFE8F1FF),
                ],
        ),
      ),
      child: Stack(
        children: [
          // Glow top-right
          Positioned(
            top: -120,
            right: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8)
                        .withValues(alpha: isDark ? 0.20 : 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Glow bottom-left
          Positioned(
            bottom: -150,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA78BFA)
                        .withValues(alpha: isDark ? 0.15 : 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Logo grande com glow azul ciano pulsante
// ═══════════════════════════════════════════════════════════════════════════

class _BigLogo extends StatefulWidget {
  const _BigLogo();

  @override
  State<_BigLogo> createState() => _BigLogoState();
}

class _BigLogoState extends State<_BigLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final t = _pulse.value;
        return Container(
          width: 148,
          height: 148,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                isDark ? const Color(0xFF1E3A5F) : Colors.white,
                isDark ? const Color(0xFF0F2444) : const Color(0xFFE8F1FF),
              ],
            ),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.40),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8)
                    .withValues(alpha: 0.30 + 0.15 * t),
                blurRadius: 30 + 10 * t,
                spreadRadius: 4 + 2 * t,
              ),
              BoxShadow(
                color: const Color(0xFF1D5FA8)
                    .withValues(alpha: isDark ? 0.40 : 0.20),
                blurRadius: 50,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Transform.scale(
                scale: 1.30,
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Toggle dark/light flutuante
// ═══════════════════════════════════════════════════════════════════════════

class _ThemeToggleFab extends ConsumerWidget {
  final bool isDark;
  const _ThemeToggleFab({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.20)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.30 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        tooltip: isDark ? 'Modo claro' : 'Modo escuro',
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            size: 20,
            color: isDark
                ? const Color(0xFFFBBF24)
                : const Color(0xFF1D5FA8),
          ),
        ),
        onPressed: () =>
            ref.read(themeModeProvider.notifier).toggleDark(!isDark),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Card branco/dark com o formulário
// ═══════════════════════════════════════════════════════════════════════════

class _LoginCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _LoginCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Botão Entrar com gradient + glow
// ═══════════════════════════════════════════════════════════════════════════

class _PrimaryLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  const _PrimaryLoginButton({required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1D5FA8),
              Color(0xFF38BDF8),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Entrar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

