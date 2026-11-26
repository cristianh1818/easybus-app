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
import '../repositories/fetched.dart';
import '../theme/eb_tokens.dart';
import '../utils/time_format.dart';

class EbNextDepartureRow extends ConsumerWidget {
  const EbNextDepartureRow({super.key, required this.service, required this.embarcaderoId, this.label});

  /// Desde cuántos minutos antes de zarpar el chip late.
  static const soonMinutes = 5;

  final PierService service;
  final String embarcaderoId;

  /// Texto a la izquierda. Por defecto "BS-1 · Hacia …"; en el detalle, donde la
  /// ruta y el destino ya están en el encabezado, "Próximo zarpe".
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (rutaId: service.rutaId, sentido: service.sentido, desdeEmbarcaderoId: embarcaderoId);
    final value = ref.watch(proximaSalidaProvider(args));
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();

    final (String detail, Color color, bool strong, bool soon) = switch (value) {
      AsyncValue(hasValue: true) => _describe(value.requireValue.data, value.requireValue.updatedAt, now, () {
        // La salida ya pasó: se consulta la siguiente (después de este cuadro)
        WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidate(proximaSalidaProvider(args)));
      }),
      AsyncValue(hasError: true) => ('No se pudo calcular', EbColors.textMuted, false, false),
      _ => ('00:00 · en 00 min', EbColors.textMuted, false, false),
    };
    final loading = !value.hasValue && !value.hasError;
    // Sin conexión: calculada en el teléfono con los horarios guardados
    final local = value.value?.origin == DataOrigin.cache;
    const localNote = 'Calculado en tu teléfono, sin conexión';

    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      label: '${service.rutaCodigo}, hacia ${service.destino}: $detail${local ? '. $localNote' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: EbSpacing.xs),
        child: Wrap(
          spacing: EbSpacing.s,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            if (label != null)
              Text(label!, style: text.bodyMedium?.copyWith(color: EbColors.textMuted))
            else
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
                // Faltan 5 min o menos: el chip late suave (sin "reducir movimiento")
                child: EbSoonPulse(
                  key: ValueKey(detail),
                  active: soon,
                  child: Text(
                    detail,
                    style: text.bodyMedium?.copyWith(
                      color: color,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            if (local) Text(localNote, style: text.bodySmall?.copyWith(color: EbColors.textMuted)),
          ],
        ),
      ),
    );
  }

  static (String, Color, bool, bool) _describe(
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
          return ('Actualizando…', EbColors.textMuted, false, false);
        }
        return (
          '${p.departureTime} · ${formatInMinutes(remaining)}',
          EbColors.riverInk,
          true,
          remaining <= soonMinutes,
        );
      case DepartureStatus.noMoreDeparturesToday:
        final next = p.nextDayFirstDeparture;
        if (next == null) return ('Sin más salidas hoy', EbColors.textMuted, false, false);
        final isTomorrow = DateTime.parse(next.date).difference(DateTime.parse(p.localDate)).inDays == 1;
        return (
          'Sin más salidas hoy · ${isTomorrow ? 'mañana' : next.date} ${next.departureTime}',
          EbColors.textMuted,
          false,
          false,
        );
      case DepartureStatus.suspended:
        return ('Suspendido', EbColors.alertSuspended, true, false);
      case DepartureStatus.outOfService:
        return ('Fuera de servicio', EbColors.alertSuspended, true, false);
      case DepartureStatus.unknown:
        return (p.message, EbColors.textMuted, false, false);
    }
  }
}

/// Chip que late suave (escala 1 → 1,06 y fondo que aparece y se va, 1,6 s por
/// ciclo, menos de 1 vez por segundo) para avisar que la embarcación sale pronto.
/// Con "reducir movimiento" el chip queda resaltado y quieto. El texto dice igual
/// "en X min": la información no depende de la animación.
class EbSoonPulse extends StatefulWidget {
  const EbSoonPulse({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<EbSoonPulse> createState() => _EbSoonPulseState();
}

class _EbSoonPulseState extends State<EbSoonPulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EbSoonPulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!animate && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final still = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = still ? 1.0 : Curves.easeInOutSine.transform(_c.value);
          return Transform.scale(
            scale: 1 + 0.06 * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: EbColors.riverTint.withValues(alpha: 0.5 + 0.5 * t),
                borderRadius: BorderRadius.circular(EbRadius.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: EbSpacing.s, vertical: 2),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
