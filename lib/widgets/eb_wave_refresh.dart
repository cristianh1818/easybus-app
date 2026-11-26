// "Deslizar para actualizar" con una gota de agua en lugar del círculo de Material
// (skill easybus-motion): al tirar, el agua sube dentro del círculo; mientras se
// actualiza, la superficie se mueve como una ola. Con "reducir movimiento" no hay
// ola en bucle: el círculo se llena y se muestra quieto.
//
// Usa RefreshIndicator.noSpinner: el gesto, la accesibilidad y el onRefresh son los
// de Material; solo cambia el dibujo.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eb_tokens.dart';

class EbWaveRefresh extends StatefulWidget {
  const EbWaveRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
    this.semanticsLabel = 'Actualizar',
  });

  final RefreshCallback onRefresh;
  final Widget child;

  /// Distancia desde arriba donde aparece la gota (p. ej. debajo de la barra de estado).
  final double edgeOffset;
  final String semanticsLabel;

  @override
  State<EbWaveRefresh> createState() => _EbWaveRefreshState();
}

class _EbWaveRefreshState extends State<EbWaveRefresh> with SingleTickerProviderStateMixin {
  /// Cuánto hay que tirar para llenar el círculo (como el RefreshIndicator).
  static const _pullExtent = 100.0;
  static const _size = 44.0;

  late final _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  RefreshIndicatorStatus? _status;
  double _pulled = 0;

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  void _onStatus(RefreshIndicatorStatus? status) {
    setState(() => _status = status);
    final refreshing = status == RefreshIndicatorStatus.refresh || status == RefreshIndicatorStatus.snap;
    if (refreshing && !_reduceMotion) {
      _wave.repeat();
    } else {
      _wave.stop();
    }
    if (status == null ||
        status == RefreshIndicatorStatus.done ||
        status == RefreshIndicatorStatus.canceled) {
      _pulled = 0;
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    // Rebote (iOS) o borde con "overscroll" (Android): cuánto se tiró hacia abajo
    if (n is ScrollUpdateNotification && n.metrics.pixels < n.metrics.minScrollExtent) {
      _pulled = n.metrics.minScrollExtent - n.metrics.pixels;
    } else if (n is OverscrollNotification && n.overscroll < 0) {
      _pulled += -n.overscroll;
    } else if (n is ScrollEndNotification && _status == RefreshIndicatorStatus.drag) {
      _pulled = 0;
    }
    if (_status == RefreshIndicatorStatus.drag || _status == RefreshIndicatorStatus.armed) setState(() {});
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final visible =
        status != null && status != RefreshIndicatorStatus.done && status != RefreshIndicatorStatus.canceled;
    final refreshing = status == RefreshIndicatorStatus.refresh || status == RefreshIndicatorStatus.snap;
    final level = refreshing ? 0.6 : (_pulled / _pullExtent).clamp(0.0, 1.0) * 0.8;
    final drop = (refreshing ? 1.0 : (_pulled / _pullExtent).clamp(0.0, 1.0)) * 56;

    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: _onStatus,
          semanticsLabel: widget.semanticsLabel,
          child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child),
        ),
        Positioned(
          top: widget.edgeOffset + drop - _size,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: EbDurations.fast,
                child: RepaintBoundary(
                  child: Material(
                    color: EbColors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: Colors.black26,
                    child: SizedBox.square(
                      dimension: _size,
                      child: ClipOval(
                        child: AnimatedBuilder(
                          animation: _wave,
                          builder: (_, _) => CustomPaint(
                            painter: _WaterPainter(level: level, phase: _wave.value, refreshing: refreshing),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Agua dentro del círculo: una superficie ondulada a la altura [level] (0 a 1).
class _WaterPainter extends CustomPainter {
  _WaterPainter({required this.level, required this.phase, required this.refreshing});

  final double level;
  final double phase;
  final bool refreshing;

  @override
  void paint(Canvas canvas, Size size) {
    final surface = size.height * (1 - level);
    final amplitude = refreshing ? 3.0 : 2.0;
    Path wave(double shift) {
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 1) {
        final y = surface + amplitude * math.sin(2 * math.pi * (x / size.width + phase + shift));
        path.lineTo(x, y);
      }
      return path
        ..lineTo(size.width, size.height)
        ..close();
    }

    canvas
      ..drawPath(wave(0.5), Paint()..color = EbColors.river.withValues(alpha: 0.35))
      ..drawPath(wave(0), Paint()..color = EbColors.river);
    // Borde del círculo
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 - 1.5,
      Paint()
        ..color = EbColors.riverTint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_WaterPainter old) =>
      old.level != level || old.phase != phase || old.refreshing != refreshing;
}
