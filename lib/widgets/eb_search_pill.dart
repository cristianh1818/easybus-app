// Píldora flotante "¿A dónde quieres ir hoy?" (elemento firma, mockup "Pantalla
// principal"): marino, con ícono de ubicación y texto blanco.

import 'package:flutter/material.dart';

import '../theme/eb_tokens.dart';

class EbSearchPill extends StatelessWidget {
  const EbSearchPill({super.key, required this.onTap, this.label = '¿A dónde quieres ir hoy?'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(color: EbColors.white);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: EbColors.navy,
        shape: const StadiumBorder(side: BorderSide(color: EbColors.white, width: 1.5)),
        elevation: 4,
        shadowColor: Colors.black38,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EbSpacing.l, vertical: EbSpacing.s),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on_outlined, color: EbColors.white, size: 28),
                  const SizedBox(width: EbSpacing.s),
                  Flexible(child: Text(label, style: style)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
