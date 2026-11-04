import 'package:flutter/material.dart';

/// Faixa colorida na lateral esquerda de um cartão com cantos arredondados.
///
/// O Flutter não desenha `Border` com cores diferentes por lado junto com `borderRadius`
/// (em debug dá erro; em release os cantos saem quadrados). O cartão usa uma borda
/// uniforme e esta faixa é sobreposta à esquerda, com os mesmos cantos arredondados.
class AccentStripe extends StatelessWidget {
  final Color color;
  final double width;
  final double radius;
  final Widget child;

  const AccentStripe({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
    this.width = 3,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: width,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(radius)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
