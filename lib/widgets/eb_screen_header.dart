// Encabezado de las pestañas: deja libre el lugar del botón ☰ (que pone HomeShell,
// uno solo para las tres pestañas, siempre en la misma posición) y muestra el título
// a su lado, centrado con él. El título nunca parte una palabra (EbWrapText).

import 'package:flutter/material.dart';

import '../theme/eb_tokens.dart';
import 'eb_menu_button.dart';
import 'eb_wrap_text.dart';

class EbScreenHeader extends StatelessWidget {
  const EbScreenHeader({super.key, required this.title, this.titleAlign = TextAlign.start});

  final String title;
  final TextAlign titleAlign;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Row(
        children: [
          // Lugar del ☰ (HomeShell lo dibuja encima, a esta misma altura)
          const SizedBox.square(dimension: EbMenuButton.size),
          const SizedBox(width: EbSpacing.m),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: EbSpacing.m),
              child: Semantics(
                header: true,
                child: EbWrapText(
                  title,
                  textAlign: titleAlign,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
