// Barra inferior de EASYBUS (mockup "Pantalla principal"): fondo marino con las
// esquinas superiores redondeadas y la pestaña activa dentro de una burbuja clara que
// sobresale de la barra y se desliza al cambiar de pestaña (250 ms).
//
// Las etiquetas caben siempre: las tres usan el mismo tamaño, el mayor con el que la
// más larga ("Embarcaderos") cabe dentro de la burbuja, sin tocar sus esquinas.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/eb_tokens.dart';

@immutable
class EbNavItem {
  const EbNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class EbBottomNav extends StatelessWidget {
  const EbBottomNav({super.key, required this.items, required this.currentIndex, required this.onTap});

  final List<EbNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Alto de la barra (sin la zona de gestos del sistema).
  static const barHeight = 72.0;

  /// Cuánto sobresale la burbuja de la pestaña activa por encima de la barra.
  static const bubbleOverflow = 14.0;

  /// Burbuja de la pestaña activa (para las pruebas de diseño).
  static const bubbleKey = Key('eb-bottom-nav-bubble');

  /// Burbuja: ancho de la pestaña menos [_bubbleInset] a cada lado y esquinas de
  /// [bubbleRadius] (un círculo fijo no deja caber "Embarcaderos").
  static const bubbleHeight = 82.0;
  static const bubbleRadius = 30.0;
  static const _bubbleInset = 6.0;

  /// Margen lateral de la etiqueta dentro de su pestaña: la deja dentro de la parte
  /// recta de la burbuja, lejos de las esquinas redondeadas.
  static const labelInset = _bubbleInset + 10;

  static const _iconSize = 30.0;
  static const _maxLabelScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final labelStyle = Theme.of(context).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w600);

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelScaler = _labelScaler(context, labelStyle, constraints.maxWidth / items.length);
        return SizedBox(
          height: barHeight + bubbleOverflow + systemBottom,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Fondo marino
              Positioned.fill(
                top: bubbleOverflow,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: EbColors.navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(EbRadius.sheet + 4)),
                  ),
                ),
              ),
              // Burbuja de la pestaña activa (se desliza)
              AnimatedAlign(
                duration: reduceMotion ? Duration.zero : EbDurations.normal,
                curve: EbCurves.enter,
                alignment: Alignment(_alignX(currentIndex), -1),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: _bubbleInset),
                    child: SizedBox(
                      height: bubbleHeight,
                      key: bubbleKey,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: EbColors.skeleton,
                          borderRadius: BorderRadius.all(Radius.circular(bubbleRadius)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Botones, centrados con la burbuja
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: bubbleHeight,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: labelScaler),
                  child: Row(
                    children: [
                      for (final (i, item) in items.indexed)
                        Expanded(
                          child: _NavButton(item: item, selected: i == currentIndex, onTap: () => onTap(i)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Un solo tamaño para las tres etiquetas: crece con la fuente del sistema hasta el
  /// 130 % y se reduce si la etiqueta más larga no cabe en su pestaña.
  TextScaler _labelScaler(BuildContext context, TextStyle style, double slotWidth) {
    final fontSize = style.fontSize ?? 13;
    final system = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _maxLabelScale);
    final scale = system.scale(fontSize) / fontSize;
    final available = slotWidth - 2 * labelInset;
    var widest = 0.0;
    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(text: item.label, style: style),
        textScaler: TextScaler.linear(scale),
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final fit = widest > available ? available / widest : 1.0;
    return TextScaler.linear(scale * fit);
  }

  double _alignX(int index) => items.length == 1 ? 0 : -1 + 2 * index / (items.length - 1);
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final EbNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? EbColors.navy : EbColors.white;
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: color, fontWeight: FontWeight.w600);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      // La acción va aquí: excludeSemantics también quitaría la del InkResponse
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(EbBottomNav.bubbleRadius)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EbBottomNav.labelInset),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: EbDurations.fast,
                child: Icon(item.icon, key: ValueKey(selected), size: EbBottomNav._iconSize, color: color),
              ),
              const SizedBox(height: 2),
              // Ya viene con el tamaño justo; FittedBox solo evita desbordes por redondeo
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(item.label, maxLines: 1, style: style),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
