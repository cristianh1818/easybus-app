// Próximo zarpe de una ruta, en un sentido, desde un embarcadero:
// "BS-1 · Hacia Embarcadero Sur      07:20 · en 15 min".
// Descuenta los minutos con el reloj (clockProvider) y vuelve a consultar cuando la
// salida ya pasó. Siempre es horario programado, no tiempo real.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../models/proxima_salida.dart';
import '../providers/clock_provider.dart';
import '../providers/data_providers.dart';
import '../providers/piers_providers.dart';
import '../theme/eb_tokens.dart';
import '../utils/time_format.dart';

class EbNextDepartureRow extends ConsumerWidget {
  const EbNextDepartureRow({super.key, required this.service, required this.embarcaderoId});

  final PierService service;
  final String embarcaderoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (rutaId: service.rutaId, sentido: service.sentido, desdeEmbarcaderoId: embarcaderoId);
    final value = ref.watch(proximaSalidaProvider(args));
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();

    final (String detail, Color color, bool strong) = switch (value) {
      AsyncValue(hasValue: true) => _describe(value.requireValue.data, value.requireValue.updatedAt, now, () {
        // La salida ya pasó: se consulta la siguiente (después de este cuadro)
        WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidate(proximaSalidaProvider(args)));
      }),
      AsyncValue(hasError: true) => ('No se pudo calcular', EbColors.textMuted, false),
      _ => ('00:00 · en 00 min', EbColors.textMuted, false),
    };
    final loading = !value.hasValue && !value.hasError;

    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '${service.rutaCodigo}, hacia ${service.destino}: $detail',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EbSpacing.xs),
        child: Wrap(
          spacing: EbSpacing.s,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${service.rutaCodigo} · ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: 'Hacia ${service.destino}'),
                ],
              ),
              style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
            ),
            Skeletonizer(
              enabled: loading,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : EbDurations.normal,
                child: Text(
                  detail,
                  key: ValueKey(detail),
                  style: text.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (String, Color, bool) _describe(
    ProximaSalida p,
    DateTime fetchedAt,
    DateTime now,
    VoidCallback onDeparted,
  ) {
    switch (p.status) {
      case DepartureStatus.nextDeparture:
        final elapsed = now.difference(fetchedAt).inMinutes;
        final remaining = (p.minutesRemaining ?? 0) - (elapsed < 0 ? 0 : elapsed);
        if (remaining < 0) {
          onDeparted();
          return ('Actualizando…', EbColors.textMuted, false);
        }
        return ('${p.departureTime} · ${formatInMinutes(remaining)}', EbColors.riverInk, true);
      case DepartureStatus.noMoreDeparturesToday:
        final next = p.nextDayFirstDeparture;
        if (next == null) return ('Sin más salidas hoy', EbColors.textMuted, false);
        final isTomorrow = DateTime.parse(next.date).difference(DateTime.parse(p.localDate)).inDays == 1;
        return (
          'Sin más salidas hoy · ${isTomorrow ? 'mañana' : next.date} ${next.departureTime}',
          EbColors.textMuted,
          false,
        );
      case DepartureStatus.suspended:
        return ('Suspendido', EbColors.alertSuspended, true);
      case DepartureStatus.outOfService:
        return ('Fuera de servicio', EbColors.alertSuspended, true);
      case DepartureStatus.unknown:
        return (p.message, EbColors.textMuted, false);
    }
  }
}
