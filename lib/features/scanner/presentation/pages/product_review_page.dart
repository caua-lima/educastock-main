import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../data/datasources/open_food_facts_datasource.dart';
import '../controllers/scanner_provider.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../ml/presentation/widgets/risk_widgets.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';

class ProductReviewPage extends ConsumerStatefulWidget {
  final String barcode;
  const ProductReviewPage({super.key, required this.barcode});

  @override
  ConsumerState<ProductReviewPage> createState() => _ProductReviewPageState();
}

class _ProductReviewPageState extends ConsumerState<ProductReviewPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Invalida o cache do provider antes de assistir para garantir busca
      // fresca toda vez que a página abre. autoDispose descarta quando sai
      // da tela, mas há uma janela de tempo onde o disposal ainda não ocorreu
      // e o resultado null (de uma scan anterior) seria retornado do cache.
      ref.invalidate(productByBarcodeProvider(widget.barcode));
      ref.read(scannerProvider.notifier).onBarcodeDetected(widget.barcode);
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scanState = ref.watch(scannerProvider);
    final localProductAsync =
        ref.watch(productByBarcodeProvider(widget.barcode));
    final user = ref.watch(currentUserProvider);
    final alertCount = ref.watch(allAvailableBatchesProvider).when(
          data: (list) => list
              .where((b) =>
                  !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30))
              .length,
          loading: () => 0,
          error: (_, __) => 0,
        );
    final initial = (user?.name ?? '').trim().isEmpty
        ? 'U'
        : user!.name.trim().substring(0, 1).toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: cs.surface,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── SliverAppBar com gradiente ──────────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              stretch: true,
              backgroundColor: AppColors.brandPrimary800,
              surfaceTintColor: Colors.transparent,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => context.pop(),
                ),
              ),
              actions: [
                buildHelpButton(
                  context: context,
                  onPressed: () => _showHelp(context),
                ),
                CasaAlertsBellButton(
                  alertCount: alertCount,
                  onDarkBg: true,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.xs),
                  child: CasaThemeToggleButton(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs),
                  child: GestureDetector(
                    onTap: () => context.push(AppRoutes.settings),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 3.5,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Revisão do Produto',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.3,
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: FadeTransition(
                  opacity: _heroFade,
                  child: _HeroSection(barcode: widget.barcode),
                ),
              ),
            ),

            // ── Conteúdo ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 80),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Seção 1: Status do banco local
                  _DbStatusSection(
                    localProductAsync: localProductAsync,
                    barcode: widget.barcode,
                    cs: cs,
                    isDark: isDark,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Seção 2: Pesquisa na web (só quando produto não está no banco)
                  localProductAsync.when(
                    loading: () => _WebSearchSection(
                      scanState: scanState,
                      barcode: widget.barcode,
                      cs: cs,
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (product) => product == null
                        ? _WebSearchSection(
                            scanState: scanState,
                            barcode: widget.barcode,
                            cs: cs,
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Seção 3: Lotes (só quando produto encontrado no banco)
                  localProductAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (product) => product != null
                        ? _BatchesSection(
                            product: product,
                            cs: cs,
                            isDark: isDark,
                          )
                        : const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Como funciona?',
                  style: AppTypography.headingSmall
                      .copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSpacing.lg),
              _HelpItem(
                icon: Icons.check_circle_rounded,
                color: AppColors.success600,
                title: 'Produto cadastrado',
                desc:
                    'Adicione unidades a um lote existente ou crie um novo lote.',
              ),
              const SizedBox(height: AppSpacing.md),
              _HelpItem(
                icon: Icons.travel_explore_rounded,
                color: AppColors.brandPrimary600,
                title: 'Pesquisa na web',
                desc:
                    'Consultamos 3 bases de dados online em sequência. Cada etapa é exibida na barra de progresso.',
              ),
              const SizedBox(height: AppSpacing.md),
              _HelpItem(
                icon: Icons.add_box_rounded,
                color: AppColors.warning600,
                title: 'Produto novo',
                desc:
                    'Cadastre manualmente ou use o OCR para ler o nome da embalagem com a câmera.',
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary600,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button)),
                  ),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Hero com código de barras ─────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final String barcode;
  const _HeroSection({required this.barcode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F2444),
            Color(0xFF1A3A6B),
            Color(0xFF1D5FA8),
            Color(0xFF38BDF8),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // ── Círculos decorativos de fundo com glow ──
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -30,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF38BDF8).withValues(alpha: 0.20),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          // ── Linha de grid decorativa (efeito "scanner") ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ScanGridPainter(),
              ),
            ),
          ),
          // ── Conteúdo central ──
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge com ícone scanner pulsante
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF38BDF8).withValues(alpha: 0.30),
                        const Color(0xFF1D5FA8).withValues(alpha: 0.20),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded,
                          color: Color(0xFF7DD3FC), size: 13),
                      const SizedBox(width: 6),
                      Text(
                        'Código escaneado',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Container do barcode com glow
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.18),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    barcode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(
                          color: Color(0x88000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinta uma grade fina decorativa para efeito "scanner futurista"
class _ScanGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanGridPainter old) => false;
}

// ─── Seção: status do banco local ─────────────────────────────────────────

class _DbStatusSection extends StatelessWidget {
  final AsyncValue<Product?> localProductAsync;
  final String barcode;
  final ColorScheme cs;
  final bool isDark;

  const _DbStatusSection({
    required this.localProductAsync,
    required this.barcode,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return localProductAsync.when(
      loading: () => _DbSkeleton(cs: cs),
      error: (e, _) => _DbErrorCard(
        cs: cs,
        onManual: () => context
            .push('${AppRoutes.productForm}?barcode=$barcode'),
      ),
      data: (product) => product != null
          ? _ProductFoundCard(product: product, cs: cs, isDark: isDark)
          : _NewProductBadge(cs: cs),
    );
  }
}

// ─── Skeleton enquanto verifica o banco ───────────────────────────────────

class _DbSkeleton extends StatefulWidget {
  final ColorScheme cs;
  const _DbSkeleton({required this.cs});

  @override
  State<_DbSkeleton> createState() => _DbSkeletonState();
}

class _DbSkeletonState extends State<_DbSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.3 + _anim.value * 0.35;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: widget.cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card + 4),
            border: Border.all(
                color: widget.cs.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.cs.surfaceContainer.withOpacity(opacity),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color:
                            widget.cs.surfaceContainer.withOpacity(opacity),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 140,
                      decoration: BoxDecoration(
                        color:
                            widget.cs.surfaceContainer.withOpacity(opacity),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      _SkeletonPill(
                          width: 64,
                          cs: widget.cs,
                          opacity: opacity),
                      const SizedBox(width: 6),
                      _SkeletonPill(
                          width: 48,
                          cs: widget.cs,
                          opacity: opacity),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonPill extends StatelessWidget {
  final double width;
  final ColorScheme cs;
  final double opacity;
  const _SkeletonPill(
      {required this.width, required this.cs, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: width,
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withOpacity(opacity),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

// ─── Card: produto encontrado no banco ────────────────────────────────────

class _ProductFoundCard extends StatelessWidget {
  final Product product;
  final ColorScheme cs;
  final bool isDark;
  const _ProductFoundCard(
      {required this.product, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.success600.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        border: Border.all(color: AppColors.success600.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Banner superior
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.success600,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card + 4),
                topRight: Radius.circular(AppRadius.card + 4),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 13),
                SizedBox(width: 6),
                Text(
                  'Produto já cadastrado no sistema',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // Informações do produto
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem / ícone
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.success600.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                        color: AppColors.success600.withOpacity(0.2)),
                  ),
                  child: product.imageUrl != null &&
                          product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Image.network(product.imageUrl!,
                              fit: BoxFit.cover),
                        )
                      : const Icon(Icons.inventory_2_rounded,
                          color: AppColors.success600, size: 28),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTypography.headingSmall.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w800),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((product.brand ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            product.brand!,
                            style: AppTypography.bodySmall
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Tag(product.category.name,
                              color: AppColors.brandPrimary600),
                          _Tag(product.unit,
                              icon: Icons.straighten_rounded,
                              color: cs.onSurfaceVariant),
                          if (product.isPerishable)
                            _Tag('Perecível',
                                icon: Icons.schedule_rounded,
                                color: AppColors.warning600),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Botão editar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.push('${AppRoutes.productForm}?id=${product.id}'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Editar informações do produto'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge: produto novo (não está no banco) ──────────────────────────────

class _NewProductBadge extends StatelessWidget {
  final ColorScheme cs;
  const _NewProductBadge({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning600.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        border: Border.all(color: AppColors.warning600.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.warning600.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.new_label_rounded,
                color: AppColors.warning600, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Produto não cadastrado',
                    style: AppTypography.labelMedium.copyWith(
                        color: AppColors.warning600,
                        fontWeight: FontWeight.w700)),
                Text('Pesquisando dados na internet...',
                    style: AppTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card: erro ao verificar banco ───────────────────────────────────────

class _DbErrorCard extends StatelessWidget {
  final ColorScheme cs;
  final VoidCallback onManual;
  const _DbErrorCard({required this.cs, required this.onManual});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger600.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        border: Border.all(color: AppColors.danger600.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.danger600.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded,
                color: AppColors.danger600, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Erro ao verificar banco local',
                    style: AppTypography.labelMedium.copyWith(
                        color: AppColors.danger600,
                        fontWeight: FontWeight.w700)),
                Text('Verifique sua conexão com a internet',
                    style: AppTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(
            onPressed: onManual,
            child: const Text('Manual',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Seção: pesquisa na web com barra de progresso ────────────────────────

class _WebSearchSection extends StatelessWidget {
  final ScannerState scanState;
  final String barcode;
  final ColorScheme cs;

  const _WebSearchSection({
    required this.scanState,
    required this.barcode,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da seção
        Row(
          children: [
            const Icon(Icons.travel_explore_rounded,
                size: 16, color: AppColors.brandPrimary600),
            const SizedBox(width: 6),
            Text('Pesquisa na Internet',
                style: AppTypography.labelMedium.copyWith(
                    color: AppColors.brandPrimary600,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Card principal
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card + 4),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Barra de progresso (visível enquanto pesquisa)
              if (scanState.searchStep != WebSearchStep.done)
                _ProgressBar(step: scanState.searchStep, cs: cs),

              // Conteúdo conforme estado
              scanState.apiResult.when(
                loading: () =>
                    _SearchingBody(step: scanState.searchStep, cs: cs),
                error: (_, __) =>
                    _WebErrorBody(barcode: barcode, cs: cs),
                data: (result) {
                  if (result == null) {
                    return _SearchingBody(step: scanState.searchStep, cs: cs);
                  }
                  if (!result.found) {
                    return _NotFoundBody(barcode: barcode, cs: cs);
                  }
                  return _FoundBody(result: result, barcode: barcode, cs: cs);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Barra de progresso animada ────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final WebSearchStep step;
  final ColorScheme cs;
  const _ProgressBar({required this.step, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary600.withOpacity(0.06),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.card + 4),
          topRight: Radius.circular(AppRadius.card + 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label atual
          Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.brandPrimary600),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Consultando ${step.label}...',
                  style: AppTypography.labelSmall.copyWith(
                      color: AppColors.brandPrimary600,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Barra de progresso animada
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.05, end: step.progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 7,
                backgroundColor: AppColors.brandPrimary600.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.brandPrimary600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Etapas com bolinhas
          Row(
            children: [
              _StepDot(
                label: 'OpenFood',
                done:
                    step.index > WebSearchStep.openFoodFacts.index,
                active: step == WebSearchStep.openFoodFacts,
                cs: cs,
              ),
              Expanded(
                child: Container(
                  height: 1.5,
                  color: step.index > WebSearchStep.openFoodFacts.index
                      ? AppColors.brandPrimary600
                      : cs.outlineVariant,
                ),
              ),
              _StepDot(
                label: 'UPC DB',
                done: step.index > WebSearchStep.upcItemDb.index,
                active: step == WebSearchStep.upcItemDb,
                cs: cs,
              ),
              Expanded(
                child: Container(
                  height: 1.5,
                  color: step.index > WebSearchStep.upcItemDb.index
                      ? AppColors.brandPrimary600
                      : cs.outlineVariant,
                ),
              ),
              _StepDot(
                label: 'Barcode',
                done: step == WebSearchStep.done,
                active: step == WebSearchStep.barcodeLookup,
                cs: cs,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;
  final ColorScheme cs;
  const _StepDot(
      {required this.label,
      required this.done,
      required this.active,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final color =
        done || active ? AppColors.brandPrimary600 : cs.outlineVariant;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.brandPrimary600
                : active
                    ? Colors.white
                    : cs.surfaceContainerLow,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            color: color,
            fontWeight:
                done || active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Corpo: pesquisando ─────────────────────────────────────────────────────

class _SearchingBody extends StatelessWidget {
  final WebSearchStep step;
  final ColorScheme cs;
  const _SearchingBody({required this.step, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Text(
            'Buscando informações do produto...',
            style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurface, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Aguarde, consultando ${step.label}',
            style: AppTypography.bodySmall
                .copyWith(color: cs.onSurfaceVariant, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Corpo: produto encontrado na web ──────────────────────────────────────

class _FoundBody extends StatelessWidget {
  final ProductApiResult result;
  final String barcode;
  final ColorScheme cs;
  const _FoundBody(
      {required this.result, required this.barcode, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner sucesso
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.success600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_done_rounded,
                    color: AppColors.success600, size: 15),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Produto identificado na internet!',
                    style: TextStyle(
                        color: AppColors.success600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Card do produto
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.success600.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                      color: AppColors.success600.withOpacity(0.2)),
                ),
                child: result.imageUrl != null &&
                        result.imageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Image.network(
                          result.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.success600,
                              size: 28),
                        ),
                      )
                    : const Icon(Icons.inventory_2_outlined,
                        color: AppColors.success600, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((result.name ?? '').isNotEmpty)
                      Text(
                        result.name!,
                        style: AppTypography.labelLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if ((result.brand ?? '').isNotEmpty)
                      Text(result.brand!,
                          style: AppTypography.bodySmall
                              .copyWith(color: cs.onSurfaceVariant)),
                    if ((result.category ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _Tag(result.category!,
                            color: AppColors.brandPrimary600),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Aviso de verificação
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warning600.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.warning600, size: 13),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Confira nome e categoria antes de confirmar.',
                    style: TextStyle(color: AppColors.warning600, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Botão confirmar
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                final (unit, unitSize) =
                    _extractUnitFromName(result.name ?? '');
                final isPerishable = _inferIsPerishable(result.category);
                context.push(
                  '${AppRoutes.productForm}?barcode=$barcode'
                  '&name=${Uri.encodeComponent(result.name ?? '')}'
                  '&brand=${Uri.encodeComponent(result.brand ?? '')}'
                  '&category=${result.category ?? ''}'
                  '&imageUrl=${Uri.encodeComponent(result.imageUrl ?? '')}'
                  '&isPerishable=$isPerishable'
                  '&unit=$unit'
                  '&unitSize=$unitSize'
                  '&desc=${Uri.encodeComponent(result.description ?? '')}',
                );
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Confirmar e cadastrar produto'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context
                  .push('${AppRoutes.productForm}?barcode=$barcode'),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Ignorar e cadastrar manualmente'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corpo: produto não encontrado na web ──────────────────────────────────

class _NotFoundBody extends StatefulWidget {
  final String barcode;
  final ColorScheme cs;
  const _NotFoundBody({required this.barcode, required this.cs});

  @override
  State<_NotFoundBody> createState() => _NotFoundBodyState();
}

class _NotFoundBodyState extends State<_NotFoundBody> {
  final _imagePicker = ImagePicker();
  bool _isOcrLoading = false;

  Future<void> _scanPackagingWithOcr() async {
    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    if (file == null) return;

    setState(() => _isOcrLoading = true);
    String? productName;
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final result = await recognizer.processImage(inputImage);
        productName = _tryExtractProductName(result.text);
      } finally {
        await recognizer.close();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isOcrLoading = false);
    }

    if (!mounted) return;
    final uri = Uri(
      path: AppRoutes.productForm,
      queryParameters: {
        'barcode': widget.barcode,
        if (productName != null) 'name': productName,
      },
    );
    context.push(uri.toString());
  }

  String? _tryExtractProductName(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.length >= 3 && e.length <= 50)
        .toList();
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('lote') ||
          lower.contains('valid') ||
          lower.contains('ingrediente') ||
          RegExp(r'\d{2}[\/\-]\d{2}[\/\-]\d{2,4}').hasMatch(lower)) {
        continue;
      }
      if (RegExp(r'[a-zA-Z]{3,}').hasMatch(line)) return line;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Badge de não encontrado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: widget.cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Row(
              children: [
                Icon(Icons.search_off_rounded,
                    size: 15, color: widget.cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Não encontrado em nenhuma base de dados',
                    style: TextStyle(
                        color: widget.cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Botão OCR
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isOcrLoading ? null : _scanPackagingWithOcr,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                side: const BorderSide(color: AppColors.brandPrimary600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              icon: _isOcrLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandPrimary600))
                  : const Icon(Icons.document_scanner_outlined,
                      size: 17, color: AppColors.brandPrimary600),
              label: Text(
                _isOcrLoading
                    ? 'Lendo embalagem...'
                    : 'Ler embalagem com câmera (OCR)',
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.brandPrimary600),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Botão cadastro manual
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(
                  '${AppRoutes.productForm}?barcode=${widget.barcode}'),
              icon: const Icon(Icons.inventory_2_outlined, size: 16),
              label: const Text('Cadastrar produto manualmente'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corpo: sem internet ───────────────────────────────────────────────────

class _WebErrorBody extends StatelessWidget {
  final String barcode;
  final ColorScheme cs;
  const _WebErrorBody({required this.barcode, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.warning600, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text('Sem conexão com a internet',
              style: AppTypography.labelMedium.copyWith(
                  color: cs.onSurface, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text('Cadastre o produto manualmente.',
              style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context
                  .push('${AppRoutes.productForm}?barcode=$barcode'),
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Cadastrar manualmente'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Seção de lotes ───────────────────────────────────────────────────────

class _BatchesSection extends ConsumerWidget {
  final Product product;
  final ColorScheme cs;
  final bool isDark;

  const _BatchesSection({
    required this.product,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(batchesByProductProvider(product.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da seção
        Row(
          children: [
            const Icon(Icons.layers_rounded,
                size: 16, color: AppColors.brandPrimary600),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Lotes em estoque',
                  style: AppTypography.labelMedium.copyWith(
                      color: AppColors.brandPrimary600,
                      fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: () => context.push(
                  '${AppRoutes.batchForm}?productId=${product.id}'),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Novo lote',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brandPrimary600,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        batchesAsync.when(
          loading: () => const CasaCardSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (batches) {
            if (batches.isEmpty) {
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius:
                          BorderRadius.circular(AppRadius.card + 4),
                      border: Border.all(
                          color: cs.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 36, color: cs.onSurfaceVariant),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Nenhum lote cadastrado',
                            style: AppTypography.labelMedium
                                .copyWith(color: cs.onSurface)),
                        const SizedBox(height: 4),
                        Text(
                          'Cadastre o primeiro lote para este produto.',
                          style: AppTypography.bodySmall
                              .copyWith(color: cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                          '${AppRoutes.batchForm}?productId=${product.id}'),
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text('Cadastrar primeiro lote'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary600,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button)),
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                ...batches.map((b) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ExistingBatchCard(
                        batch: b,
                        cs: cs,
                        isDark: isDark,
                        productName: product.name,
                      ),
                    )),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                        '${AppRoutes.batchForm}?productId=${product.id}'),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Adicionar Novo Lote'),
                    style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ─── Card de lote existente ───────────────────────────────────────────────

class _ExistingBatchCard extends ConsumerStatefulWidget {
  final Batch batch;
  final String productName;
  final ColorScheme cs;
  final bool isDark;

  const _ExistingBatchCard({
    required this.batch,
    required this.productName,
    required this.cs,
    required this.isDark,
  });

  @override
  ConsumerState<_ExistingBatchCard> createState() =>
      _ExistingBatchCardState();
}

class _ExistingBatchCardState extends ConsumerState<_ExistingBatchCard> {
  Color _statusColor() {
    final b = widget.batch;
    if (b.noExpiry) return AppColors.success600;
    if (b.isExpired) return AppColors.danger600;
    final d = b.daysToExpiry;
    if (d <= 7) return AppColors.danger600;
    if (d <= 30) return AppColors.warning600;
    return AppColors.success600;
  }

  String _statusLabel() {
    final b = widget.batch;
    if (b.noExpiry) return 'Sem validade';
    if (b.isExpired) return 'Vencido';
    final d = b.daysToExpiry;
    if (d <= 7) return 'Crítico';
    if (d <= 30) return 'Atenção';
    return 'OK';
  }

  void _showAddQtySheet() {
    int amount = 1;
    final ctrl = TextEditingController(text: '1');
    final cs = widget.cs;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
                Text('Adicionar ao lote',
                    style: AppTypography.headingSmall.copyWith(
                        color: cs.onSurface, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.batch.batchNumber != null
                      ? 'Lote ${widget.batch.batchNumber} · ${widget.batch.quantity} unidades'
                      : '${widget.batch.quantity} unidades em estoque',
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: () {
                        if (amount > 1) {
                          setModal(() => amount--);
                          ctrl.text = '$amount';
                        }
                      },
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: ctrl,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        style: AppTypography.headingMedium.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                  AppRadius.input)),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) setModal(() => amount = n);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () {
                        setModal(() => amount++);
                        ctrl.text = '$amount';
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Preview ML — risco projetado após adicionar as unidades
                RiskPreviewBanner(
                  expiryDate: widget.batch.expiryDate,
                  noExpiry: widget.batch.noExpiry,
                  quantity: widget.batch.quantity + amount,
                  entryDate: widget.batch.entryDate,
                ),
                const SizedBox(height: AppSpacing.md),
                Consumer(
                  builder: (ctx, cref, _) {
                    final addState = cref.watch(addBatchQuantityProvider);
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: addState.isLoading
                            ? null
                            : () async {
                                await cref
                                    .read(addBatchQuantityProvider.notifier)
                                    .addUnits(widget.batch, amount);
                                if (ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  showCasaSnackbar(
                                    ctx,
                                    message:
                                        '$amount unidade${amount == 1 ? '' : 's'} adicionada${amount == 1 ? '' : 's'}!',
                                    isSuccess: true,
                                  );
                                }
                              },
                        icon: addState.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add_rounded),
                        label: Text(
                            'Adicionar $amount unidade${amount == 1 ? '' : 's'}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary600,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppRadius.button)),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final statusColor = _statusColor();
    final b = widget.batch;

    return Container(
      decoration: BoxDecoration(
        color: widget.cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card + 2),
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
          top: BorderSide(
              color: widget.cs.outlineVariant.withOpacity(0.25)),
          right: BorderSide(
              color: widget.cs.outlineVariant.withOpacity(0.25)),
          bottom: BorderSide(
              color: widget.cs.outlineVariant.withOpacity(0.25)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(Icons.inventory_2_outlined,
                color: statusColor, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                            color: statusColor.withOpacity(0.25)),
                      ),
                      child: Text(_statusLabel(),
                          style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w700)),
                    ),
                    if ((b.batchNumber ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('# ${b.batchNumber}',
                          style: AppTypography.labelSmall.copyWith(
                              color: widget.cs.onSurfaceVariant,
                              fontSize: 11)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.widgets_outlined,
                        size: 13, color: AppColors.brandPrimary600),
                    const SizedBox(width: 4),
                    Text('${b.quantity} unidades',
                        style: AppTypography.labelMedium.copyWith(
                            color: widget.cs.onSurface,
                            fontWeight: FontWeight.w700)),
                    if (!b.noExpiry && b.expiryDate != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(Icons.event_rounded, size: 12, color: statusColor),
                      const SizedBox(width: 3),
                      Text(fmt.format(b.expiryDate!),
                          style: AppTypography.bodySmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 11)),
                    ],
                    if (b.noExpiry) ...[
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.all_inclusive_rounded,
                          size: 12, color: AppColors.success600),
                      const SizedBox(width: 3),
                      Text('Sem validade',
                          style: AppTypography.bodySmall.copyWith(
                              color: AppColors.success600, fontSize: 11)),
                    ],
                  ],
                ),
                if ((b.shelfLocation ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded,
                            size: 11,
                            color: widget.cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(b.shelfLocation!,
                            style: AppTypography.bodySmall.copyWith(
                                color: widget.cs.onSurfaceVariant,
                                fontSize: 10)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showAddQtySheet,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.button),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary600.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Adicionar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Tag(this.label, {required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _HelpItem(
      {required this.icon,
      required this.color,
      required this.title,
      required this.desc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.labelMedium
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(desc,
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.button),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Icon(icon, color: cs.onSurface, size: 20),
      ),
    );
  }
}

// ─── Helpers de inferência ────────────────────────────────────────────────

bool _inferIsPerishable(String? category) {
  const nonPerishable = {'limpeza', 'higienePessoal', 'escolar', 'outros'};
  return !nonPerishable.contains(category);
}

(String, String) _extractUnitFromName(String name) {
  final patterns = <(RegExp, String)>[
    (RegExp(r'(\d+(?:[.,]\d+)?)\s*mL', caseSensitive: false), 'mL'),
    (RegExp(r'(\d+(?:[.,]\d+)?)\s*L\b'), 'L'),
    (RegExp(r'(\d+(?:[.,]\d+)?)\s*kg', caseSensitive: false), 'kg'),
    (RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b'), 'g'),
  ];
  for (final (pattern, unit) in patterns) {
    final m = pattern.firstMatch(name);
    if (m != null) return (unit, m.group(1)!);
  }
  return ('un', '');
}
