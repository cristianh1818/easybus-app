// Botón ☰ del mockup: una pestaña marino pegada al borde izquierdo, con la esquina
// inferior derecha redondeada. Abre el menú lateral del Scaffold principal.

import 'package:flutter/material.dart';

import '../theme/eb_tokens.dart';

class EbMenuButton extends StatelessWidget {
  const EbMenuButton({super.key});

  static const size = 64.0;

  @override
  Widget build(BuildContext context) {
    // Empieza debajo de la barra de estado: si la cubriera, la hora y los íconos
    // (oscuros sobre fondo claro) no se leerían sobre el marino.
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Semantics(
        button: true,
        label: 'Abrir menú',
        onTap: () => Scaffold.of(context).openDrawer(),
        excludeSemantics: true,
        child: Material(
          color: EbColors.navy,
          elevation: 2,
          shadowColor: Colors.black26,
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(EbRadius.sheet)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: const SizedBox.square(
              dimension: size,
              child: Icon(Icons.menu_rounded, color: EbColors.white, size: 34),
            ),
          ),
        ),
      ),
    );
  }
}
