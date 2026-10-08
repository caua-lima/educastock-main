import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Botão "Continuar com Google" estilo Material 3 com o logo G colorido
/// renderizado via CustomPaint — sem dependência de assets externos.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continuar com Google',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final borderColor =
        isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: bg,
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: isLoading
                  ? null
                  : [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.30 : 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: textColor,
                    ),
                  )
                else
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CustomPaint(painter: _GoogleGPainter()),
                  ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinta o logo G do Google com 4 setores coloridos + barra horizontal central.
/// Aproximação fiel ao guideline oficial (azul/vermelho/amarelo/verde).
class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final cy = size.height / 2;
    final r = w / 2;
    final stroke = w * 0.20;
    final arcRect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: r - stroke / 2,
    );

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Arcos (ângulos em radianos; 0 = direita, π/2 = baixo)
    // Vermelho: topo-direito até topo-esquerdo (~12h até 9h)
    canvas.drawArc(arcRect, math.pi * -0.5 - math.pi * 0.20,
        math.pi * 0.70, false, p..color = _red);
    // Amarelo: topo-esquerdo até inferior-esquerdo (~9h até 6h)
    canvas.drawArc(arcRect, math.pi * 1.0, math.pi * 0.45, false,
        p..color = _yellow);
    // Verde: inferior-esquerdo até inferior-direito (~6h até 4h)
    canvas.drawArc(arcRect, math.pi * 1.45, math.pi * 0.50, false,
        p..color = _green);
    // Azul: inferior-direito até barra horizontal (~4h até 3h)
    canvas.drawArc(arcRect, math.pi * 1.95, math.pi * 0.25, false,
        p..color = _blue);

    // Barra horizontal azul (do centro até a borda direita)
    final bar = Rect.fromLTWH(
      cx - 1,
      cy - stroke * 0.5,
      r,
      stroke,
    );
    canvas.drawRect(bar, Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(_GoogleGPainter old) => false;
}
