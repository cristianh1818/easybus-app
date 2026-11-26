// Panel "¿A dónde quieres ir hoy?" sobre el mapa: Desde · Hacia y la propuesta
// (dónde subir, sentido, dónde bajar, próxima salida y llegada estimada). La
// propuesta se calcula en el teléfono (domain/propuesta_viaje.dart); la próxima
// salida usa la API y, sin conexión, el cálculo local con la caché.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../domain/cercanos.dart' show formatoDistancia;
import '../domain/propuesta_viaje.dart';
import '../models/proxima_salida.dart';
import '../providers/clock_provider.dart';
import '../providers/data_providers.dart';
import '../repositories/fetched.dart';
import '../theme/eb_tokens.dart';
import '../utils/time_format.dart';
import 'eb_wrap_text.dart';

class EbTripPanel extends StatelessWidget {
  const EbTripPanel({
    super.key,
    required this.from,
    required this.to,
    required this.propuesta,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSwap,
    required this.onClose,
    required this.onOpenRoute,
    this.loading = false,
  });

  final PuntoViaje? from;
  final PuntoViaje? to;
  final PropuestaViaje? propuesta;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onSwap;
  final VoidCallback onClose;
  final ValueChanged<PropuestaViaje> onOpenRoute;

  /// Todavía se están leyendo las rutas.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: EbColors.textMuted);
    final p = propuesta;

    return Material(
      color: EbColors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(EbRadius.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(EbSpacing.m, EbSpacing.xs, EbSpacing.xs, EbSpacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('¿A dónde quieres ir hoy?', style: text.titleMedium),
                  ),
                ),
                IconButton(
                  tooltip: 'Intercambiar origen y destino',
                  onPressed: from != null && to != null ? onSwap : null,
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
                IconButton(tooltip: 'Cerrar', onPressed: onClose, icon: const Icon(Icons.close_rounded)),
              ],
            ),
            _EndpointField(
              icon: Icons.trip_origin_rounded,
              label: 'Desde',
              value: from?.nombre,
              hint: 'Tu ubicación o un embarcadero',
              onTap: onPickFrom,
            ),
            const SizedBox(height: EbSpacing.xs),
            _EndpointField(
              icon: Icons.location_on_rounded,
              label: 'Hacia',
              value: to?.nombre,
              hint: 'Toca el mapa o elige un embarcadero',
              onTap: onPickTo,
            ),
            const SizedBox(height: EbSpacing.s),
            Padding(
              padding: const EdgeInsets.only(right: EbSpacing.s),
              child: switch ((from, to, p)) {
                (null, _, _) || (_, null, _) => Text(
                  'Elige de dónde sales y a dónde vas: te diremos dónde subir, dónde bajar y a qué hora '
                  'llegas.',
                  style: muted,
                ),
                _ when loading => const Skeletonizer(child: Text('Subir en el embarcadero de ejemplo')),
                (_, _, null) => EbWrapText(
                  'No encontramos un viaje en embarcación para ese recorrido (por ejemplo, si sales y '
                  'llegas al mismo embarcadero).',
                  style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
                ),
                (_, _, final p?) => _Proposal(propuesta: p, onOpenRoute: () => onOpenRoute(p)),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointField extends StatelessWidget {
  const _EndpointField({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(right: EbSpacing.s),
      child: Semantics(
        button: true,
        label: '$label: ${value ?? hint}. Toca para cambiar',
        excludeSemantics: true,
        child: Material(
          color: EbColors.surface,
          borderRadius: BorderRadius.circular(EbRadius.card - EbSpacing.xs),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(EbRadius.card - EbSpacing.xs),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: EbSizes.minTouch),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: EbSpacing.s + 4, vertical: EbSpacing.xs),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: EbColors.riverInk),
                    const SizedBox(width: EbSpacing.s),
                    Text('$label  ', style: text.labelLarge?.copyWith(color: EbColors.textMuted)),
                    Expanded(
                      child: Text(
                        value ?? hint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: value == null
                            ? text.bodyMedium?.copyWith(color: EbColors.textMuted)
                            : text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.expand_more_rounded, color: EbColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La propuesta: subir, sentido, bajar, próxima salida y llegada.
class _Proposal extends ConsumerWidget {
  const _Proposal({required this.propuesta, required this.onOpenRoute});

  final PropuestaViaje propuesta;
  final VoidCallback onOpenRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = propuesta;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: EbColors.textMuted);
    final args = (
      rutaId: p.ruta.ruta.id,
      sentido: p.sentido.sentido,
      desdeEmbarcaderoId: p.subida.embarcadero.id,
    );
    final value = ref.watch(proximaSalidaProvider(args));
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();

    String caminar(double m, int min) => m < 30 ? '' : ' · ${formatoDistancia(m)} a pie (~$min min)';

    // Próxima salida desde la subida y llegada a la bajada
    final (String salida, String? llegada) = switch (value) {
      AsyncValue(hasValue: true) => _describe(value.requireValue, p, now),
      AsyncValue(hasError: true) => ('No se pudo calcular la próxima salida', null),
      _ => ('07:30 · en 15 min', '08:00'),
    };
    final loading = !value.hasValue && !value.hasError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Step(
          icon: Icons.login_rounded,
          title: 'Sube en ${p.subida.embarcadero.nombre}',
          detail:
              '${p.ruta.ruta.codigo} hacia ${p.sentido.destino}'
              '${caminar(p.metrosHastaSubida, p.minutosCaminandoHastaSubida)}',
        ),
        _Step(
          icon: Icons.logout_rounded,
          title: 'Baja en ${p.bajada.embarcadero.nombre}',
          detail:
              '${p.minutosEnEmbarcacion} min en la embarcación'
              '${caminar(p.metrosDesdeBajada, p.minutosCaminandoDesdeBajada)}',
        ),
        const SizedBox(height: EbSpacing.xs),
        Skeletonizer(
          enabled: loading,
          child: Wrap(
            spacing: EbSpacing.m,
            runSpacing: EbSpacing.xs,
            children: [
              _Figure(label: 'Próxima salida', value: salida),
              if (llegada != null) _Figure(label: 'Llegada estimada', value: llegada),
            ],
          ),
        ),
        const SizedBox(height: EbSpacing.xs),
        Text(
          value.value?.origin == DataOrigin.cache
              ? 'Calculado en tu teléfono, sin conexión. Horario programado.'
              : 'Horario programado, no ubicación en tiempo real. Distancias en línea recta.',
          style: muted,
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpenRoute,
            icon: const Icon(Icons.timeline_rounded),
            label: const Text('Ver recorrido y horarios'),
          ),
        ),
      ],
    );
  }

  static (String, String?) _describe(Fetched<ProximaSalida> f, PropuestaViaje p, DateTime now) {
    final s = f.data;
    final llegada = horaLlegada(s, p.bajada);
    switch (s.status) {
      case DepartureStatus.nextDeparture:
        final elapsed = now.difference(f.updatedAt).inMinutes;
        final remaining = (s.minutesRemaining ?? 0) - (elapsed < 0 ? 0 : elapsed);
        return ('${s.departureTime} · ${formatInMinutes(remaining < 0 ? 0 : remaining)}', llegada?.hora);
      case DepartureStatus.noMoreDeparturesToday:
        final next = s.nextDayFirstDeparture;
        return (
          next == null ? 'Sin más salidas hoy' : 'Sin más hoy · mañana ${next.departureTime}',
          llegada == null ? null : 'mañana ${llegada.hora}',
        );
      case DepartureStatus.suspended:
        return ('Servicio suspendido', null);
      case DepartureStatus.outOfService:
        return ('Fuera de servicio', null);
      case DepartureStatus.unknown:
        return (s.message, null);
    }
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$title. $detail',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EbSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: EbColors.riverInk),
            const SizedBox(width: EbSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EbWrapText(title, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                  EbWrapText(detail, style: text.bodySmall?.copyWith(color: EbColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: text.labelMedium?.copyWith(color: EbColors.textMuted)),
          Text(
            value,
            style: text.titleMedium?.copyWith(color: EbColors.riverInk, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Hoja para elegir el origen o el destino: opción especial arriba (mi ubicación /
/// tocar el mapa) y los embarcaderos en el orden del río.
Future<T?> showTripEndpointPicker<T>(
  BuildContext context, {
  required String title,
  required ({IconData icon, String label, T value})? special,
  required List<({String nombre, String? detalle, bool cerrado, T value})> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: EbColors.white,
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(EbRadius.sheet)),
    ),
    builder: (sheetContext) {
      final text = Theme.of(sheetContext).textTheme;
      return ListView(
        shrinkWrap: true,
        // Hasta el borde inferior: se suma la barra de navegación del sistema
        padding: EdgeInsets.only(bottom: EbSpacing.m + MediaQuery.paddingOf(sheetContext).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(EbSpacing.l, 0, EbSpacing.l, EbSpacing.s),
            child: Semantics(header: true, child: Text(title, style: text.titleLarge)),
          ),
          if (special != null)
            ListTile(
              leading: Icon(special.icon, color: EbColors.riverInk),
              title: Text(special.label, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.of(sheetContext).pop(special.value),
            ),
          if (special != null) const Divider(),
          for (final o in options)
            ListTile(
              leading: Icon(
                Icons.directions_boat_filled_rounded,
                color: o.cerrado ? EbColors.textMuted : EbColors.river,
              ),
              title: Text(o.nombre),
              subtitle: o.detalle == null ? null : Text(o.detalle!),
              onTap: () => Navigator.of(sheetContext).pop(o.value),
            ),
        ],
      );
    },
  );
}
