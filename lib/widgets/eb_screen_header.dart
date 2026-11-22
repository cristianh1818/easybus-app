// Encabezado de las pestañas: botón ☰ y título en la misma fila, sin superponerse.
// El título nunca parte una palabra (EbWrapText) y queda centrado con el botón.

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
          // El padding superior ya se aplicó: el botón no debe sumarlo otra vez
          MediaQuery.removePadding(context: context, removeTop: true, child: const EbMenuButton()),
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
