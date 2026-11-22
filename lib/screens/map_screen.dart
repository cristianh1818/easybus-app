// Pestaña Mapa (mockup "Pantalla principal"): ☰ arriba a la izquierda y la píldora
// "¿A dónde quieres ir hoy?" sobre la barra inferior.
// TEMPORAL: el mapa del río aún no está; se muestra un fondo de agua.

import 'package:flutter/material.dart';

import '../models/transport_mode.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../widgets/eb_bottom_nav.dart';
import '../widgets/eb_menu_button.dart';
import '../widgets/eb_search_pill.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.mode, required this.onOpenPiers});

  final TransportMode mode;

  /// Mientras no haya búsqueda de origen y destino, la píldora lleva a la lista.
  final VoidCallback onOpenPiers;

  @override
  Widget build(BuildContext context) {
    final style = mode.style;
    // Con extendBody, MediaQuery ya incluye el alto de la barra inferior
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: style.tint,
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(EbSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 56, color: style.color),
                  const SizedBox(height: EbSpacing.m),
                  Text(
                    'El mapa del río Sinú estará aquí muy pronto.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: EbColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, child: EbMenuButton()),
          Positioned(
            left: EbSpacing.l,
            right: EbSpacing.l,
            bottom: bottom + EbSpacing.m - EbBottomNav.bubbleOverflow,
            child: Center(child: EbSearchPill(onTap: onOpenPiers)),
          ),
        ],
      ),
    );
  }
}
