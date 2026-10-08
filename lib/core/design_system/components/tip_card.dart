import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tokens/color_tokens.dart';
import '../tokens/typography_tokens.dart';

/// Global flag: when true, AppBars and TabBars should hide themselves so the
/// user can read the expanded TipCard without visual clutter.
final appTipsModeProvider = StateProvider.autoDispose<bool>((_) => false);

// ─── Data ────────────────────────────────────────────────────────────────────

class TipItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const TipItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}

// ─── Widget ───────────────────────────────────────────────────────────────────

/// Collapsible tip card widget. When expanded, hides AppBar/TabBar via
/// [appTipsModeProvider] so the user can read tips without visual clutter.
class TipCard extends ConsumerStatefulWidget {
  final List<TipItem> tips;
  final bool isDark;
  final ColorScheme cs;
  final String? title;

  const TipCard({
    super.key,
    required this.tips,
    required this.isDark,
    required this.cs,
    this.title,
  });

  @override
  ConsumerState<TipCard> createState() => _TipCardState();
}

class _TipCardState extends ConsumerState<TipCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    if (_expanded) {
      // reset global mode when widget is disposed while expanded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.context.mounted) {
          try {
            ref.read(appTipsModeProvider.notifier).state = false;
          } catch (_) {}
        }
      });
    }
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    ref.read(appTipsModeProvider.notifier).state = _expanded;
    if (_expanded) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final isDark = widget.isDark;
    const accentColor = AppColors.secondaryBlue600;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.09 : 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── Header row (always visible)
          InkWell(
            onTap: _toggle,
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _expanded
                          ? Icons.lightbulb_rounded
                          : Icons.lightbulb_outline_rounded,
                      key: ValueKey(_expanded),
                      size: 16,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _expanded
                            ? (widget.title ?? 'Dicas para esta tela')
                            : '${widget.tips.length} dicas — toque para expandir',
                        key: ValueKey(_expanded),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              _expanded ? FontWeight.w700 : FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  if (_expanded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded,
                              size: 12, color: accentColor),
                          const SizedBox(width: 3),
                          Text(
                            'Fechar',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: accentColor),
                          ),
                        ],
                      ),
                    )
                  else
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 16, color: accentColor),
                ],
              ),
            ),
          ),

          // ─── Expanded tips list
          ClipRect(
            child: SizeTransition(
              sizeFactor: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Divider(
                    height: 1,
                    color: accentColor.withValues(alpha: 0.18),
                  ),
                  ...widget.tips.asMap().entries.map((e) {
                    final tip = e.value;
                    final isLast = e.key == widget.tips.length - 1;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: tip.color.withValues(
                                      alpha: isDark ? 0.18 : 0.10),
                                  borderRadius:
                                      const BorderRadius.all(Radius.circular(8)),
                                ),
                                child: Icon(tip.icon,
                                    size: 15, color: tip.color),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tip.title,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      tip.body,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 11,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Divider(
                            height: 1,
                            indent: 14,
                            endIndent: 14,
                            color:
                                accentColor.withValues(alpha: 0.10),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
