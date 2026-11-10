// Logo oficial animado del splash (skill easybus-motion):
//   1. Entrada: crece de 0.9 a 1 (400 ms, easeOutCubic). Arranca al 90 % porque así
//      lo muestra el splash nativo: el paso entre los dos no se nota.
//   2. Mientras carga: un pulso leve (escala 1 → 1.03 y opacidad 1 → 0.9) en ciclos
//      de 1.8 s. Menos de un ciclo por segundo: nada de parpadeos.
// Con "reducir movimiento": sin escalas ni bucles; solo un fade corto.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eb_tokens.dart';

class EbAnimatedLogo extends StatefulWidget {
  const EbAnimatedLogo({super.key, this.size = EbAnimatedLogo.splashSize});

  /// Tamaño final del logo en el splash.
  static const splashSize = 160.0;

  /// Escala inicial: la misma con que lo muestra el splash nativo (144 dp).
  static const startScale = 0.9;

  static const asset = 'assets/images/easybus_logo.png';

  final double size;

  @override
  State<EbAnimatedLogo> createState() => _EbAnimatedLogoState();
}

class _EbAnimatedLogoState extends State<EbAnimatedLogo> with TickerProviderStateMixin {
  static const _pulseCycle = Duration(milliseconds: 1800);

  late final AnimationController _enter = AnimationController(vsync: this, duration: EbDurations.slow);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: _pulseCycle);
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _enter.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_reduceMotion) _pulse.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _pulse.stop();
    if (!_enter.isAnimating && !_enter.isCompleted) {
      _enter.duration = _reduceMotion ? EbDurations.fast : EbDurations.slow;
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(parent: _enter, curve: EbCurves.enter);
    final logo = Image.asset(
      EbAnimatedLogo.asset,
      width: widget.size,
      height: widget.size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'EASYBUS',
    );

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _pulse]),
        builder: (context, child) {
          if (_reduceMotion) {
            // Sin movimiento: aparece con un fade corto.
            return Opacity(opacity: enter.value, child: child);
          }
          // Onda suave de 0 a 1 y de vuelta a 0 en cada ciclo.
          final wave = (1 - math.cos(2 * math.pi * _pulse.value)) / 2;
          final scale =
              EbAnimatedLogo.startScale + (1 - EbAnimatedLogo.startScale) * enter.value + 0.03 * wave;
          return Opacity(
            opacity: 1 - 0.1 * wave,
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: logo,
      ),
    );
  }
}
