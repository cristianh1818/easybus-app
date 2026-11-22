// Detalle del embarcadero (skill easybus-ui): foto o ícono, referencia, estado,
// avisos (antes que los horarios), rutas que lo atienden con el próximo zarpe y los
// siguientes, accesibilidad y "Cómo llegar".
//
// Mientras carga, muestra de inmediato lo que ya se conoce de la lista (nombre,
// referencia) y un skeleton solo para lo que falta.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/siguientes_pasos.dart';
import '../models/embarcadero.dart';
import '../models/enums.dart';
import '../providers/clock_provider.dart';
import '../providers/data_providers.dart';
import '../providers/errors.dart';
import '../providers/piers_providers.dart';
import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../utils/time_format.dart';
import '../widgets/eb_async_view.dart';
import '../widgets/eb_avisos_section.dart';
import '../widgets/eb_next_departure_row.dart';
import '../widgets/eb_pier_card.dart' show pierHeroTag;
import '../widgets/eb_wrap_text.dart';

class PierDetailScreen extends ConsumerWidget {
  const PierDetailScreen({super.key, required this.embarcadero, this.openUrl = _openExternal});

  /// Lo que ya se conoce de la lista: se muestra de inmediato.
  final Embarcadero embarcadero;

  /// Abre "Cómo llegar" (reemplazable en las pruebas).
  final Future<bool> Function(Uri url) openUrl;

  static Future<bool> _openExternal(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

  /// Google Maps con el embarcadero como destino, a pie. Funciona con la app de
  /// Google Maps o en el navegador. La ubicación del usuario no pasa por EASYBUS.
  static Uri directionsUrl(Embarcadero e) => Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '${e.ubicacion.lat},${e.ubicacion.lng}',
    'travelmode': 'walking',
  });

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(embarcaderoDetalleProvider(embarcadero.id))
      ..invalidate(avisosProvider)
      ..invalidate(proximaSalidaProvider)
      ..invalidate(horariosProvider);
    try {
      await ref.read(embarcaderoDetalleProvider(embarcadero.id).future);
    } on Object {
      // El error se muestra en la pantalla
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detalle = ref.watch(embarcaderoDetalleProvider(embarcadero.id));
    final style = embarcadero.mode.style;
    // Los datos más recientes del embarcadero (si ya llegó el detalle)
    final e = detalle.value?.data.embarcadero ?? embarcadero;

    return Scaffold(
      appBar: AppBar(title: EbWrapText(style.stopLabel, maxLines: 1)),
      body: RefreshIndicator(
        color: EbColors.river,
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.ebScrollPadding(top: EbSpacing.s),
          children: [
            _Header(embarcadero: e),
            const SizedBox(height: EbSpacing.m),
            // Avisos antes que los horarios: generales, de este embarcadero y de sus rutas
            EbAvisosSection(embarcaderoId: embarcadero.id),
            EbAsyncView(
              value: detalle,
              skeleton: const _RoutesSkeleton(),
              error: (error) => _InlineError(
                error: toApiException(error).message,
                offline: toApiException(error).isOffline,
                onRetry: () => _refresh(ref),
              ),
              data: (fetched) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (fetched.refreshError != null) ...[
                    _Note(
                      icon: Icons.wifi_off_rounded,
                      text: fetched.refreshError!.isOffline
                          ? 'Sin conexión a internet. Estás viendo los datos guardados en tu teléfono.'
                          : 'El servicio no está disponible en este momento. Estás viendo los datos guardados en tu teléfono.',
                    ),
                    const SizedBox(height: EbSpacing.s),
                  ],
                  _Routes(detalle: fetched.data, updatedAt: fetched.updatedAt),
                ],
              ),
            ),
            const SizedBox(height: EbSpacing.m),
            _Accessibility(embarcadero: e),
            const SizedBox(height: EbSpacing.l),
            FilledButton.icon(
              onPressed: () => openUrl(directionsUrl(e)),
              icon: const Icon(Icons.directions_walk_rounded),
              label: const Text('Cómo llegar'),
            ),
            const SizedBox(height: EbSpacing.s),
            Text(
              'Se abre Google Maps con el ${style.stopLabel.toLowerCase()} como destino.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EbColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.embarcadero});

  final Embarcadero embarcadero;

  @override
  Widget build(BuildContext context) {
    final e = embarcadero;
    final style = e.mode.style;
    final text = Theme.of(context).textTheme;

    final tags = <String>[
      if (e.estado == EstadoEmbarcadero.cerradoTemporal) 'Cerrado temporalmente',
      if (e.margen != null) e.margen == Margen.izquierda ? 'Margen izquierda' : 'Margen derecha',
      if (!e.esOficial) 'Dato de ejemplo',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(EbRadius.card),
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: e.fotoUrl == null
                ? ColoredBox(
                    color: style.tint,
                    child: Center(
                      child: Hero(
                        tag: pierHeroTag(e.id),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: EbColors.white,
                          child: Icon(
                            style.icon,
                            size: 40,
                            color: style.color,
                            semanticLabel: style.stopLabel,
                          ),
                        ),
                      ),
                    ),
                  )
                : Image.network(
                    e.fotoUrl!,
                    fit: BoxFit.cover,
                    semanticLabel: 'Foto del ${e.nombre}',
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: style.tint,
                      child: Icon(style.icon, size: 40, color: style.color),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: EbSpacing.m),
        Semantics(header: true, child: EbWrapText(e.nombre, style: text.headlineSmall)),
        if (e.referencia != null) ...[
          const SizedBox(height: EbSpacing.xs),
          EbWrapText(e.referencia!, style: text.bodyLarge?.copyWith(color: EbColors.textMuted)),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: EbSpacing.s),
          Wrap(
            spacing: EbSpacing.xs,
            runSpacing: EbSpacing.xs,
            children: [
              for (final t in tags)
                Chip(
                  label: Text(t),
                  labelStyle: text.labelMedium?.copyWith(
                    color: t == 'Cerrado temporalmente' ? EbColors.alertSuspended : EbColors.textPrimary,
                  ),
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: EbColors.divider),
                  backgroundColor: EbColors.white,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Rutas que pasan por el embarcadero, con el próximo zarpe y los siguientes.
class _Routes extends ConsumerWidget {
  const _Routes({required this.detalle, required this.updatedAt});

  final EmbarcaderoDetalle detalle;
  final DateTime updatedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: EbColors.textMuted);
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();
    final e = detalle.embarcadero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: EbWrapText('Rutas y próximos zarpes', style: text.titleLarge)),
        Text('Horarios programados, no ubicación en tiempo real.', style: muted),
        Text(formatUpdatedAgo(updatedAt, now), style: muted),
        const SizedBox(height: EbSpacing.s),
        if (detalle.rutas.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(EbSpacing.m),
              child: EbWrapText(
                'Ninguna ruta activa pasa por aquí por ahora.',
                style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
              ),
            ),
          ),
        for (final r in detalle.rutas) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(EbSpacing.m),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EbWrapText('${r.ruta.codigo} · ${r.ruta.nombre}', style: text.titleMedium),
                  EbWrapText(
                    [
                      if (r.totalEmbarcaderos != null) 'Parada ${r.orden} de ${r.totalEmbarcaderos}',
                      'hacia ${r.destino}',
                    ].join(' · '),
                    style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
                  ),
                  const SizedBox(height: EbSpacing.xs),
                  if (e.estado == EstadoEmbarcadero.cerradoTemporal)
                    EbWrapText(
                      'Hoy no hay zarpes desde aquí.',
                      style: text.bodyMedium?.copyWith(color: EbColors.alertSuspended),
                    )
                  else if (r.totalEmbarcaderos != null && r.orden >= r.totalEmbarcaderos!)
                    EbWrapText(
                      'Es la última parada de este sentido: aquí termina el recorrido.',
                      style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
                    )
                  else ...[
                    EbNextDepartureRow(
                      service: PierService(
                        rutaId: r.ruta.id,
                        rutaCodigo: r.ruta.codigo,
                        sentido: r.sentido,
                        destino: r.destino,
                        orden: r.orden,
                      ),
                      embarcaderoId: e.id,
                      label: 'Próximo zarpe',
                    ),
                    _NextPasses(rutaId: r.ruta.id, sentido: r.sentido, embarcaderoId: e.id),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: EbSpacing.s),
        ],
      ],
    );
  }
}

/// "Luego: 07:42 · 08:12 · 08:42" (solo si hay próxima salida y horarios).
class _NextPasses extends ConsumerWidget {
  const _NextPasses({required this.rutaId, required this.sentido, required this.embarcaderoId});

  final String rutaId;
  final Sentido sentido;
  final String embarcaderoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxima = ref
        .watch(proximaSalidaProvider((rutaId: rutaId, sentido: sentido, desdeEmbarcaderoId: embarcaderoId)))
        .value;
    final horarios = ref.watch(horariosProvider((rutaId: rutaId, sentido: sentido, tipoDia: null))).value;
    if (proxima == null || horarios == null) return const SizedBox.shrink();
    final pasos = siguientesPasos(proxima.data, horarios.data.horarios);
    if (pasos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: EbSpacing.xs),
      child: EbWrapText(
        'Luego: ${pasos.join(' · ')}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: EbColors.textMuted),
      ),
    );
  }
}

class _Accessibility extends StatelessWidget {
  const _Accessibility({required this.embarcadero});

  final Embarcadero embarcadero;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    String valor(bool? v) => switch (v) {
      true => 'Sí',
      false => 'No',
      null => 'Sin información',
    };
    final items = [
      (Icons.accessible_rounded, 'Rampa', embarcadero.tieneRampa),
      (Icons.roofing_rounded, 'Techo', embarcadero.tieneTecho),
      (Icons.lightbulb_outline_rounded, 'Iluminación', embarcadero.tieneIluminacion),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EbSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: EbWrapText('Accesibilidad', style: text.titleMedium)),
            const SizedBox(height: EbSpacing.s),
            for (final (icon, label, v) in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: EbSpacing.xs),
                child: Semantics(
                  label: '$label: ${valor(v)}',
                  excludeSemantics: true,
                  // Nombre y valor en la misma línea si caben; si no, el valor baja
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: EbSpacing.s,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: v == true ? EbColors.bankInk : EbColors.textMuted),
                            const SizedBox(width: EbSpacing.s),
                            Text(label, style: text.bodyLarge),
                          ],
                        ),
                        Text(
                          valor(v),
                          style: text.bodyMedium?.copyWith(
                            color: v == null ? EbColors.textMuted : EbColors.textPrimary,
                            fontWeight: v == null ? FontWeight.w400 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: EbColors.white, borderRadius: BorderRadius.circular(EbRadius.card)),
      child: Padding(
        padding: const EdgeInsets.all(EbSpacing.s + 4),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, color: EbColors.textMuted, size: 20)),
            const SizedBox(width: EbSpacing.s),
            Expanded(
              child: EbWrapText(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: EbColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error dentro de la pantalla (el encabezado y "Cómo llegar" siguen disponibles).
class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.offline, required this.onRetry});

  final String error;
  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EbSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded, color: EbColors.textMuted),
                const SizedBox(width: EbSpacing.s),
                Expanded(
                  child: EbWrapText('No se pudieron cargar las rutas y los zarpes', style: text.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: EbSpacing.xs),
            EbWrapText(error, style: text.bodyMedium?.copyWith(color: EbColors.textMuted)),
            const SizedBox(height: EbSpacing.s),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton con la forma de las tarjetas de ruta.
class _RoutesSkeleton extends StatelessWidget {
  const _RoutesSkeleton();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Skeletonizer(
      enabled: true,
      effect: const ShimmerEffect(
        baseColor: EbColors.skeleton,
        highlightColor: EbColors.surface,
        duration: Duration(milliseconds: 1200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rutas y próximos zarpes', style: text.titleLarge),
          Text('Horarios programados', style: text.bodySmall),
          const SizedBox(height: EbSpacing.s),
          for (var i = 0; i < 2; i++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(EbSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BS-1 · Ruta de ejemplo', style: text.titleMedium),
                    Text('Parada 2 de 5 · hacia Embarcadero Sur', style: text.bodyMedium),
                    const SizedBox(height: EbSpacing.xs),
                    Text('BS-1 · Hacia Embarcadero Sur   07:30 · en 27 min', style: text.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: EbSpacing.s),
          ],
        ],
      ),
    );
  }
}
