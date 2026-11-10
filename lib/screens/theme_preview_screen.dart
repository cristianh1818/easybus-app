// TEMPORAL: muestra del tema para revisarlo en el emulador. Se elimina cuando
// existan el splash y la pantalla de inicio.

import 'package:flutter/material.dart';

import '../models/transport_mode.dart';
import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';

class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fluvial = TransportMode.fluvial.style;

    return Scaffold(
      appBar: AppBar(title: const Text('EASYBUS · Tema')),
      body: ListView(
        padding: context.ebScrollPadding(),
        children: [
          Text('Próximo zarpe', style: text.titleMedium),
          Text('07:20', style: text.displayMedium?.copyWith(color: EbColors.navy)),
          Text(
            'en 15 min · Horario programado, no ubicación en tiempo real',
            style: text.bodySmall?.copyWith(color: EbColors.textMuted),
          ),
          const SizedBox(height: EbSpacing.l),
          Wrap(
            spacing: EbSpacing.s,
            runSpacing: EbSpacing.s,
            children: [
              Chip(
                avatar: Icon(fluvial.icon, size: 18, color: fluvial.color),
                label: Text(fluvial.label, style: TextStyle(color: fluvial.ink)),
                backgroundColor: fluvial.tint,
              ),
              Chip(label: Text(fluvial.stopLabel)),
            ],
          ),
          const SizedBox(height: EbSpacing.l),
          const _Swatches(),
          const SizedBox(height: EbSpacing.l),
          FilledButton(onPressed: () {}, child: const Text('Ver embarcadero')),
          const SizedBox(height: EbSpacing.s),
          OutlinedButton(onPressed: () {}, child: const Text('Cómo llegar')),
          const SizedBox(height: EbSpacing.s),
          TextButton(onPressed: () {}, child: const Text('Reintentar')),
          const SizedBox(height: EbSpacing.l),
          Card(
            child: ListTile(
              leading: Icon(fluvial.icon, color: fluvial.color),
              title: const Text('Embarcadero Centro'),
              subtitle: const Text('Ronda del Sinú, frente al centro'),
            ),
          ),
          const SizedBox(height: EbSpacing.l),
          for (final (texto, estilo) in [
            ('displaySmall', text.displaySmall),
            ('headlineSmall', text.headlineSmall),
            ('titleLarge', text.titleLarge),
            ('bodyLarge · Poppins con tildes: Sinú, Montería, embarcación', text.bodyLarge),
            ('bodyMedium', text.bodyMedium),
            ('labelSmall', text.labelSmall),
          ])
            Text(texto, style: estilo),
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches();

  static const _colores = [
    ('navy', EbColors.navy),
    ('river', EbColors.river),
    ('bank', EbColors.bank),
    ('riverInk', EbColors.riverInk),
    ('bankInk', EbColors.bankInk),
    ('suspendido', EbColors.alertSuspended),
    ('retraso', EbColors.alertDelay),
    ('info', EbColors.alertInfo),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: EbSpacing.s,
      runSpacing: EbSpacing.s,
      children: [
        for (final (nombre, color) in _colores)
          // Ancho y alto mínimos, no fijos: con textos largos o la fuente del
          // sistema al 130 % la muestra crece en vez de partir la palabra.
          Container(
            constraints: const BoxConstraints(minWidth: 76, minHeight: EbSizes.minTouch),
            padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m, vertical: EbSpacing.s),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(EbRadius.card / 2)),
            child: Text(
              nombre,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: EbColors.white),
            ),
          ),
      ],
    );
  }
}
