// Mapa del río (flutter_map + teselas de EbMapConfig). Es el ÚNICO widget que
// conoce el paquete de mapas: recibe y entrega GeoPoint, así que cambiar a Google
// Maps más adelante solo toca este archivo y config/map_config.dart.
//
// Movimiento (skill easybus-motion), todo desactivado con "reducir movimiento":
// - los marcadores aparecen en cascada, en el orden recibido (el del río), 40 ms
//   entre cada uno;
// - la ruta seleccionada se dibuja del origen al destino y luego unas flechas
//   recorren la línea en el sentido del viaje (es el sentido, NO una embarcación:
//   solo hay horarios programados);
// - la cámara se desplaza con suavidad (flutter_map_animations);
// - el marcador seleccionado tiene un pulso suave.
//
// Sin conexión, si las teselas no cargan, se ve un fondo neutro con las líneas y
// los marcadores igual (vienen de la caché del teléfono).

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../config/map_config.dart';
import '../../models/geo.dart';
import '../../theme/eb_tokens.dart';

/// Un embarcadero sobre el mapa.
@immutable
class EbMapMarker {
  const EbMapMarker({
    required this.id,
    required this.point,
    required this.color,
    required this.icon,
    required this.semanticLabel,
    this.muted = false,
  });

  final String id;
  final GeoPoint point;
  final Color color;
  final IconData icon;
  final String semanticLabel;

  /// Cerrado temporalmente: se dibuja en gris.
  final bool muted;
}

/// Una línea de ruta (en un sentido: del origen al destino).
@immutable
class EbMapLine {
  const EbMapLine({required this.id, required this.points, required this.color});

  /// Identifica la línea y su sentido: si cambia, la línea se vuelve a dibujar.
  final String id;
  final List<GeoPoint> points;
  final Color color;
}

/// Mueve la cámara del mapa desde la pantalla.
class EbRiverMapController {
  _EbRiverMapState? _state;

  /// Centra [point] en la zona visible por encima de [bottomInset] (p. ej. una hoja
  /// inferior), con al menos [minZoom].
  Future<void> focus(GeoPoint point, {double bottomInset = 0, double minZoom = 15.5}) async =>
      _state?._focus(point, bottomInset: bottomInset, minZoom: minZoom);

  /// Encuadra los puntos dejando libre [padding] (botones, píldora, hojas).
  Future<void> fit(List<GeoPoint> points, {EdgeInsets padding = const EdgeInsets.all(48)}) async =>
      _state?._fit(points, padding: padding);
}

class EbRiverMap extends StatefulWidget {
  const EbRiverMap({
    super.key,
    required this.controller,
    required this.markers,
    required this.lines,
    this.selectedLine,
    this.selectedMarkerId,
    this.onMarkerTap,
    this.onMapTap,
    this.fitPadding = const EdgeInsets.all(48),
    this.attributionPadding = EdgeInsets.zero,
    this.userLocation,
    this.userAccuracyM,
  });

  final EbRiverMapController controller;

  /// En el orden del río: así aparecen en cascada.
  final List<EbMapMarker> markers;

  /// Rutas sin seleccionar.
  final List<EbMapLine> lines;

  /// Ruta seleccionada: se dibuja animada y con el sentido del viaje.
  final EbMapLine? selectedLine;
  final String? selectedMarkerId;
  final ValueChanged<String>? onMarkerTap;
  final ValueChanged<GeoPoint>? onMapTap;

  /// Margen al encuadrar los embarcaderos la primera vez.
  final EdgeInsets fitPadding;

  /// Dónde va la atribución del mapa (abajo a la derecha, por encima de esto).
  final EdgeInsets attributionPadding;

  /// Ubicación del pasajero (punto azul), solo si la pidió con "Mi ubicación".
  final GeoPoint? userLocation;

  /// Precisión de [userLocation] en metros: círculo claro alrededor del punto.
  final double? userAccuracyM;

  @override
  State<EbRiverMap> createState() => _EbRiverMapState();
}

class _EbRiverMapState extends State<EbRiverMap> with TickerProviderStateMixin {
  static const _cameraDuration = Duration(milliseconds: 700);
  static const _markerStagger = Duration(milliseconds: 40);
  static const _markerEntry = Duration(milliseconds: 300);

  late final _camera = AnimatedMapController(
    vsync: this,
    duration: _cameraDuration,
    curve: Curves.easeInOutCubic,
    cancelPreviousAnimations: true,
  );
  late final _entry = AnimationController(vsync: this);
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  bool _mapReady = false;
  bool _fittedOnce = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _syncPulse();
  }

  @override
  void didUpdateWidget(EbRiverMap old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._state = null;
      widget.controller._state = this;
    }
    if (old.markers.isEmpty && widget.markers.isNotEmpty) {
      // Después del cuadro: mover la cámara durante el build no está permitido
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onFirstMarkers();
      });
    }
    _syncPulse();
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    _camera.dispose();
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    if (widget.markers.isNotEmpty) _onFirstMarkers();
  }

  /// Primera vez con datos: encuadra los embarcaderos (sin animar la cámara, para que
  /// la cascada se vea en su sitio) y los hace aparecer.
  void _onFirstMarkers() {
    if (!_mapReady || _fittedOnce) return;
    _fittedOnce = true;
    final points = _toLatLngs([for (final m in widget.markers) m.point]);
    if (points.length > 1) {
      final controller = _camera.mapController;
      final fitted = CameraFit.coordinates(
        coordinates: points,
        padding: widget.fitPadding,
        maxZoom: _maxSeparationZoom,
      ).fit(controller.camera);
      // Si con ese encuadre dos embarcaderos quedan encimados, se acerca más (aunque
      // algún extremo quede fuera de la pantalla). Los que estén aún más juntos se
      // separan al hacer zoom con los dedos.
      final zoom = math.max(fitted.zoom, math.min(_separationZoom(points, fitted.center.latitude), _maxSeparationZoom));
      controller.move(fitted.center, zoom);
    }
    if (_reduceMotion) {
      _entry.value = 1;
    } else {
      _entry.duration = _markerEntry + _markerStagger * (widget.markers.length - 1);
      _entry.forward(from: 0);
    }
  }

  /// Zoom máximo que se usa para separar embarcaderos al abrir el mapa.
  static const _maxSeparationZoom = 16.0;

  /// Distancia mínima en pantalla entre dos marcadores para que no se encimen.
  static const _minMarkerGapPx = _PierMarker.dot + 12;

  /// Zoom con el que los dos embarcaderos más cercanos quedan a [_minMarkerGapPx].
  static double _separationZoom(List<LatLng> points, double latitude) {
    const distance = Distance();
    var minMeters = double.infinity;
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final d = distance.as(LengthUnit.Meter, points[i], points[j]);
        if (d > 0 && d < minMeters) minMeters = d;
      }
    }
    if (minMeters == double.infinity) return 0;
    // Metros por píxel en Web Mercator: 156543.03 · cos(lat) / 2^zoom
    final metersPerPxAtZoom0 = 156543.03 * math.cos(latitude * math.pi / 180);
    return math.log(metersPerPxAtZoom0 * _minMarkerGapPx / minMeters) / math.ln2;
  }

  void _syncPulse() {
    final pulse = widget.selectedMarkerId != null && !_reduceMotion;
    if (pulse && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!pulse && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  Future<void> _focus(GeoPoint point, {required double bottomInset, required double minZoom}) async {
    if (!_mapReady) return;
    final camera = _camera.mapController.camera;
    final zoom = math.max(camera.zoom, minZoom);
    // El punto queda centrado en la parte visible, por encima de la hoja
    final projected = camera.projectAtZoom(_toLatLng(point), zoom);
    final center = camera.unprojectAtZoom(projected + Offset(0, bottomInset / 2), zoom);
    if (_reduceMotion) {
      _camera.mapController.move(center, zoom);
    } else {
      await _camera.animateTo(dest: center, zoom: zoom);
    }
  }

  Future<void> _fit(List<GeoPoint> points, {required EdgeInsets padding}) async {
    if (!_mapReady || points.isEmpty) return;
    final fit = CameraFit.coordinates(coordinates: _toLatLngs(points), padding: padding, maxZoom: 16.5);
    if (_reduceMotion) {
      _camera.mapController.fitCamera(fit);
    } else {
      await _camera.animatedFitCamera(cameraFit: fit);
    }
  }

  @override
  Widget build(BuildContext context) {
    const tiles = EbMapConfig.tiles;
    final selected = widget.selectedLine;
    final dimOthers = selected != null;

    return FlutterMap(
      mapController: _camera.mapController,
      options: MapOptions(
        initialCenter: _toLatLng(EbMapConfig.center),
        initialZoom: EbMapConfig.initialZoom,
        minZoom: EbMapConfig.minZoom,
        maxZoom: EbMapConfig.maxZoom,
        // Fondo neutro: es lo que se ve si las teselas no cargan (sin conexión)
        backgroundColor: EbColors.surface,
        // Sin rotación: el río siempre se ve igual y las flechas no confunden
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
        onMapReady: _onMapReady,
        onTap: widget.onMapTap == null
            ? null
            : (_, latLng) => widget.onMapTap!(GeoPoint(latLng.latitude, latLng.longitude)),
      ),
      children: [
        TileLayer(
          urlTemplate: tiles.urlTemplate,
          subdomains: tiles.subdomains,
          maxNativeZoom: tiles.maxNativeZoom,
          retinaMode: tiles.supportsRetina && RetinaMode.isHighDensity(context),
          userAgentPackageName: EbMapConfig.userAgentPackageName,
          tileDisplay: _reduceMotion ? const TileDisplay.instantaneous() : const TileDisplay.fadeIn(),
          // Sin conexión las teselas fallan: se deja el fondo neutro, sin llenar el registro
          errorTileCallback: (_, _, _) {},
        ),
        PolylineLayer(
          polylines: [
            for (final l in widget.lines)
              if (l.id != selected?.id)
                Polyline(
                  points: _toLatLngs(l.points),
                  color: l.color.withValues(alpha: dimOthers ? 0.35 : 0.9),
                  strokeWidth: 5,
                  borderStrokeWidth: 2,
                  borderColor: EbColors.white.withValues(alpha: dimOthers ? 0.4 : 0.9),
                ),
          ],
        ),
        if (selected != null)
          _SelectedRouteLayer(
            key: ValueKey(selected.id),
            points: _toLatLngs(selected.points),
            color: selected.color,
            reduceMotion: _reduceMotion,
          ),
        // Ubicación del pasajero: debajo de los embarcaderos para no taparlos
        if (widget.userLocation case final user?) ...[
          if ((widget.userAccuracyM ?? 0) > 0)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _toLatLng(user),
                  radius: widget.userAccuracyM!,
                  useRadiusInMeter: true,
                  color: EbColors.userLocation.withValues(alpha: 0.12),
                  borderColor: EbColors.userLocation.withValues(alpha: 0.35),
                  borderStrokeWidth: 1,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: _toLatLng(user),
                width: _UserDot.size,
                height: _UserDot.size,
                child: const _UserDot(),
              ),
            ],
          ),
        ],
        MarkerLayer(
          markers: [
            for (final (i, m) in widget.markers.indexed)
              Marker(
                point: _toLatLng(m.point),
                width: EbSizes.minTouch,
                height: EbSizes.minTouch,
                child: _PierMarker(
                  marker: m,
                  selected: m.id == widget.selectedMarkerId,
                  entry: _entryFor(i),
                  pulse: _pulse,
                  reduceMotion: _reduceMotion,
                  onTap: widget.onMarkerTap == null ? null : () => widget.onMarkerTap!(m.id),
                ),
              ),
          ],
        ),
        _Attribution(style: tiles, padding: widget.attributionPadding),
      ],
    );
  }

  Animation<double> _entryFor(int i) {
    final total = _entry.duration?.inMilliseconds ?? 0;
    if (total == 0) return _entry;
    final start = (_markerStagger.inMilliseconds * i / total).clamp(0.0, 1.0);
    final end = ((_markerStagger.inMilliseconds * i + _markerEntry.inMilliseconds) / total).clamp(start, 1.0);
    return _entry.drive(CurveTween(curve: Interval(start, end, curve: EbCurves.enter)));
  }
}

LatLng _toLatLng(GeoPoint p) => LatLng(p.lat, p.lng);

List<LatLng> _toLatLngs(List<GeoPoint> points) => [for (final p in points) _toLatLng(p)];

/// Punto azul de "estás aquí" (estilo habitual de los mapas, para que se reconozca).
class _UserDot extends StatelessWidget {
  const _UserDot();

  static const size = 22.0;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Tu ubicación',
    child: Container(
      decoration: BoxDecoration(
        color: EbColors.userLocation,
        shape: BoxShape.circle,
        border: Border.all(color: EbColors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
      ),
    ),
  );
}

class _PierMarker extends StatelessWidget {
  const _PierMarker({
    required this.marker,
    required this.selected,
    required this.entry,
    required this.pulse,
    required this.reduceMotion,
    required this.onTap,
  });

  final EbMapMarker marker;
  final bool selected;
  final Animation<double> entry;
  final Animation<double> pulse;
  final bool reduceMotion;
  final VoidCallback? onTap;

  static const dot = 28.0;

  @override
  Widget build(BuildContext context) {
    final color = marker.muted ? EbColors.textMuted : marker.color;
    final point = AnimatedScale(
      scale: selected ? 1.2 : 1,
      duration: reduceMotion ? Duration.zero : EbDurations.normal,
      curve: EbCurves.enter,
      child: Container(
        width: dot,
        height: dot,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: EbColors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Icon(marker.icon, size: 15, color: EbColors.white),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: marker.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 48 px de lado (área táctil mínima) alrededor del punto de 28 px: con 72 px
        // las áreas de embarcaderos cercanos se tapaban entre sí
        child: Center(
          child: FadeTransition(
            opacity: entry,
            child: ScaleTransition(
              scale: entry,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (selected) _SelectionRing(color: color, pulse: pulse, reduceMotion: reduceMotion),
                  point,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillo del marcador seleccionado: crece y se desvanece (1.6 s por ciclo, nunca
/// parpadea). Con "reducir movimiento" queda fijo.
class _SelectionRing extends StatelessWidget {
  const _SelectionRing({required this.color, required this.pulse, required this.reduceMotion});

  final Color color;
  final Animation<double> pulse;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
    if (reduceMotion) {
      return Transform.scale(scale: 1.7, child: Opacity(opacity: 0.3, child: ring));
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = Curves.easeOut.transform(pulse.value);
          return Transform.scale(
            scale: 1 + 1.2 * t,
            child: Opacity(opacity: 0.45 * (1 - t), child: child),
          );
        },
        child: ring,
      ),
    );
  }
}

/// Ruta seleccionada: se dibuja del origen al destino (1.2 s) y luego unas flechas
/// blancas avanzan por la línea en el sentido del viaje. Con "reducir movimiento"
/// aparece completa y las flechas quedan quietas (el sentido se sigue viendo).
class _SelectedRouteLayer extends StatefulWidget {
  const _SelectedRouteLayer({super.key, required this.points, required this.color, required this.reduceMotion});

  final List<LatLng> points;
  final Color color;
  final bool reduceMotion;

  @override
  State<_SelectedRouteLayer> createState() => _SelectedRouteLayerState();
}

class _SelectedRouteLayerState extends State<_SelectedRouteLayer> with TickerProviderStateMixin {
  late final _draw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  late final _drawCurve = CurvedAnimation(parent: _draw, curve: Curves.easeInOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _draw.value = 1;
    } else {
      _draw.forward().whenComplete(() {
        if (mounted && !widget.reduceMotion) _flow.repeat();
      });
    }
  }

  @override
  void didUpdateWidget(_SelectedRouteLayer old) {
    super.didUpdateWidget(old);
    if (widget.reduceMotion && !old.reduceMotion) {
      _draw.value = 1;
      _flow
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _drawCurve.dispose();
    _draw.dispose();
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final offsets = [for (final p in widget.points) camera.getOffsetFromOrigin(p)];
    return MobileLayerTransformer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _RoutePainter(offsets: offsets, color: widget.color, draw: _drawCurve, flow: _flow),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.offsets, required this.color, required this.draw, required this.flow})
    : super(repaint: Listenable.merge([draw, flow]));

  final List<Offset> offsets;
  final Color color;
  final Animation<double> draw;
  final Animation<double> flow;

  static const _arrowSpacing = 46.0;

  // Se calculan una vez por posición de cámara, no en cada cuadro de la animación
  late final List<PathMetric> _metrics = (Path()..addPolygon(offsets, false)).computeMetrics().toList();
  late final double _length = _metrics.fold(0, (sum, m) => sum + m.length);

  late final Paint _casing = Paint()
    ..color = EbColors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 10
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  late final Paint _line = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  late final Paint _arrow = Paint()
    ..color = EbColors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    if (_length == 0) return;
    final progress = draw.value;
    final visible = Path();
    var remaining = _length * progress;
    for (final m in _metrics) {
      if (remaining <= 0) break;
      visible.addPath(m.extractPath(0, math.min(remaining, m.length)), Offset.zero);
      remaining -= m.length;
    }
    canvas
      ..drawPath(visible, _casing)
      ..drawPath(visible, _line);

    if (progress < 1) return;
    // Flechas en el sentido del viaje, desplazándose con el flujo
    final phase = flow.value * _arrowSpacing;
    for (final m in _metrics) {
      for (var d = phase + _arrowSpacing / 2; d < m.length; d += _arrowSpacing) {
        final t = m.getTangentForOffset(d);
        if (t == null) continue;
        final angle = math.atan2(t.vector.dy, t.vector.dx);
        canvas
          ..save()
          ..translate(t.position.dx, t.position.dy)
          ..rotate(angle)
          ..drawPath(_chevron, _arrow)
          ..restore();
      }
    }
  }

  static final Path _chevron = Path()
    ..moveTo(-2.5, -3.5)
    ..lineTo(1.5, 0)
    ..lineTo(-2.5, 3.5);

  @override
  bool shouldRepaint(_RoutePainter old) => old.offsets != offsets || old.color != color;
}

/// Atribución siempre visible (política de uso de OpenStreetMap).
class _Attribution extends StatelessWidget {
  const _Attribution({required this.style, required this.padding});

  final EbTileStyle style;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme.labelSmall?.copyWith(color: EbColors.textPrimary, fontSize: 10);
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: padding,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: EbColors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), bottomLeft: Radius.circular(6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in style.attributions)
                Semantics(
                  link: true,
                  label: a.text,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(a.text, style: text),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
