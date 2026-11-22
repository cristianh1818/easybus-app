// Tarjeta de embarcadero en la lista: nombre, referencia, estado, margen,
// accesibilidad (solo lo que se sabe) y el próximo zarpe en cada sentido.

import 'package:flutter/material.dart';

import '../models/aviso.dart';
import '../models/enums.dart';
import '../providers/piers_providers.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import 'eb_wrap_text.dart';

/// Etiqueta Hero del ícono del embarcadero: la comparten la tarjeta y el encabezado
/// del detalle (pier_detail_screen.dart).
String pierHeroTag(String id) => 'pier-icon-$id';

class EbPierCard extends StatelessWidget {
  const EbPierCard({
    super.key,
    required this.item,
    required this.departureBuilder,
    this.avisos = const [],
    this.showSampleTag = true,
    this.onTap,
  });

  final PierListItem item;

  /// Construye la fila de próximo zarpe de cada servicio (en el skeleton se usa una
  /// fila de ejemplo, sin consultar la API).
  final Widget Function(PierService service) departureBuilder;

  /// Avisos vigentes que afectan solo a este embarcadero.
  final List<Aviso> avisos;

  /// false cuando toda la lista es de ejemplo (la pantalla lo dice una sola vez).
  final bool showSampleTag;

  /// Abre el detalle (null en el skeleton).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = item.embarcadero;
    final mode = e.mode.style;
    final text = Theme.of(context).textTheme;
    final closed = e.estado == EstadoEmbarcadero.cerradoTemporal;

    final tags = <Widget>[
      if (closed) const _Tag(label: 'Cerrado temporalmente', color: EbColors.alertSuspended),
      for (final a in avisos)
        _Tag(
          label: switch (a.tipo) {
            TipoAviso.suspendido => 'Suspendido',
            TipoAviso.retraso => 'Retraso',
            TipoAviso.cambioHorario => 'Cambio de horario',
            TipoAviso.informativo => 'Aviso',
          },
          color: a.esSuspension ? EbColors.alertSuspended : EbColors.alertDelayInk,
        ),
      if (e.margen != null)
        _Tag(label: e.margen == Margen.izquierda ? 'Margen izquierda' : 'Margen derecha', color: mode.ink),
      if (showSampleTag && !e.esOficial) const _Tag(label: 'Dato de ejemplo', color: EbColors.textMuted),
    ];
    final accessibility = [
      if (e.tieneRampa == true) (Icons.accessible_rounded, 'Rampa'),
      if (e.tieneTecho == true) (Icons.roofing_rounded, 'Techo'),
      if (e.tieneIluminacion == true) (Icons.lightbulb_outline_rounded, 'Iluminación'),
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(EbSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Hero(
                      // Viaja al encabezado del detalle (pier_detail_screen.dart)
                      tag: pierHeroTag(e.id),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: mode.tint,
                        child: Icon(mode.icon, color: mode.color),
                      ),
                    ),
                  ),
                  const SizedBox(width: EbSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: EbWrapText(e.nombre, style: text.titleMedium)),
                        if (e.referencia != null)
                          EbWrapText(
                            e.referencia!,
                            style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: EbSpacing.s),
                Wrap(spacing: EbSpacing.xs, runSpacing: EbSpacing.xs, children: tags),
              ],
              if (accessibility.isNotEmpty) ...[
                const SizedBox(height: EbSpacing.s),
                Wrap(
                  spacing: EbSpacing.m,
                  children: [
                    for (final (icon, label) in accessibility)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(child: Icon(icon, size: 18, color: EbColors.textMuted)),
                          const SizedBox(width: 2),
                          Text(label, style: text.bodySmall?.copyWith(color: EbColors.textMuted)),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: EbSpacing.s),
              const Divider(),
              const SizedBox(height: EbSpacing.xs),
              if (closed)
                Text(
                  'Hoy no hay zarpes desde este ${mode.stopLabel.toLowerCase()}.',
                  style: text.bodyMedium?.copyWith(color: EbColors.alertSuspended),
                )
              else if (item.services.isEmpty)
                Text(
                  'Ninguna ruta activa sale desde aquí.',
                  style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
                )
              else
                for (final s in item.services) departureBuilder(s),
              if (onTap != null) ...[
                const SizedBox(height: EbSpacing.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: 'Ver ${e.nombre}',
                    onTap: onTap,
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ver ${mode.stopLabel.toLowerCase()}',
                          style: text.labelLarge?.copyWith(color: EbColors.riverInk),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: EbColors.riverInk),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(EbRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: EbSpacing.s, vertical: 2),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
      ),
    );
  }
}
