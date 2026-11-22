// Barra inferior de EASYBUS (mockup "Pantalla principal"): fondo marino con las
// esquinas superiores redondeadas y la pestaña activa dentro de un círculo claro que
// sobresale de la barra. Al cambiar de pestaña el círculo se desliza (250 ms).

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

  /// Cuánto sobresale el círculo de la pestaña activa por encima de la barra.
  static const bubbleOverflow = 14.0;
  static const _bubbleSize = 78.0;

  @override
  Widget build(BuildContext context) {
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // Las etiquetas crecen con la fuente del sistema hasta el 130 %; más allá se
    // reducen para caber (la barra tiene alto fijo).
    final textScaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: SizedBox(
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
            // Círculo de la pestaña activa (se desliza)
            AnimatedAlign(
              duration: reduceMotion ? Duration.zero : EbDurations.normal,
              curve: EbCurves.enter,
              alignment: Alignment(_alignX(currentIndex), -1),
              child: FractionallySizedBox(
                widthFactor: 1 / items.length,
                child: const Center(
                  child: SizedBox.square(
                    dimension: _bubbleSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: EbColors.skeleton, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),
            // Botones
            Positioned(
              left: 0,
              right: 0,
              top: bubbleOverflow,
              height: barHeight,
              child: Row(
                children: [
                  for (final (i, item) in items.indexed)
                    Expanded(
                      child: _NavButton(item: item, selected: i == currentIndex, onTap: () => onTap(i)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        ?.copyWith(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      // La acción va aquí: excludeSemantics también quitaría la del InkResponse
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.circle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: EbSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: EbDurations.fast,
                child: Icon(item.icon, key: ValueKey(selected), size: 30, color: color),
              ),
              const SizedBox(height: 2),
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
