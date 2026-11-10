// Tokens de diseño de EASYBUS (skill easybus-ui). Ningún widget escribe colores,
// espacios ni duraciones a mano: todo sale de aquí.

import 'package:flutter/animation.dart';

abstract final class EbColors {
  // Identidad
  static const navy = Color(0xFF062559); // institucional: barra inferior, botones, píldora
  static const river = Color(0xFF1C8FBF); // modo fluvial: trazado, marcadores, chip
  static const bank = Color(0xFF2E9E6B); // acento ribera

  // Variantes para TEXTO. river, bank y alertDelay no llegan a 4.5:1 sobre blanco
  // (3.66, 3.38 y 4.24), así que solo se usan en líneas, íconos y fondos.
  // Estas versiones oscuras sí cumplen sobre blanco y sobre surface.
  static const riverInk = Color(0xFF13729A); // 5.38 blanco · 4.94 surface
  static const bankInk = Color(0xFF217A53); // 5.29 blanco · 4.85 surface
  static const alertDelayInk = Color(0xFF9A5C00); // 5.38 blanco · 4.93 surface

  // Superficies y texto
  static const white = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF4F5F8);
  static const skeleton = Color(0xFFE3E7EE);
  static const textPrimary = Color(0xFF111111);
  static const textMuted = Color(0xFF5A5F6B);
  static const divider = Color(0xFFDCE0E8);

  // Avisos de servicio (ícono, borde y fondo del banner)
  static const alertSuspended = Color(0xFFC62828);
  static const alertDelay = Color(0xFFB26A00);
  static const alertInfo = Color(0xFF1565C0);

  // Fondos suaves de los banners de aviso (el texto va con el color del aviso o su Ink)
  static const alertSuspendedTint = Color(0xFFFDECEC);
  static const alertDelayTint = Color(0xFFFFF4E0);
  static const alertInfoTint = Color(0xFFE8F1FB);
  static const riverTint = Color(0xFFE6F4FA);
}

abstract final class EbSpacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
}

abstract final class EbRadius {
  static const card = 16.0;
  static const pill = 999.0;
  static const sheet = 24.0;
}

abstract final class EbSizes {
  // Área táctil mínima (accesibilidad)
  static const minTouch = 48.0;
}

abstract final class EbDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

// Curvas de la skill easybus-motion: suaves, como el río
abstract final class EbCurves {
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
}
