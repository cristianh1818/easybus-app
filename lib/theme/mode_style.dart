// Estilo por modo de transporte. Los widgets leen color, ícono y textos de aquí
// (modeStyle[mode]) y nunca escriben "fluvial" ni "embarcadero" dentro de su código.

import 'package:flutter/material.dart';

import '../models/transport_mode.dart';
import 'eb_tokens.dart';

@immutable
class ModeStyle {
  const ModeStyle({
    required this.color,
    required this.accent,
    required this.ink,
    required this.tint,
    required this.icon,
    required this.label,
    required this.stopLabel,
    required this.stopLabelPlural,
    required this.vehicleLabel,
  });

  /// Color principal del modo: trazado, marcadores, chip (no para texto pequeño).
  final Color color;

  /// Acento secundario del modo.
  final Color accent;

  /// Versión del color apta para texto (contraste ≥ 4.5:1).
  final Color ink;

  /// Fondo suave para chips y encabezados del modo.
  final Color tint;

  final IconData icon;

  /// "Fluvial", "Bus".
  final String label;

  /// "Embarcadero" / "Parada".
  final String stopLabel;

  /// "Embarcaderos" / "Paradas".
  final String stopLabelPlural;

  /// "Embarcación" / "Bus".
  final String vehicleLabel;
}

const Map<TransportMode, ModeStyle> modeStyle = {
  TransportMode.fluvial: ModeStyle(
    color: EbColors.river,
    accent: EbColors.bank,
    ink: EbColors.riverInk,
    tint: EbColors.riverTint,
    icon: Icons.directions_boat_filled_rounded,
    label: 'Fluvial',
    stopLabel: 'Embarcadero',
    stopLabelPlural: 'Embarcaderos',
    vehicleLabel: 'Embarcación',
  ),
  // Fase 2: cada ruta de bus usará su propio color; este es solo el valor por defecto.
  TransportMode.bus: ModeStyle(
    color: EbColors.navy,
    accent: EbColors.bank,
    ink: EbColors.navy,
    tint: EbColors.surface,
    icon: Icons.directions_bus_filled_rounded,
    label: 'Bus',
    stopLabel: 'Parada',
    stopLabelPlural: 'Paradas',
    vehicleLabel: 'Bus',
  ),
};

extension ModeStyleX on TransportMode {
  ModeStyle get style => modeStyle[this]!;
}
