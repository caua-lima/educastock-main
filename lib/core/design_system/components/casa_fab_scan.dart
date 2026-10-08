import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/color_tokens.dart';
import '../tokens/typography_tokens.dart';

/// FAB de scanner modernizado:
///  - Gradient azul brand
///  - Pulse animation no ícone (sutil)
///  - Borda interna clara para depth
///  - Sombra colorida para destacar
class CasaFabScan extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const CasaFabScan({
    super.key,
    required this.onPressed,
    this.label = 'Escanear',
  });

  @override
  State<CasaFabScan> createState() => _CasaFabScanState();
}

class _CasaFabScanState extends State<CasaFabScan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A56C4), Color(0xFF2F74D0), Color(0xFF1D5FA8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPrimary600.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) {
                final scale = 1.0 + (_pulse.value * 0.08);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: AppTypography.productName(
                size: 14,
                weight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
