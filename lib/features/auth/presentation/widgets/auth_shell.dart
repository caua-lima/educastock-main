import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';

class AuthShell extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final String footerText;
  final String footerActionLabel;
  final VoidCallback onFooterAction;
  final bool compactBrandPanel;
  final bool showFeatureBadges;
  final bool showBrandPanel;

  const AuthShell({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footerText,
    required this.footerActionLabel,
    required this.onFooterAction,
    this.compactBrandPanel = false,
    this.showFeatureBadges = true,
    this.showBrandPanel = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0B1220), Color(0xFF0F172A), Color(0xFF0B1220)]
                : const [Color(0xFFF5FAFF), Color(0xFFD9EBFF), Color(0xFFEFF6FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 980;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: showBrandPanel ? 1180 : 560,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: !showBrandPanel
                        ? SingleChildScrollView(
                            child: _AuthCard(
                              footerText: footerText,
                              footerActionLabel: footerActionLabel,
                              onFooterAction: onFooterAction,
                              child: child,
                            ),
                          )
                        : wide
                        ? Row(
                            children: [
                              Expanded(
                                child: _BrandPanel(
                                  eyebrow: eyebrow,
                                  title: title,
                                  subtitle: subtitle,
                                  compact: compactBrandPanel,
                                  showFeatureBadges: showFeatureBadges,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(
                                child: _AuthCard(
                                  footerText: footerText,
                                  footerActionLabel: footerActionLabel,
                                  onFooterAction: onFooterAction,
                                  child: child,
                                ),
                              ),
                            ],
                          )
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _BrandPanel(
                                  eyebrow: eyebrow,
                                  title: title,
                                  subtitle: subtitle,
                                  compact: true,
                                  showFeatureBadges: showFeatureBadges,
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                _AuthCard(
                                  footerText: footerText,
                                  footerActionLabel: footerActionLabel,
                                  onFooterAction: onFooterAction,
                                  child: child,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool compact;
  final bool showFeatureBadges;

  const _BrandPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.showFeatureBadges = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.xl : AppSpacing.xxxl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.modal),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandPrimary800, AppColors.brandPrimary600],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0B3C74),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              eyebrow,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.surface,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Container(
                width: compact ? 80 : 96,
                height: compact ? 80 : 96,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Transform.scale(
                    scale: 1.55,
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EducaStock',
                      style: AppTypography.displayMedium.copyWith(
                        color: AppColors.surface,
                      ),
                    ),
                    Text(
                      'Casa da Crianca',
                      style: AppTypography.bodyLarge.copyWith(
                        color: const Color(0xFFDCEBFA),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            style: AppTypography.displayLarge.copyWith(
              color: AppColors.surface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            style: AppTypography.bodyLarge.copyWith(
              color: const Color(0xFFDCEBFA),
              height: 1.6,
            ),
          ),
          if (showFeatureBadges) ...[
            const SizedBox(height: AppSpacing.xxl),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: const [
                _FeatureBadge(icon: Icons.qr_code_scanner_rounded, label: 'Scanner e cadastro rapido'),
                _FeatureBadge(icon: Icons.notifications_active_rounded, label: 'Alertas de estoque e vencimento'),
                _FeatureBadge(icon: Icons.verified_user_rounded, label: 'Acesso por perfis e auditoria'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.surface, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  final Widget child;
  final String footerText;
  final String footerActionLabel;
  final VoidCallback onFooterAction;

  const _AuthCard({
    required this.child,
    required this.footerText,
    required this.footerActionLabel,
    required this.onFooterAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : AppColors.surface;
    final cardBorder = isDark ? const Color(0xFF374151) : AppColors.brandPrimary100;
    final shadowColor = isDark ? const Color(0x40000000) : const Color(0x140B3C74);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.modal),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF374151) : AppColors.brandPrimary100,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          child,
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                footerText,
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: onFooterAction,
                child: Text(footerActionLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}