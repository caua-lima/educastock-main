import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/auth_provider.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  ConsumerState<OtpVerificationPage> createState() =>
      _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otpCode.length < 6 || _otpCode.contains(' ')) {
      showCasaSnackbar(
        context,
        message: 'Digite o código completo de 6 dígitos.',
        isError: true,
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final ds = ref.read(authDatasourceProvider);
      final valid = await ds.verifyOtp(user.id, _otpCode);
      if (!mounted) return;
      if (valid) {
        ref.read(pendingOtpProvider.notifier).state = false;
        // Router redirect handles navigation to dashboard
      } else {
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
        showCasaSnackbar(
          context,
          message: 'Código inválido ou expirado. Tente novamente.',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Erro ao verificar o código. Tente novamente.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isResending = true);
    try {
      await ref.read(authDatasourceProvider).sendOtp(user.id);
      if (!mounted) return;
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      showCasaSnackbar(
        context,
        message: 'Código reenviado com sucesso.',
        isSuccess: true,
      );
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Erro ao reenviar o código.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    ref.read(pendingOtpProvider.notifier).state = false;
    await ref.read(authNotifierProvider.notifier).signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await CasaDialogConfirmacao.show(
      context: context,
      title: 'Cancelar verificação',
      message:
          'Deseja cancelar a verificação e sair da conta?',
      confirmLabel: 'Sair',
      isDanger: true,
    );
    if (confirmed == true && mounted) {
      await _signOut();
    }
  }

  Widget _buildDigitBox(int index, ColorScheme cs) {
    final focusNode = _focusNodes[index];
    focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.backspace &&
          _controllers[index].text.isEmpty &&
          index > 0) {
        _focusNodes[index - 1].requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    return SizedBox(
      width: 44,
      height: 54,
      child: TextField(
        controller: _controllers[index],
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enabled: !_isLoading,
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide(color: cs.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide:
                const BorderSide(color: AppColors.brandPrimary600, width: 2),
          ),
          filled: true,
          fillColor: cs.surfaceContainerLow,
        ),
        style: AppTypography.numberSmall.copyWith(color: cs.onSurface),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (index == 5 && value.isNotEmpty && _otpCode.length == 6) {
            _verify();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmSignOut();
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: Column(
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Verificação em duas etapas',
                        style: AppTypography.headingMedium
                            .copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Enviamos um código para',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: AppTypography.labelMedium
                            .copyWith(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Digite o código de 6 dígitos',
                      style: AppTypography.headingSmall.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'O código expira em 10 minutos.',
                      style: AppTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 6-digit boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        6,
                        (i) => _buildDigitBox(i, cs),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),

                    CasaButton(
                      label: 'Verificar código',
                      onPressed: _isLoading ? null : _verify,
                      isLoading: _isLoading,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaButton(
                      label: 'Reenviar código',
                      variant: CasaButtonVariant.secondary,
                      onPressed:
                          (_isResending || _isLoading) ? null : _resend,
                      isLoading: _isResending,
                      icon: Icons.refresh_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaButton(
                      label: 'Sair',
                      variant: CasaButtonVariant.ghost,
                      onPressed: _isLoading ? null : _signOut,
                      icon: Icons.logout_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
