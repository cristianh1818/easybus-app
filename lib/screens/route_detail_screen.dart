// Detalle de la ruta (pantalla insignia, skill easybus-ui): avisos primero, el
// trazado sobre el río, selector de sentido, próxima salida, horarios del día y la
// LÍNEA DEL RÍO: los embarcaderos como estaciones sobre una línea vertical ondulada,
// en orden, con su margen y la hora estimada de paso (salida del origen + minutos
// desde el origen).
//
// Todo sale del repository: sin conexión funciona con la ruta, los horarios y los
// festivos guardados en el teléfono (la próxima salida se calcula localmente).
//
// Se abre desde el chip de la ruta en el Mapa y desde el detalle del embarcadero.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../domain/pasos_ruta.dart';
import '../domain/proxima_salida_local.dart' show MomentoBogota;
import '../models/enums.dart';
import '../models/geo.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';
import '../providers/clock_provider.dart';
import '../providers/data_providers.dart';
import '../providers/errors.dart';
import '../providers/piers_providers.dart';
import '../repositories/fetched.dart';
import '../theme/eb_insets.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../utils/color_hex.dart';
import '../utils/time_format.dart';
import '../widgets/eb_async_view.dart';
import '../widgets/eb_avisos_section.dart';
import '../widgets/eb_next_departure_row.dart';
import '../widgets/eb_state_message.dart';
import '../widgets/eb_wrap_text.dart';
import '../widgets/map/eb_river_map.dart';
import 'pier_detail_screen.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({
    super.key,
    required this.rutaId,
    required this.codigo,
    this.initialSentido = Sentido.ida,
    this.highlightEmbarcaderoId,
  });

  final String rutaId;

  /// Se muestra de inmediato en la barra superior ("BS-1").
  final String codigo;
  final Sentido initialSentido;

  /// Embarcadero desde el que se abrió: se resalta en la línea del río.
  final String? highlightEmbarcaderoId;

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  late Sentido _sentido = widget.initialSentido;

  /// Tipo de día elegido para ver sus horarios. null = el de hoy.
  TipoDia? _tipoDia;

  /// Salida del origen elegida para la línea del río. null = la próxima.
  String? _salida;

  final _map = EbRiverMapController();

  Future<void> _refresh() async {
    ref
      ..invalidate(rutaDetalleProvider(widget.rutaId))
      ..invalidate(horariosProvider)
      ..invalidate(proximaSalidaProvider)
      ..invalidate(avisosProvider);
    try {
      await ref.read(rutaDetalleProvider(widget.rutaId).future);
    } on Object {
      // El error se muestra en la pantalla
    }
  }

  void _setSentido(Sentido s, RutaDetalle ruta) {
    if (s == _sentido) return;
    setState(() {
      _sentido = s;
      _salida = null;
    });
    final rs = ruta.sentido(s);
    if (rs != null) _map.fit(_points(rs));
  }

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(rutaDetalleProvider(widget.rutaId));

    return Scaffold(
      appBar: AppBar(title: EbWrapText('Ruta ${widget.codigo}', maxLines: 1)),
      body: RefreshIndicator(
        color: EbColors.river,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: context.ebScrollPadding(top: EbSpacing.s),
          children: [
            // Avisos antes que cualquier horario
            EbAvisosSection(rutaId: widget.rutaId),
            EbAsyncView<Fetched<RutaDetalle>>(
              value: detalle,
              skeleton: const _RouteSkeleton(),
              error: (error) =>
                  EbStateMessage.fromError(toApiException(error), what: 'la ruta', onRetry: _refresh),
              data: (fetched) => _body(context, fetched),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Fetched<RutaDetalle> fetched) {
    final ruta = fetched.data;
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: EbColors.textMuted);
    final mode = ruta.ruta.mode;
    final style = mode.style;
    final color = parseHexColor(ruta.ruta.color) ?? style.color;
    final sentidos = [...ruta.sentidos]..sort((a, b) => a.sentido.index.compareTo(b.sentido.index));
    final rs = ruta.sentido(_sentido) ?? (sentidos.isEmpty ? null : sentidos.first);
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();

    if (rs == null || rs.paradas.isEmpty) {
      return EbStateMessage(
        icon: style.icon,
        title: 'Esta ruta aún no tiene ${style.stopLabelPlural.toLowerCase()}',
        message: 'Cuando se publiquen aparecerán aquí.',
      );
    }
    final origen = rs.paradas.first;
    final proxima = ref
        .watch(proximaSalidaProvider((rutaId: ruta.ruta.id, sentido: rs.sentido, desdeEmbarcaderoId: null)))
        .value
        ?.data;
    final horarios = ref.watch(horariosProvider((rutaId: ruta.ruta.id, sentido: rs.sentido, tipoDia: null)));
    final hoy = proxima == null ? null : tipoDiaDe[proxima.dayType];
    final tipoDia = _tipoDia ?? hoy ?? TipoDia.laboral;
    final salidas = horarios.value == null
        ? const <String>[]
        : salidasDelDia(horarios.value!.data.horarios, tipoDia);
    final esHoy = _tipoDia == null || _tipoDia == hoy;
    // Salida que se usa en la línea del río: la elegida, o la próxima de hoy, o la primera
    final proximaOrigen = proxima?.status == DepartureStatus.nextDeparture
        ? proxima?.originDepartureTime
        : null;
    final salida = _salida ?? (esHoy ? proximaOrigen : null) ?? (salidas.isEmpty ? null : salidas.first);
    final ahora = MomentoBogota(now).hora;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: EbWrapText('${ruta.ruta.codigo} · ${ruta.ruta.nombre}', style: text.headlineSmall),
        ),
        if (ruta.ruta.descripcion != null) ...[
          const SizedBox(height: EbSpacing.xs),
          EbWrapText(ruta.ruta.descripcion!, style: text.bodyMedium?.copyWith(color: EbColors.textMuted)),
        ],
        const SizedBox(height: EbSpacing.xs),
        Text(formatUpdatedAgo(fetched.updatedAt, now), style: muted),
        if (fetched.refreshError != null) ...[
          const SizedBox(height: EbSpacing.s),
          _Note(
            icon: fetched.refreshError!.isOffline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
            text: fetched.refreshError!.isOffline
                ? 'Sin conexión a internet. Estás viendo los datos guardados en tu teléfono.'
                : 'El servicio no está disponible en este momento. Estás viendo los datos guardados en tu teléfono.',
          ),
        ],
        const SizedBox(height: EbSpacing.m),
        // Sentido
        if (sentidos.length > 1)
          SegmentedButton<Sentido>(
            segments: [
              for (final s in sentidos)
                ButtonSegment(
                  value: s.sentido,
                  // Texto simple: SegmentedButton mide su contenido (EbWrapText no lo permite)
                  label: Text('Hacia ${s.destino}', maxLines: 2, textAlign: TextAlign.center),
                ),
            ],
            selected: {rs.sentido},
            showSelectedIcon: false,
            onSelectionChanged: (v) => _setSentido(v.first, ruta),
          ),
        const SizedBox(height: EbSpacing.m),
        // Trazado sobre el río
        ClipRRect(
          borderRadius: BorderRadius.circular(EbRadius.card),
          child: SizedBox(
            height: 220,
            child: EbRiverMap(
              controller: _map,
              fitPadding: const EdgeInsets.all(EbSpacing.l),
              markers: [
                for (final p in rs.paradas)
                  EbMapMarker(
                    id: p.embarcadero.id,
                    point: p.embarcadero.ubicacion,
                    color: color,
                    icon: style.icon,
                    muted: p.embarcadero.estaCerrado,
                    semanticLabel: '${style.stopLabel} ${p.embarcadero.nombre}',
                  ),
              ],
              lines: const [],
              selectedLine: EbMapLine(
                id: '${ruta.ruta.id}-${rs.sentido.name}',
                points: _points(rs),
                color: color,
              ),
              selectedMarkerId: widget.highlightEmbarcaderoId,
              onMarkerTap: (id) => _openPier(rs.paradas.firstWhere((p) => p.embarcadero.id == id)),
            ),
          ),
        ),
        const SizedBox(height: EbSpacing.m),
        // Próxima salida desde el origen
        Card(
          child: Padding(
            padding: const EdgeInsets.all(EbSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EbWrapText('Próxima salida desde ${origen.embarcadero.nombre}', style: text.titleMedium),
                EbNextDepartureRow(
                  service: PierService(
                    rutaId: ruta.ruta.id,
                    rutaCodigo: ruta.ruta.codigo,
                    sentido: rs.sentido,
                    destino: rs.destino,
                    orden: 1,
                  ),
                  embarcaderoId: origen.embarcadero.id,
                  label: 'Sale',
                ),
                Text('Horario programado, no ubicación en tiempo real.', style: muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: EbSpacing.m),
        // Horarios del día
        Semantics(header: true, child: EbWrapText('Horarios', style: text.titleLarge)),
        const SizedBox(height: EbSpacing.xs),
        Wrap(
          spacing: EbSpacing.xs,
          runSpacing: EbSpacing.xs,
          children: [
            for (final t in TipoDia.values)
              ChoiceChip(
                label: Text(t == hoy ? '${nombreTipoDia(t)} (hoy)' : nombreTipoDia(t)),
                selected: t == tipoDia,
                onSelected: (_) => setState(() {
                  _tipoDia = t;
                  _salida = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: EbSpacing.s),
        Text(
          'Salidas desde ${origen.embarcadero.nombre}. Toca una para ver la hora en cada parada.',
          style: muted,
        ),
        const SizedBox(height: EbSpacing.s),
        if (horarios.hasError && !horarios.hasValue)
          EbWrapText(
            toApiException(horarios.error!).message,
            style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
          )
        else if (!horarios.hasValue)
          const Skeletonizer(child: Text('05:30 · 06:00 · 06:30 · 07:00 · 07:30'))
        else if (salidas.isEmpty)
          EbWrapText(
            'No hay salidas programadas ${tipoDia == TipoDia.laboral ? 'de lunes a viernes' : 'este día'}.',
            style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
          )
        else
          _DeparturesGrid(
            salidas: salidas,
            selected: salida,
            // Solo hoy se atenúan las que ya salieron
            pasadas: esHoy ? (h) => h.compareTo(ahora) < 0 : (_) => false,
            onSelect: (h) => setState(() => _salida = h),
          ),
        const SizedBox(height: EbSpacing.l),
        // La línea del río
        Semantics(header: true, child: EbWrapText('Recorrido', style: text.titleLarge)),
        const SizedBox(height: EbSpacing.xs),
        EbWrapText(
          salida == null
              ? 'Embarcaderos en orden de paso hacia ${rs.destino}.'
              : 'Hora estimada de paso para la salida de las $salida desde ${origen.embarcadero.nombre}.',
          style: muted,
        ),
        if (rs.paradas.any((p) => p.tiempoEstimado))
          Text('Tiempos estimados con el trazado, aún sin medir en un viaje real.', style: muted),
        const SizedBox(height: EbSpacing.s),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: EbSpacing.s),
            child: EbRiverLine(
              sentido: rs,
              salida: salida,
              color: color,
              highlightId: widget.highlightEmbarcaderoId,
              onTap: _openPier,
            ),
          ),
        ),
      ],
    );
  }

  // Trazado del sentido; si aún no está dibujado, la línea que une sus embarcaderos
  List<GeoPoint> _points(RutaSentido rs) => (rs.trazado != null && rs.trazado!.length >= 2)
      ? rs.trazado!
      : [for (final p in rs.paradas) p.embarcadero.ubicacion];

  void _openPier(ParadaEnRuta p) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => PierDetailScreen(embarcadero: p.embarcadero)));
}

/// Cuadrícula de horas de salida; la elegida resaltada y las que ya pasaron, atenuadas.
class _DeparturesGrid extends StatelessWidget {
  const _DeparturesGrid({
    required this.salidas,
    required this.selected,
    required this.pasadas,
    required this.onSelect,
  });

  final List<String> salidas;
  final String? selected;
  final bool Function(String) pasadas;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: EbSpacing.xs,
      runSpacing: EbSpacing.xs,
      children: [
        for (final h in salidas)
          Semantics(
            button: true,
            selected: h == selected,
            label: 'Salida de las $h${pasadas(h) ? ', ya salió' : ''}',
            excludeSemantics: true,
            child: Material(
              color: h == selected ? EbColors.navy : EbColors.white,
              borderRadius: BorderRadius.circular(EbRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(EbRadius.pill),
                onTap: () => onSelect(h),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: EbSizes.minTouch, minWidth: 72),
                  child: Center(
                    widthFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: EbSpacing.s),
                      child: Text(
                        h,
                        style: text.labelLarge?.copyWith(
                          color: h == selected
                              ? EbColors.white
                              : pasadas(h)
                              ? EbColors.textMuted
                              : EbColors.textPrimary,
                          decoration: pasadas(h) && h != selected ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Línea del río (elemento firma): estaciones sobre una línea vertical ondulada, en
/// orden, con la margen, los minutos desde el origen y la hora estimada de paso.
class EbRiverLine extends StatelessWidget {
  const EbRiverLine({
    super.key,
    required this.sentido,
    required this.salida,
    required this.color,
    this.highlightId,
    this.onTap,
  });

  final RutaSentido sentido;

  /// Salida del origen ("HH:MM") para calcular la hora en cada parada. null = sin horas.
  final String? salida;
  final Color color;
  final String? highlightId;
  final ValueChanged<ParadaEnRuta>? onTap;

  @override
  Widget build(BuildContext context) {
    final pasos = salida == null ? null : pasosDeSalida(sentido, salida!);
    final paradas = sentido.paradas;
    return Column(
      children: [
        for (final (i, p) in paradas.indexed)
          _Station(
            parada: p,
            hora: pasos?[i].hora,
            first: i == 0,
            last: i == paradas.length - 1,
            color: color,
            highlighted: p.embarcadero.id == highlightId,
            onTap: onTap == null ? null : () => onTap!(p),
          ),
      ],
    );
  }
}

class _Station extends StatelessWidget {
  const _Station({
    required this.parada,
    required this.hora,
    required this.first,
    required this.last,
    required this.color,
    required this.highlighted,
    this.onTap,
  });

  final ParadaEnRuta parada;
  final String? hora;
  final bool first;
  final bool last;
  final Color color;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = parada.embarcadero;
    final margen = switch (e.margen) {
      Margen.izquierda => 'Margen izquierda',
      Margen.derecha => 'Margen derecha',
      null => null,
    };
    final detalle = [
      if (first) 'Origen' else if (last) 'Destino' else '+${parada.minutosDesdeOrigen} min',
      ?margen,
      if (e.estaCerrado) 'Cerrado temporalmente',
    ].join(' · ');
    final cuando = hora == null ? null : (last ? 'llega $hora' : (first ? 'sale $hora' : 'pasa $hora'));

    return Semantics(
      button: onTap != null,
      label:
          'Parada ${parada.orden}, ${e.nombre}. $detalle${cuando == null ? '' : '. ${cuando.replaceFirst(' ', ' a las ')}'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        // La línea se pinta detrás, a todo el alto de la fila (Stack, sin medir
        // intrínsecos: EbWrapText usa LayoutBuilder)
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _lineWidth,
              child: CustomPaint(
                painter: _WavePainter(
                  color: color,
                  first: first,
                  last: last,
                  big: first || last || highlighted,
                  closed: e.estaCerrado,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: _lineWidth),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: EbSpacing.s + 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          EbWrapText(
                            e.nombre,
                            style: (first || last || highlighted ? text.titleMedium : text.bodyLarge)
                                ?.copyWith(fontWeight: highlighted ? FontWeight.w700 : null),
                          ),
                          EbWrapText(
                            detalle,
                            style: text.bodySmall?.copyWith(
                              color: e.estaCerrado ? EbColors.alertSuspended : EbColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (cuando != null)
                    Padding(
                      padding: const EdgeInsets.only(left: EbSpacing.s, right: EbSpacing.m),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(hora!, style: text.titleMedium?.copyWith(color: EbColors.riverInk)),
                            Text(
                              cuando.split(' ').first,
                              style: text.labelSmall?.copyWith(color: EbColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: EbSpacing.m),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _lineWidth = 56.0;

/// Un tramo de la línea ondulada (un periodo completo por fila, así los tramos
/// empalman) con la estación en el centro.
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.color,
    required this.first,
    required this.last,
    required this.big,
    required this.closed,
  });

  final Color color;
  final bool first;
  final bool last;
  final bool big;
  final bool closed;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const amplitude = 5.0;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    final from = first ? cy : 0.0;
    final to = last ? cy : size.height;
    for (var y = from; y <= to; y += 1) {
      final x = cx + amplitude * math.sin(2 * math.pi * y / size.height);
      if (y == from) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
    final r = big ? 10.0 : 7.0;
    canvas
      ..drawCircle(Offset(cx, cy), r, Paint()..color = EbColors.white)
      ..drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = closed ? EbColors.textMuted : color
          ..style = PaintingStyle.stroke
          ..strokeWidth = big ? 4 : 3,
      );
    if (big) canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = closed ? EbColors.textMuted : color);
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color || old.first != first || old.last != last || old.big != big || old.closed != closed;
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

/// Skeleton con la forma real: título, selector, mapa y estaciones.
class _RouteSkeleton extends StatelessWidget {
  const _RouteSkeleton();

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
          Text('BS-1 · Ruta de ejemplo', style: text.headlineSmall),
          const SizedBox(height: EbSpacing.m),
          const Bone(height: 48, borderRadius: BorderRadius.all(Radius.circular(EbRadius.pill))),
          const SizedBox(height: EbSpacing.m),
          const Bone(height: 220, borderRadius: BorderRadius.all(Radius.circular(EbRadius.card))),
          const SizedBox(height: EbSpacing.m),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: EbSpacing.s),
              child: Text('Embarcadero de ejemplo · +10 min', style: text.bodyLarge),
            ),
        ],
      ),
    );
  }
}
