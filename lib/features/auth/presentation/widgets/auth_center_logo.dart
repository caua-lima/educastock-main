import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';

class AuthCenterLogo extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthCenterLogo({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            boxShadow: const [
              BoxShadow(
                color: Color(0x331D5FA8),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: AppColors.brandPrimary100,
              width: 2.5,
            ),
          ),
          child: ClipOval(
            child: Transform.scale(
              scale: 1.55, // zoom in para eliminar espaços em branco
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          style: AppTypography.headingLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
