import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ml/domain/entities/risk_prediction.dart';
import '../../features/ml/presentation/controllers/risk_classifier_provider.dart';
import '../design_system/components/casa_tutorial.dart';
import 'app_router.dart';

class AppNavigationShell extends StatefulWidget {
  final Widget child;
  final String location;

  const AppNavigationShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  static const _tabRoutes = [
    AppRoutes.dashboard,
    AppRoutes.productList,
    '${AppRoutes.movement}?batchId=',
    AppRoutes.history,
    AppRoutes.reports,
  ];

  bool _tutorialActive = false;

  @override
  void initState() {
    super.initState();
    _tutorialActive = tutorialActiveNotifier.value;
    tutorialActiveNotifier.addListener(_onTutorialChanged);
  }

  @override
  void dispose() {
    tutorialActiveNotifier.removeListener(_onTutorialChanged);
    super.dispose();
  }

  void _onTutorialChanged() {
    if (mounted) setState(() => _tutorialActive = tutorialActiveNotifier.value);
  }

  int _selectedIndex(String currentLocation) {
    if (currentLocation.startsWith(AppRoutes.movement)) return 2;
    if (currentLocation.startsWith(AppRoutes.history)) return 3;
    if (currentLocation.startsWith(AppRoutes.reports)) return 4;
    if (currentLocation.startsWith(AppRoutes.productList)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(widget.location);
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _tutorialActive
          ? null
          : _AnimatedTabBar(
              selectedIndex: idx,
              onTap: (i) => context.go(_tabRoutes[i]),
            ),
    );
  }
}

// ─── Tab definitions ────────────────────────────────────────────────────────

class _TabDef {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  const _TabDef({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

const _tabs = [
  _TabDef(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Início',
    color: Color(0xFF1D5FA8),
  ),
  _TabDef(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2_rounded,
    label: 'Estoque',
    color: Color(0xFF2563EB),
  ),
  _TabDef(
    icon: Icons.outbound_outlined,
    activeIcon: Icons.outbound_rounded,
    label: 'Saída',
    color: Color(0xFFC53030),
  ),
  _TabDef(
    icon: Icons.history_outlined,
    activeIcon: Icons.history_rounded,
    label: 'Histórico',
    color: Color(0xFF7C3AED),
  ),
  _TabDef(
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
    label: 'Relatórios',
    color: Color(0xFF2E7D32),
  ),
];

// ─── Animated Tab Bar ────────────────────────────────────────────────────────

class _AnimatedTabBar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _AnimatedTabBar({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    // Badge ML: # de lotes em risco vermelho (lê do classifier).
    // Aparece em Estoque (idx 1) e Saída (idx 2) — ambos lidam com lotes.
    final criticalCount = ref.watch(riskCountsProvider).maybeWhen(
          data: (counts) => counts[RiskLevel.vermelho] ?? 0,
          orElse: () => 0,
        );

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final showBadge = criticalCount > 0 && (i == 1 || i == 2);
              return Expanded(
                child: _TabItem(
                  tab: _tabs[i],
                  selected: selectedIndex == i,
                  badgeCount: showBadge ? criticalCount : 0,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final _TabDef tab;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _TabItem({
    required this.tab,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? tab.color.withValues(alpha: isDark ? 0.22 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.18 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    selected ? tab.activeIcon : tab.icon,
                    size: 24,
                    color: selected ? tab.color : inactiveColor,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -7,
                    top: -4,
                    child: _MlBadge(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: selected ? 10.5 : 9.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? tab.color : inactiveColor,
                letterSpacing: selected ? 0.2 : 0,
              ),
              child: Text(tab.label, maxLines: 1),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(top: 3),
              height: 3,
              width: selected ? 20 : 0,
              decoration: BoxDecoration(
                color: tab.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MlBadge extends StatelessWidget {
  final int count;
  const _MlBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53E3E), Color(0xFFC53030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53E3E).withValues(alpha: 0.45),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
