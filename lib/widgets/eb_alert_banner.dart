// Banner de aviso de servicio (skill easybus-ui: los avisos van antes que los
// horarios). Entra deslizando desde arriba; si es una suspensión, el ícono vibra una
// sola vez. Con "reducir movimiento" aparece sin animación. Nunca depende solo del
// color o del movimiento: siempre lleva el tipo en texto.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/aviso.dart';
import '../models/enums.dart';
import '../theme/eb_tokens.dart';
import '../utils/time_format.dart';
import 'eb_wrap_text.dart';

@immutable
class _AlertStyle {
  const _AlertStyle(this.label, this.icon, this.color, this.ink, this.tint);

  final String label;
  final IconData icon;

  /// Ícono y borde.
  final Color color;

  /// Texto (contraste ≥ 4.5:1 sobre [tint]).
  final Color ink;
  final Color tint;
}

const _styles = {
  TipoAviso.suspendido: _AlertStyle(
    'Servicio suspendido',
    Icons.do_not_disturb_on_outlined,
    EbColors.alertSuspended,
    EbColors.alertSuspended,
    EbColors.alertSuspendedTint,
  ),
  TipoAviso.retraso: _AlertStyle(
    'Retraso',
    Icons.schedule_rounded,
    EbColors.alertDelay,
    EbColors.alertDelayInk,
    EbColors.alertDelayTint,
  ),
  TipoAviso.cambioHorario: _AlertStyle(
    'Cambio de horario',
    Icons.update_rounded,
    EbColors.alertInfo,
    EbColors.alertInfo,
    EbColors.alertInfoTint,
  ),
  TipoAviso.informativo: _AlertStyle(
    'Aviso',
    Icons.info_outline_rounded,
    EbColors.alertInfo,
    EbColors.alertInfo,
    EbColors.alertInfoTint,
  ),
};

/// Orden de importancia: suspensiones primero.
int compareAvisos(Aviso a, Aviso b) => a.tipo.index.compareTo(b.tipo.index);

String _scope(Aviso a) => switch (a.alcance) {
  AlcanceAviso.general => 'Todo el servicio',
  AlcanceAviso.ruta => 'Ruta ${a.ruta?.codigo ?? ''}'.trim(),
  AlcanceAviso.embarcadero => a.embarcadero?.nombre ?? 'Un embarcadero',
  AlcanceAviso.rutaEmbarcadero => [
    if (a.ruta != null) 'Ruta ${a.ruta!.codigo}',
    if (a.embarcadero != null) a.embarcadero!.nombre,
  ].join(' · '),
};

class EbAlertBanner extends StatelessWidget {
  const EbAlertBanner({super.key, required this.aviso});

  final Aviso aviso;

  @override
  Widget build(BuildContext context) {
    final style = _styles[aviso.tipo]!;
    final text = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final until = aviso.vigenteHasta == null
        ? 'Sin fecha de finalización'
        : 'Hasta el ${formatShortDateTime(aviso.vigenteHasta!)}';

    final banner = Semantics(
      container: true,
      liveRegion: aviso.esSuspension,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.tint,
          borderRadius: BorderRadius.circular(EbRadius.card),
          border: Border(left: BorderSide(color: style.color, width: 5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(EbSpacing.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: _ShakeOnce(
                  enabled: aviso.esSuspension && !reduceMotion,
                  child: Icon(style.icon, color: style.color, size: 28),
                ),
              ),
              const SizedBox(width: EbSpacing.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${style.label} · ${_scope(aviso)}',
                      style: text.labelMedium?.copyWith(color: style.ink, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    EbWrapText(aviso.titulo, style: text.titleMedium?.copyWith(color: EbColors.textPrimary)),
                    const SizedBox(height: EbSpacing.xs),
                    EbWrapText(aviso.mensaje, style: text.bodyMedium?.copyWith(color: EbColors.textPrimary)),
                    const SizedBox(height: EbSpacing.xs),
                    Text(until, style: text.bodySmall?.copyWith(color: EbColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (reduceMotion) return banner;
    // Entra deslizando desde arriba (solo transform y opacidad)
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: EbDurations.normal,
      curve: EbCurves.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, -12 * (1 - t)), child: child),
      ),
      child: banner,
    );
  }
}

/// Vibra una sola vez (no en bucle) al aparecer.
class _ShakeOnce extends StatelessWidget {
  const _ShakeOnce({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      builder: (context, t, child) {
        // Tres oscilaciones que se apagan: ±8° → 0
        final angle = math.sin(t * math.pi * 6) * (1 - t) * 8 * math.pi / 180;
        return Transform.rotate(angle: angle, child: child);
      },
      child: child,
    );
  }
}
