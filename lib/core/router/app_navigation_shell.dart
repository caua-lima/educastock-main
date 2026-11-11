import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/controllers/alerts_provider.dart';
import '../../features/auth/presentation/controllers/auth_provider.dart';
import '../../features/donation_ops/presentation/controllers/donation_ops_provider.dart';
import '../../features/ml/domain/entities/risk_prediction.dart';
import '../../features/ml/presentation/controllers/risk_classifier_provider.dart';
import '../design_system/components/adaptive_side_rail.dart';
import '../design_system/components/casa_tutorial.dart';
import '../design_system/layout/breakpoints.dart';
import '../search/command_palette.dart';
import 'app_router.dart';

class AppNavigationShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const AppNavigationShell({
    super.key,
    required this.child,
    required this.location,
  });

  @override
  ConsumerState<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends ConsumerState<AppNavigationShell> {
  static const _tabRoutes = [
    AppRoutes.dashboard,
    AppRoutes.productList,
    AppRoutes.movement,
    AppRoutes.history,
    AppRoutes.reports,
  ];

  bool _tutorialActive = false;
  bool _paletteOpen = false;

  static const _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
  ];

  @override
  void initState() {
    super.initState();
    _tutorialActive = tutorialActiveNotifier.value;
    tutorialActiveNotifier.addListener(_onTutorialChanged);
    // Atalhos globais (computador): funcionam com qualquer campo em foco.
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    tutorialActiveNotifier.removeListener(_onTutorialChanged);
    super.dispose();
  }

  List<String> get _routes => [
        ..._tabRoutes,
        if (canOperateDonations(ref.read(currentUserProvider))) AppRoutes.opsDonations,
      ];

  /// Ctrl+K (ou Cmd+K) abre a busca; Alt+1 a Alt+6 trocam de aba.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted || _tutorialActive) return false;
    final kb = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyK && (kb.isControlPressed || kb.isMetaPressed)) {
      _openPalette();
      return true;
    }
    if (kb.isAltPressed && !kb.isControlPressed && !_paletteOpen) {
      final i = _digitKeys.indexOf(event.logicalKey);
      final routes = _routes;
      if (i >= 0 && i < routes.length) {
        context.go(routes[i]);
        return true;
      }
    }
    return false;
  }

  Future<void> _openPalette() async {
    if (_paletteOpen) return;
    _paletteOpen = true;
    try {
      await showCommandPalette(context);
    } finally {
      _paletteOpen = false;
    }
  }

  void _onTutorialChanged() {
    if (mounted) setState(() => _tutorialActive = tutorialActiveNotifier.value);
  }

  int _selectedIndex(String currentLocation) {
    if (currentLocation.startsWith(AppRoutes.opsDonations)) return 5;
    if (currentLocation.startsWith(AppRoutes.movement)) return 2;
    if (currentLocation.startsWith(AppRoutes.history)) return 3;
    if (currentLocation.startsWith(AppRoutes.reports)) return 4;
    if (currentLocation.startsWith(AppRoutes.productList)) return 1;
    return 0;
  }

  /// Índice da aba principal que corresponde à rota atual, ou -1 se for outra tela.
  int _railIndex(String location) {
    if (location.startsWith(AppRoutes.dashboard)) return 0;
    if (location.startsWith(AppRoutes.opsDonations)) return 5;
    if (location.startsWith(AppRoutes.history)) return 3;
    if (location.startsWith(AppRoutes.reports)) return 4;
    if (location.startsWith(AppRoutes.productList)) return 1;
    if (location == AppRoutes.movement) return 2;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _selectedIndex(widget.location);
    // A aba de doações só existe para quem opera o portal (administrador e estoquista).
    final usuario = ref.watch(currentUserProvider);
    final showDonations = canOperateDonations(usuario);
    // Progresso dos tutoriais é guardado por conta.
    TutorialProgresso.usuarioAtual = usuario?.id ?? 'anonimo';
    final routes = [..._tabRoutes, if (showDonations) AppRoutes.opsDonations];
    final width = MediaQuery.sizeOf(context).width;

    // Celular: barra inferior (como antes).
    if (width < AppBreakpoints.rail) {
      return Scaffold(
        body: widget.child,
        // A barra fica durante o tutorial: escondê-la mudava o layout e o
        // destaque apontava para o lugar errado. O tutorial é modal (por cima).
        bottomNavigationBar: _AnimatedTabBar(
          selectedIndex: idx,
          showDonations: showDonations,
          onTap: (i) => context.go(routes[i]),
        ),
      );
    }

    // Tablet e computador: navegação lateral + conteúdo centralizado com largura máxima.
    final criticalCount = ref.watch(riskCountsProvider).maybeWhen(
          data: (counts) => counts[RiskLevel.vermelho] ?? 0,
          orElse: () => 0,
        );
    final pendingDonations = showDonations ? ref.watch(pendingDonationsCountProvider) : 0;
    final openAlerts = ref.watch(activeAlertsProvider).maybeWhen(
          data: (list) => list.length,
          orElse: () => 0,
        );
    final railIdx = _railIndex(widget.location);
    final visibleTabs = [..._tabs, if (showDonations) _donationsTab];
    final loc = widget.location;

    return Scaffold(
      body: Row(
        children: [
          AdaptiveSideRail(
            extended: width >= AppBreakpoints.expanded,
            subtitle: 'Casa da Criança · Equipe',
            onSearch: _openPalette,
            primary: [
              for (var i = 0; i < visibleTabs.length; i++)
                RailDestination(
                  icon: visibleTabs[i].icon,
                  activeIcon: visibleTabs[i].activeIcon,
                  label: visibleTabs[i].label,
                  color: visibleTabs[i].color,
                  selected: railIdx == i,
                  badge: i == 5 ? pendingDonations : ((i == 1 || i == 2) ? criticalCount : 0),
                  onTap: () => context.go(routes[i]),
                ),
            ],
            secondary: [
              RailDestination(
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_active_rounded,
                label: 'Alertas',
                color: const Color(0xFFB7791F),
                selected: loc.startsWith(AppRoutes.alerts),
                badge: openAlerts,
                onTap: () => context.go(AppRoutes.alerts),
              ),
              RailDestination(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Configurações',
                color: const Color(0xFF475569),
                selected: loc.startsWith(AppRoutes.settings),
                onTap: () => context.go(AppRoutes.settings),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
                child: widget.child,
              ),
            ),
          ),
        ],
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

const _donationsTab = _TabDef(
  icon: Icons.volunteer_activism_outlined,
  activeIcon: Icons.volunteer_activism_rounded,
  label: 'Doações',
  color: Color(0xFFB7791F),
);

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
  final bool showDonations;
  final ValueChanged<int> onTap;

  const _AnimatedTabBar({
    required this.selectedIndex,
    required this.showDonations,
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

    final visibleTabs = [..._tabs, if (showDonations) _donationsTab];
    final pendingDonations = showDonations ? ref.watch(pendingDonationsCountProvider) : 0;

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
            children: List.generate(visibleTabs.length, (i) {
              final isDonations = showDonations && i == _tabs.length;
              final showBadge = criticalCount > 0 && (i == 1 || i == 2);
              return Expanded(
                child: _TabItem(
                  tab: visibleTabs[i],
                  selected: selectedIndex == i,
                  badgeCount: isDonations
                      ? pendingDonations
                      : (showBadge ? criticalCount : 0),
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
