import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../controllers/locations_provider.dart';

class LocationCreatePage extends ConsumerStatefulWidget {
  const LocationCreatePage({super.key});

  @override
  ConsumerState<LocationCreatePage> createState() => _LocationCreatePageState();
}

class _LocationCreatePageState extends ConsumerState<LocationCreatePage> {
  final _shelfController = TextEditingController();
  final _capacityController = TextEditingController(text: '50');
  int _levels = 3;

  @override
  void dispose() {
    _shelfController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final shelf = _shelfController.text.trim();
    if (shelf.isEmpty) {
      showCasaSnackbar(context,
          message: 'Informe o nome da prateleira.', isError: true);
      return;
    }
    final created = await ref
        .read(locationsNotifierProvider.notifier)
        .createShelfWithLevels(
          shelf: shelf,
          levels: _levels,
          capacityPerLevel: int.tryParse(_capacityController.text.trim()),
        );

    if (!mounted) return;
    final state = ref.read(locationsNotifierProvider);
    state.whenOrNull(
      data: (_) {
        showCasaSnackbar(
          context,
          message: created > 0
              ? 'Prateleira "$shelf" criada com $created nível${created == 1 ? '' : 'eis'}!'
              : 'Esses níveis já existiam para "$shelf".',
          isSuccess: created > 0,
        );
        if (created > 0) context.pop();
      },
      error: (e, _) => showCasaSnackbar(context,
          message: 'Erro ao criar: $e', isError: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formState = ref.watch(locationsNotifierProvider);
    final isLoading = formState is AsyncLoading;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(
        children: [
          ModernProfileAppBar(
            title: 'Nova Prateleira',
            subtitle: 'Crie a prateleira e seus níveis',
            pageIcon: Icons.add_location_alt_rounded,
            iconColor: const Color(0xFF38BDF8),
            showBackButton: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // ── 1. Nome da prateleira ──
                _Section(
                  icon: Icons.shelves,
                  iconColor: AppColors.brandPrimary600,
                  title: 'Prateleira',
                  cs: cs,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Identifique a prateleira (letra ou nome).',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _shelfController,
                        textCapitalization: TextCapitalization.characters,
                        style: AppTypography.productName(
                          size: 18,
                          weight: FontWeight.w800,
                          color: cs.onSurface,
                          letterSpacing: 0,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ex: A, B, Geladeira 1',
                          prefixIcon: const Icon(Icons.shelves,
                              color: AppColors.brandPrimary600),
                          filled: true,
                          fillColor: cs.surfaceContainer,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.input),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      // Atalhos de letra
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ['A', 'B', 'C', 'D', 'E', 'F'].map((l) {
                          final sel =
                              _shelfController.text.trim().toUpperCase() == l;
                          return GestureDetector(
                            onTap: () => setState(
                                () => _shelfController.text = l),
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.brandPrimary600
                                    : AppColors.brandPrimary600
                                        .withValues(alpha: isDark ? 0.16 : 0.08),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: AppColors.brandPrimary600.withValues(
                                      alpha: sel ? 1 : 0.25),
                                ),
                              ),
                              child: Text(
                                l,
                                style: AppTypography.productName(
                                  size: 16,
                                  weight: FontWeight.w900,
                                  color: sel
                                      ? Colors.white
                                      : AppColors.brandPrimary600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── 2. Quantos níveis ──
                _Section(
                  icon: Icons.layers_rounded,
                  iconColor: AppColors.secondaryBlue600,
                  title: 'Quantos níveis?',
                  cs: cs,
                  child: Column(
                    children: [
                      Text(
                        'A prateleira terá esta quantidade de níveis '
                        '(criados automaticamente: 1, 2, 3…).',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          _BigBtn(
                            icon: Icons.remove_rounded,
                            color: AppColors.secondaryBlue600,
                            isDark: isDark,
                            onTap: _levels > 1
                                ? () => setState(() => _levels--)
                                : null,
                          ),
                          Expanded(
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (c, a) =>
                                    ScaleTransition(scale: a, child: c),
                                child: Column(
                                  key: ValueKey(_levels),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_levels',
                                      style: AppTypography.productName(
                                        size: 38,
                                        weight: FontWeight.w900,
                                        color: cs.onSurface,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    Text(
                                      _levels == 1 ? 'nível' : 'níveis',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          _BigBtn(
                            icon: Icons.add_rounded,
                            color: AppColors.secondaryBlue600,
                            isDark: isDark,
                            onTap: _levels < 30
                                ? () => setState(() => _levels++)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          for (final n in [3, 5, 8, 10])
                            Expanded(
                              child: Padding(
                                padding:
                                    EdgeInsets.only(right: n == 10 ? 0 : 6),
                                child: GestureDetector(
                                  onTap: () => setState(() => _levels = n),
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryBlue600
                                          .withValues(
                                              alpha: isDark ? 0.18 : 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.secondaryBlue600
                                            .withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Text(
                                      '$n',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.productName(
                                        size: 14,
                                        weight: FontWeight.w800,
                                        color: AppColors.secondaryBlue600,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── 3. Capacidade ──
                _Section(
                  icon: Icons.inventory_2_rounded,
                  iconColor: AppColors.warning600,
                  title: 'Capacidade por nível',
                  cs: cs,
                  child: TextField(
                    controller: _capacityController,
                    keyboardType: TextInputType.number,
                    style: AppTypography.productName(
                      size: 16,
                      weight: FontWeight.w700,
                      color: cs.onSurface,
                      letterSpacing: 0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ex: 50 itens por nível',
                      prefixIcon: const Icon(Icons.inventory_2_outlined,
                          color: AppColors.warning600),
                      filled: true,
                      fillColor: cs.surfaceContainer,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Preview ──
                _PreviewCard(
                  shelf: _shelfController.text.trim().isEmpty
                      ? '—'
                      : _shelfController.text.trim().toUpperCase(),
                  levels: _levels,
                  isDark: isDark,
                  cs: cs,
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isLoading
          ? const FloatingActionButton(
              onPressed: null,
              backgroundColor: AppColors.brandPrimary600,
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
            )
          : FloatingActionButton.extended(
              onPressed: _save,
              backgroundColor: AppColors.brandPrimary600,
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              label: Text(
                'Criar prateleira',
                style: AppTypography.productName(
                  size: 14,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

// ─── Seção card reutilizável ─────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final ColorScheme cs;
  final Widget child;
  const _Section({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.cs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.30 : 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor,
                      Color.lerp(iconColor, Colors.black, 0.18)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.40),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.productName(
                    size: 16,
                    weight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _BigBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;
  const _BigBtn({
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: color.withValues(
          alpha: enabled ? (isDark ? 0.22 : 0.12) : (isDark ? 0.08 : 0.05)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 56,
          height: 50,
          alignment: Alignment.center,
          child: Icon(icon,
              size: 26,
              color:
                  enabled ? color : color.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String shelf;
  final int levels;
  final bool isDark;
  final ColorScheme cs;
  const _PreviewCard({
    required this.shelf,
    required this.levels,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brandPrimary600.withValues(alpha: isDark ? 0.18 : 0.08),
            AppColors.secondaryBlue600.withValues(alpha: isDark ? 0.10 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: AppColors.brandPrimary600
                .withValues(alpha: isDark ? 0.35 : 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview_rounded,
                  size: 16, color: AppColors.brandPrimary600),
              const SizedBox(width: 6),
              Text(
                'Pré-visualização',
                style: AppTypography.productName(
                  size: 13,
                  weight: FontWeight.w800,
                  color: AppColors.brandPrimary600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(levels, (i) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.brandPrimary600
                          .withValues(alpha: 0.25)),
                ),
                child: Text(
                  'Prat. $shelf · Nível ${i + 1}',
                  style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
