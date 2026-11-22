// Encabezado de las pestañas: botón ☰ a la izquierda y el título en una píldora
// gris pegada al borde (mockup "Rutas disponibles").

import 'package:flutter/material.dart';

import '../theme/eb_tokens.dart';
import 'eb_menu_button.dart';

class EbScreenHeader extends StatelessWidget {
  const EbScreenHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EbMenuButton(),
        const SizedBox(width: EbSpacing.m),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: top + EbSpacing.s, right: EbSpacing.m),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
