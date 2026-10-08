import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design_system/design_system.dart';
import 'app_router.dart';

/// Shell de navegação do DOADOR (RNF16): 5 abas — Início, Precisa, Doar,
/// Doações e Perfil. Independente do `AppNavigationShell` da equipe.
class DonorNavigationShell extends StatelessWidget {
  final Widget child;
  final String location;

  const DonorNavigationShell({
    super.key,
    required this.child,
    required this.location,
  });

  static const _tabs = [
    _DonorTab(Icons.home_outlined, Icons.home_rounded, 'Início'),
    _DonorTab(Icons.favorite_border_rounded, Icons.favorite_rounded, 'Precisa'),
    _DonorTab(Icons.add_circle_outline_rounded, Icons.add_circle_rounded, 'Doar'),
    _DonorTab(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Doações'),
    _DonorTab(Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  int get _selectedIndex {
    if (location.startsWith(AppRoutes.donorNeeds)) return 1;
    if (location.startsWith(AppRoutes.donorDonations)) return 3;
    if (location.startsWith(AppRoutes.donorProfile)) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.donorHome);
      case 1:
        context.go(AppRoutes.donorNeeds);
      case 2:
        // Formulário de tela cheia, fora do shell (evita conflito de GlobalKey).
        context.push(AppRoutes.donorDonate);
      case 3:
        context.go(AppRoutes.donorDonations);
      case 4:
        context.go(AppRoutes.donorProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selectedIndex;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isSelected = selected == i && i != 2;
                final color =
                    isSelected ? AppColors.brandPrimary600 : cs.onSurfaceVariant;
                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: tab.label,
                    child: InkWell(
                      onTap: () => _onTap(context, i),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? tab.activeIcon : tab.icon,
                              size: 24,
                              color: i == 2 ? AppColors.brandPrimary600 : color,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tab.label,
                              style: AppTypography.labelSmall.copyWith(
                                color: i == 2 ? AppColors.brandPrimary600 : color,
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _DonorTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _DonorTab(this.icon, this.activeIcon, this.label);
}
