// Pestaña Embarcaderos. TEMPORAL: solo el encabezado; la lista con datos reales,
// skeleton, estados de error y vacío y el banner de avisos llegan en el siguiente paso.

import 'package:flutter/material.dart';

import '../models/transport_mode.dart';
import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../widgets/eb_screen_header.dart';

class PiersScreen extends StatelessWidget {
  const PiersScreen({super.key, required this.mode});

  final TransportMode mode;

  @override
  Widget build(BuildContext context) {
    final style = mode.style;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EbScreenHeader(title: style.stopLabelPlural),
        Expanded(
          child: ListView(
            padding: context.ebScrollPadding().copyWith(top: EbSpacing.l),
            children: [
              Icon(style.icon, size: 48, color: style.color),
              const SizedBox(height: EbSpacing.m),
              Text(
                'Aquí verás los ${style.stopLabelPlural.toLowerCase()} del río Sinú.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: EbColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
