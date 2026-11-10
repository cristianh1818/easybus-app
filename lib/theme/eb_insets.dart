// Márgenes de pantalla que respetan las zonas del sistema.
//
// La app se dibuja de borde a borde (edge-to-edge, obligatorio desde Android 15):
// el contenido pasa por detrás de la barra de estado y de la barra de navegación.
// Regla para TODAS las pantallas:
//   - Contenido desplazable (ListView, CustomScrollView…): padding con
//     context.ebScrollPadding(). Así la lista se desliza por detrás de la barra
//     de navegación, pero el último elemento termina por encima de ella.
//   - Contenido fijo (formularios cortos, estados vacíos, botones al pie):
//     envolver en SafeArea.
//   - El mapa sí va de borde a borde; sus controles flotantes usan ebScrollPadding
//     o SafeArea.

import 'package:flutter/widgets.dart';

import 'eb_tokens.dart';

extension EbInsetsX on BuildContext {
  /// Padding para el contenido desplazable de una pantalla: el margen estándar
  /// más lo que ocupan las barras del sistema (gestos o botones de navegación,
  /// recortes laterales en horizontal).
  ///
  /// Usa MediaQuery.paddingOf: cuando el teclado está abierto el inferior pasa a 0,
  /// porque el Scaffold ya reserva ese espacio.
  EdgeInsets ebScrollPadding({
    double horizontal = EbSpacing.m,
    double top = EbSpacing.m,
    double bottom = EbSpacing.m,
  }) {
    final system = MediaQuery.paddingOf(this);
    return EdgeInsets.fromLTRB(
      horizontal + system.left,
      top + system.top,
      horizontal + system.right,
      bottom + system.bottom,
    );
  }
}
