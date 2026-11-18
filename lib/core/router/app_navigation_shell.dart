import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/controllers/alerts_provider.dart';
import '../../features/auth/domain/entities/app_user.dart';
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

  List<String> get _routes =>
      [for (final a in abasDoPerfil(ref.read(currentUserProvider))) a.rota];

  /// Ctrl+K (ou Cmd+K) abre a busca; Alt+1 a Alt+6 trocam de aba.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted || _tutorialActive) return false;
    final kb = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyK &&
        (kb.isControlPressed || kb.isMetaPressed)) {
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

  @override
  Widget build(BuildContext context) {
    // Abas do perfil: Saída só para quem registra saídas; Doações só para quem opera o portal.
    final usuario = ref.watch(currentUserProvider);
    final abas = abasDoPerfil(usuario);
    final idx = indiceDaAba(widget.location, abas);
    final showDonations = canOperateDonations(usuario);
    // Progresso dos tutoriais é guardado por conta.
    TutorialProgresso.usuarioAtual = usuario?.id ?? 'anonimo';
    final width = MediaQuery.sizeOf(context).width;

    // Celular: barra inferior (como antes).
    if (width < AppBreakpoints.rail) {
      return Scaffold(
        body: widget.child,
        // A barra fica durante o tutorial: escondê-la mudava o layout e o
        // destaque apontava para o lugar errado. O tutorial é modal (por cima).
        bottomNavigationBar: _AnimatedTabBar(
          selectedIndex: idx,
          abas: abas,
          onTap: (i) => context.go(abas[i].rota),
        ),
      );
    }

    // Tablet e computador: navegação lateral + conteúdo centralizado com largura máxima.
    final criticalCount = ref.watch(riskCountsProvider).maybeWhen(
          data: (counts) => counts[RiskLevel.vermelho] ?? 0,
          orElse: () => 0,
        );
    final pendingDonations =
        showDonations ? ref.watch(pendingDonationsCountProvider) : 0;
    final openAlerts = ref.watch(activeAlertsProvider).maybeWhen(
          data: (list) => list.length,
          orElse: () => 0,
        );
    final loc = widget.location;

    return Scaffold(
      body: Row(
        children: [
          AdaptiveSideRail(
            extended: width >= AppBreakpoints.expanded,
            subtitle: 'Casa da Criança · Equipe',
            onSearch: _openPalette,
            primary: [
              for (var i = 0; i < abas.length; i++)
                RailDestination(
                  icon: abas[i].def.icon,
                  activeIcon: abas[i].def.activeIcon,
                  label: abas[i].def.label,
                  color: abas[i].def.color,
                  selected: idx == i,
                  badge: abas[i].rota == AppRoutes.opsDonations
                      ? pendingDonations
                      : (abas[i].mostraRisco ? criticalCount : 0),
                  onTap: () => context.go(abas[i].rota),
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
                constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.contentMaxWidth),
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

class DefinicaoAba {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  const DefinicaoAba({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

const _donationsTab = DefinicaoAba(
  icon: Icons.volunteer_activism_outlined,
  activeIcon: Icons.volunteer_activism_rounded,
  label: 'Doações',
  color: Color(0xFFB7791F),
);

const _tabs = [
  DefinicaoAba(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Início',
    color: Color(0xFF1D5FA8),
  ),
  DefinicaoAba(
    icon: Icons.inventory_2_outlined,
    activeIcon: Icons.inventory_2_rounded,
    label: 'Estoque',
    color: Color(0xFF2563EB),
  ),
  DefinicaoAba(
    icon: Icons.outbound_outlined,
    activeIcon: Icons.outbound_rounded,
    label: 'Saída',
    color: Color(0xFFC53030),
  ),
  DefinicaoAba(
    icon: Icons.history_outlined,
    activeIcon: Icons.history_rounded,
    label: 'Histórico',
    color: Color(0xFF7C3AED),
  ),
  DefinicaoAba(
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
    label: 'Relatórios',
    color: Color(0xFF2E7D32),
  ),
];

/// Uma aba da navegação principal.
class Aba {
  final String rota;
  final DefinicaoAba def;

  /// Mostra o número de lotes em risco crítico (Estoque e Saída lidam com lotes).
  final bool mostraRisco;
  const Aba(this.rota, this.def, {this.mostraRisco = false});
}

/// Abas que o perfil vê: Saída só para quem registra saídas (administrador e estoquista);
/// Doações só para quem opera o portal de doações.
List<Aba> abasDoPerfil(AppUser? usuario) => [
      Aba(AppRoutes.dashboard, _tabs[0]),
      Aba(AppRoutes.productList, _tabs[1], mostraRisco: true),
      if (usuario?.canEdit ?? false)
        Aba(AppRoutes.movement, _tabs[2], mostraRisco: true),
      Aba(AppRoutes.history, _tabs[3]),
      Aba(AppRoutes.reports, _tabs[4]),
      if (canOperateDonations(usuario))
        Aba(AppRoutes.opsDonations, _donationsTab),
    ];

/// Índice da aba da rota atual, ou -1 nas telas que não são abas (Configurações,
/// Alertas, Auditoria…). Aprovações de ajuste ficam em Configurações, não em Saída.
int indiceDaAba(String location, List<Aba> abas) {
  if (location.startsWith(AppRoutes.adjustmentApprovals)) return -1;
  for (var i = 0; i < abas.length; i++) {
    final r = abas[i].rota;
    if (location == r || location.startsWith('$r/')) return i;
  }
  return -1;
}

// ─── Animated Tab Bar ────────────────────────────────────────────────────────

class _AnimatedTabBar extends ConsumerWidget {
  final int selectedIndex;
  final List<Aba> abas;
  final ValueChanged<int> onTap;

  const _AnimatedTabBar({
    required this.selectedIndex,
    required this.abas,
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

    final temDoacoes = abas.any((a) => a.rota == AppRoutes.opsDonations);
    final pendingDonations =
        temDoacoes ? ref.watch(pendingDonationsCountProvider) : 0;

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
            children: List.generate(abas.length, (i) {
              final isDonations = abas[i].rota == AppRoutes.opsDonations;
              final showBadge = criticalCount > 0 && abas[i].mostraRisco;
              return Expanded(
                child: _TabItem(
                  tab: abas[i].def,
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
  final DefinicaoAba tab;
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
