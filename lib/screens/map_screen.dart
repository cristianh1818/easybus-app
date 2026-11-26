// Pestaña Mapa (mockup "Pantalla principal"): el río Sinú con los embarcaderos y las
// rutas, chips de rutas arriba y la píldora "¿A dónde quieres ir hoy?" sobre la
// barra inferior: abre el planificador (Desde · Hacia) con la propuesta de viaje
// calculada en el teléfono (domain/propuesta_viaje.dart).
//
// Los datos salen de la caché del teléfono (mapDataProvider), así que el mapa
// funciona sin conexión; solo el fondo (teselas) necesita internet.
//
// "Mi ubicación" (abajo a la derecha): pide la ubicación solo al tocarlo, muestra el
// punto azul y los 3 embarcaderos más cercanos. La distancia se calcula en el
// teléfono; la ubicación no se envía ni se guarda.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cercanos.dart';
import '../domain/propuesta_viaje.dart';
import '../models/enums.dart';
import '../models/geo.dart';
import '../models/transport_mode.dart';
import '../providers/map_providers.dart';
import '../providers/piers_providers.dart';
import '../providers/refresh.dart';
import '../services/ubicacion_service.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../utils/color_hex.dart';
import '../widgets/eb_bottom_nav.dart';
import '../widgets/eb_menu_button.dart';
import '../widgets/eb_next_departure_row.dart';
import '../widgets/eb_pier_photo.dart';
import '../widgets/eb_search_pill.dart';
import '../widgets/eb_trip_panel.dart';
import '../widgets/map/eb_river_map.dart';
import 'pier_detail_screen.dart';
import 'route_detail_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.mode});

  final TransportMode mode;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = EbRiverMapController();
  String? _routeId;
  Sentido _sentido = Sentido.ida;
  String? _pierId;

  /// Ubicación del pasajero, solo en memoria mientras la pantalla está abierta.
  UbicacionObtenida? _user;
  bool _locating = false;
  bool _showNearest = false;

  /// "¿A dónde quieres ir hoy?": panel abierto, origen y destino elegidos.
  bool _planning = false;
  PuntoViaje? _from;
  PuntoViaje? _to;

  /// Última propuesta encuadrada en el mapa (para no repetir el encuadre).
  String? _fittedTrip;

  /// Alto aproximado del panel del viaje, para encuadrar por encima de él.
  static const _tripPanelSpace = 380.0;

  /// Alto de la píldora más su margen: lo que el mapa deja libre abajo.
  static const _pillSpace = 56.0 + EbSpacing.m;

  /// Alto aproximado de la tarjeta de cercanos, para encuadrar por encima de ella.
  static const _nearestCardSpace = 240.0;

  List<Cercano<PierListItem>> _nearest(List<PierListItem> items) {
    final user = _user;
    if (user == null || items.isEmpty) return const [];
    return masCercanos(
      user.punto,
      items,
      ubicacion: (i) => i.embarcadero.ubicacion,
      cerrado: (i) => i.embarcadero.estaCerrado,
    );
  }

  Future<void> _locate(List<PierListItem> items) async {
    if (items.isEmpty) {
      _snack(
        ScaffoldMessenger.of(context),
        'Todavía se están cargando los embarcaderos. Intenta en un momento.',
      );
      return;
    }
    final result = await _obtainLocation(
      sinPermiso: 'Sin el permiso no podemos mostrar los cercanos. El resto del mapa funciona igual.',
      retry: () => _locate(items),
    );
    if (result == null || !mounted) return;
    setState(() {
      _user = result;
      _showNearest = true;
    });
    final nearest = _nearest(items);
    final padding = _overlayPadding(context);
    _map.fit([
      result.punto,
      if (nearest.isNotEmpty) nearest.first.item.embarcadero.ubicacion,
    ], padding: padding.copyWith(bottom: padding.bottom + _nearestCardSpace));
  }

  /// Pide la ubicación (solo al tocar) y explica qué hacer si no se pudo. La
  /// ubicación no sale del teléfono.
  Future<UbicacionObtenida?> _obtainLocation({
    required String sinPermiso,
    required VoidCallback retry,
  }) async {
    if (_locating) return null;
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(ubicacionServiceProvider);
    setState(() => _locating = true);
    final result = await service.obtener();
    if (!mounted) return null;
    setState(() => _locating = false);

    switch (result) {
      case UbicacionObtenida():
        return result;
      case UbicacionApagada():
        _snack(
          messenger,
          'La ubicación del teléfono está apagada. Actívala o elige un embarcadero de la lista.',
          action: SnackBarAction(label: 'Activar', onPressed: service.abrirAjustesDeUbicacion),
        );
      case UbicacionSinPermiso(paraSiempre: true):
        _snack(
          messenger,
          'EASYBUS no tiene permiso de ubicación. Puedes darlo en los ajustes del teléfono.',
          action: SnackBarAction(label: 'Ajustes', onPressed: service.abrirAjustesDeLaApp),
        );
      case UbicacionSinPermiso():
        _snack(messenger, sinPermiso);
      case UbicacionNoDisponible():
        _snack(
          messenger,
          'No se pudo obtener tu ubicación. Intenta de nuevo, mejor al aire libre.',
          action: SnackBarAction(label: 'Reintentar', onPressed: retry),
        );
    }
    return null;
  }

  // ---- "¿A dónde quieres ir hoy?" ----

  static const _tuUbicacion = 'Tu ubicación';

  // Opciones especiales de las hojas de elegir (se reconocen por identidad)
  static const _useLocation = PuntoViaje.punto(GeoPoint(0, 0), nombre: 'ubicacion');
  static const _pickOnMap = PuntoViaje.punto(GeoPoint(0, 0), nombre: 'mapa');

  void _startPlanning() {
    setState(() {
      _planning = true;
      _showNearest = false;
      // Si ya dio su ubicación, es el origen por defecto
      if (_from == null && _user != null) _from = PuntoViaje.punto(_user!.punto, nombre: _tuUbicacion);
    });
  }

  void _closePlanning() => setState(() {
    _planning = false;
    _from = null;
    _to = null;
    _fittedTrip = null;
  });

  List<({String nombre, String? detalle, bool cerrado, PuntoViaje? value})> _pierOptions(
    List<PierListItem> items,
  ) => [
    for (final i in items)
      (
        nombre: i.embarcadero.nombre,
        detalle: i.embarcadero.estaCerrado ? 'Cerrado temporalmente' : i.embarcadero.referencia,
        cerrado: i.embarcadero.estaCerrado,
        value: PuntoViaje.embarcadero(
          i.embarcadero.id,
          ubicacion: i.embarcadero.ubicacion,
          nombre: i.embarcadero.nombre,
        ),
      ),
  ];

  Future<void> _pickFrom(List<PierListItem> items) async {
    final chosen = await showTripEndpointPicker<PuntoViaje?>(
      context,
      title: '¿Desde dónde sales?',
      special: (icon: Icons.my_location_rounded, label: 'Usar mi ubicación', value: _useLocation),
      options: _pierOptions(items),
    );
    if (chosen == null || !mounted) return;
    if (identical(chosen, _useLocation)) {
      final loc = await _obtainLocation(
        sinPermiso: 'Sin el permiso de ubicación, elige el embarcadero desde donde sales.',
        retry: () => _pickFrom(items),
      );
      if (loc == null || !mounted) return;
      setState(() {
        _user = loc;
        _from = PuntoViaje.punto(loc.punto, nombre: _tuUbicacion);
      });
    } else {
      setState(() => _from = chosen);
    }
  }

  Future<void> _pickTo(List<PierListItem> items) async {
    final chosen = await showTripEndpointPicker<PuntoViaje?>(
      context,
      title: '¿A dónde vas?',
      special: (icon: Icons.touch_app_rounded, label: 'Tocar el lugar en el mapa', value: _pickOnMap),
      options: _pierOptions(items),
    );
    if (chosen == null || !mounted) return;
    if (identical(chosen, _pickOnMap)) {
      _snack(ScaffoldMessenger.of(context), 'Toca el mapa en el lugar al que quieres ir.');
    } else {
      setState(() => _to = chosen);
    }
  }

  void _onMapTapForTrip(GeoPoint point) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _to = PuntoViaje.punto(point, nombre: 'Punto elegido en el mapa'));
  }

  void _swap() => setState(() {
    final from = _from;
    _from = _to;
    _to = from;
  });

  /// Encuadra origen, subida, bajada y destino por encima del panel (una vez por propuesta).
  void _fitTrip(PropuestaViaje p) {
    final key = '${_from?.punto}-${_to?.punto}-${p.subida.embarcadero.id}-${p.bajada.embarcadero.id}';
    if (_fittedTrip == key) return;
    _fittedTrip = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final padding = _overlayPadding(context);
      _map.fit([
        if (_from case final f?) f.punto,
        p.subida.embarcadero.ubicacion,
        p.bajada.embarcadero.ubicacion,
        if (_to case final t?) t.punto,
      ], padding: padding.copyWith(bottom: MediaQuery.paddingOf(context).bottom + _tripPanelSpace));
    });
  }

  void _snack(ScaffoldMessengerState messenger, String message, {SnackBarAction? action}) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action, behavior: SnackBarBehavior.floating));
  }

  EdgeInsets _overlayPadding(BuildContext context) {
    final media = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      EbSpacing.xl,
      media.top + EbMenuButton.size + EbSpacing.xl,
      EbSpacing.xl,
      media.bottom + _pillSpace + EbSpacing.l,
    );
  }

  void _selectRoute(MapRoute route) {
    final deselect = _routeId == route.id;
    setState(() {
      _routeId = deselect ? null : route.id;
      _sentido = Sentido.ida;
    });
    if (!deselect) _fitRoute(route);
  }

  void _selectSentido(MapRoute route, Sentido s) {
    if (s == _sentido) return;
    setState(() => _sentido = s);
    _fitRoute(route);
  }

  void _fitRoute(MapRoute route) {
    final dir = route.direction(_sentido) ?? route.directions.first;
    // Deja espacio para los chips y el selector de sentido arriba
    final padding = _overlayPadding(context);
    _map.fit(dir.points, padding: padding.copyWith(top: padding.top + 56));
  }

  Future<void> _openPier(PierListItem item) async {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Con la portada la hoja ocupa algo más de la mitad
    final sheetHeight = screenHeight * 0.55;
    setState(() => _pierId = item.embarcadero.id);
    _map.focus(item.embarcadero.ubicacion, bottomInset: sheetHeight);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      // Se ajusta al contenido (hasta el 85 % de la pantalla, luego se desplaza)
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      backgroundColor: EbColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EbRadius.sheet)),
      ),
      builder: (sheetContext) => _PierSheet(
        item: item,
        // Se abre encima de la hoja (sin cerrarla): la foto viaja con Hero y al
        // volver el pasajero sigue en la hoja
        onOpenDetail: () => Navigator.of(sheetContext)
            .push(MaterialPageRoute<void>(builder: (_) => PierDetailScreen(embarcadero: item.embarcadero))),
      ),
    );
    if (mounted) setState(() => _pierId = null);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.mode.style;
    final data = ref.watch(mapDataProvider(widget.mode));
    final value = data.value;
    final media = MediaQuery.paddingOf(context);
    // Con extendBody, MediaQuery ya incluye el alto de la barra inferior
    final bottom = media.bottom;

    final items = value?.overview.items ?? const <PierListItem>[];
    final routes = value?.routes ?? const <MapRoute>[];
    final selectedRoute = routes.where((r) => r.id == _routeId).firstOrNull;
    final selectedDir = selectedRoute == null
        ? null
        : (selectedRoute.direction(_sentido) ?? selectedRoute.directions.first);
    final nearest = _showNearest && !_planning ? _nearest(items) : const <Cercano<PierListItem>>[];

    // Propuesta de viaje (calculada en el teléfono con las rutas guardadas)
    final tripRoutes = _planning ? ref.watch(activeRouteDetailsProvider(widget.mode)) : null;
    final propuesta = (_planning && _from != null && _to != null && tripRoutes?.value != null)
        ? calcularPropuesta(rutas: tripRoutes!.value!, origen: _from!, destino: _to!)
        : null;
    if (propuesta != null) _fitTrip(propuesta);
    final tripRoute = propuesta == null
        ? null
        : routes.where((r) => r.id == propuesta.ruta.ruta.id).firstOrNull;
    final tripDir = tripRoute?.direction(propuesta!.sentido.sentido);
    // Encima de la píldora "¿A dónde quieres ir hoy?"
    final aboveTheBar = bottom + EbSpacing.m - EbBottomNav.bubbleOverflow + 56 + EbSpacing.m;

    return Stack(
      children: [
        Positioned.fill(
          child: EbRiverMap(
            controller: _map,
            fitPadding: _overlayPadding(context),
            attributionPadding: EdgeInsets.only(
              bottom: bottom + _pillSpace - EbBottomNav.bubbleOverflow + EbSpacing.s,
            ),
            markers: [
              for (final i in items)
                EbMapMarker(
                  id: i.embarcadero.id,
                  point: i.embarcadero.ubicacion,
                  color: style.color,
                  icon: style.icon,
                  muted: i.embarcadero.estaCerrado,
                  semanticLabel: '${style.stopLabel} ${i.embarcadero.nombre}',
                ),
            ],
            lines: [
              for (final r in routes)
                // Ida y vuelta van por el mismo cauce: sin seleccionar basta una línea
                EbMapLine(
                  id: '${r.id}-${r.directions.first.sentido.name}',
                  points: r.directions.first.points,
                  color: _routeColor(r),
                ),
            ],
            selectedLine: tripDir != null
                ? EbMapLine(
                    id: '${tripRoute!.id}-${tripDir.sentido.name}',
                    points: tripDir.points,
                    color: _routeColor(tripRoute),
                  )
                : selectedDir == null
                ? null
                : EbMapLine(
                    id: '${selectedRoute!.id}-${selectedDir.sentido.name}',
                    points: selectedDir.points,
                    color: _routeColor(selectedRoute),
                  ),
            selectedMarkerId: _pierId ?? propuesta?.subida.embarcadero.id,
            userLocation: _user?.punto,
            userAccuracyM: _user?.precisionM,
            destination: _planning && _to != null && _to!.embarcaderoId == null ? _to!.punto : null,
            onMapTap: _planning ? _onMapTapForTrip : null,
            onMarkerTap: (id) {
              final item = items.where((i) => i.embarcadero.id == id).firstOrNull;
              if (item != null) _openPier(item);
            },
          ),
        ),
        // El ☰ lo pone HomeShell (el mismo en las tres pestañas)
        // Franja superior (chips de rutas): deslizar hacia abajo aquí actualiza los
        // datos. El resto del mapa sigue moviéndose con el dedo.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: RefreshIndicator(
            color: EbColors.river,
            edgeOffset: media.top,
            semanticsLabel: 'Actualizar el mapa',
            onRefresh: () => refreshAllData(ref, widget.mode),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(
                  top: media.top + EbSpacing.s,
                  left: EbMenuButton.size + EbSpacing.s,
                  bottom: EbSpacing.s,
                ),
                child: _TopControls(
                  routes: routes,
                  selected: selectedRoute,
                  sentido: selectedDir?.sentido,
                  colorOf: _routeColor,
                  onRoute: _selectRoute,
                  onSentido: _selectSentido,
                  onOpenRoute: (r, s) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RouteDetailScreen(rutaId: r.id, codigo: r.codigo, initialSentido: s),
                    ),
                  ),
                  loading: data.isLoading && value == null,
                  error: data.hasError && value == null,
                  onRetry: () => refreshAllData(ref, widget.mode),
                ),
              ),
            ),
          ),
        ),
        if (_planning)
          Positioned(
            left: EbSpacing.m,
            right: EbSpacing.m,
            bottom: bottom + EbSpacing.m - EbBottomNav.bubbleOverflow,
            child: ConstrainedBox(
              // En pantallas pequeñas el panel se desplaza y deja ver el mapa
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
              child: SingleChildScrollView(
                child: EbTripPanel(
                  from: _from,
                  to: _to,
                  propuesta: propuesta,
                  loading: tripRoutes?.value == null,
                  onPickFrom: () => _pickFrom(items),
                  onPickTo: () => _pickTo(items),
                  onSwap: _swap,
                  onClose: _closePlanning,
                  onOpenRoute: (p) => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RouteDetailScreen(
                        rutaId: p.ruta.ruta.id,
                        codigo: p.ruta.ruta.codigo,
                        initialSentido: p.sentido.sentido,
                        highlightEmbarcaderoId: p.subida.embarcadero.id,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        else ...[
          if (nearest.isNotEmpty)
            Positioned(
              left: EbSpacing.m,
              right: EbSpacing.m,
              bottom: aboveTheBar,
              child: _NearestCard(
                nearest: nearest,
                color: style.color,
                icon: style.icon,
                locating: _locating,
                onTap: _openPier,
                onRefresh: () => _locate(items),
                onClose: () => setState(() => _showNearest = false),
              ),
            )
          else
            Positioned(
              right: EbSpacing.m,
              bottom: aboveTheBar,
              child: _LocateButton(locating: _locating, onPressed: () => _locate(items)),
            ),
          Positioned(
            left: EbSpacing.l,
            right: EbSpacing.l,
            bottom: bottom + EbSpacing.m - EbBottomNav.bubbleOverflow,
            child: Center(child: EbSearchPill(onTap: _startPlanning)),
          ),
        ],
      ],
    );
  }

  Color _routeColor(MapRoute r) => parseHexColor(r.colorHex) ?? widget.mode.style.color;
}

/// Chips de las rutas y, con una ruta elegida, el selector de sentido.
class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.routes,
    required this.selected,
    required this.sentido,
    required this.colorOf,
    required this.onRoute,
    required this.onSentido,
    required this.onOpenRoute,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<MapRoute> routes;
  final MapRoute? selected;
  final Sentido? sentido;
  final Color Function(MapRoute) colorOf;
  final ValueChanged<MapRoute> onRoute;
  final void Function(MapRoute, Sentido) onSentido;
  final void Function(MapRoute, Sentido) onOpenRoute;
  final bool loading;
  final bool error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (error) {
      return _Bubble(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text('No se pudieron cargar los embarcaderos.', style: text.bodyMedium)),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (loading) {
      return _Bubble(
        child: Text('Cargando el mapa…', style: text.bodyMedium?.copyWith(color: EbColors.textMuted)),
      );
    }
    final sel = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: EbSpacing.m),
          child: Row(
            children: [
              for (final r in routes)
                Padding(
                  padding: const EdgeInsets.only(right: EbSpacing.s),
                  child: _RouteChip(
                    label: r.codigo,
                    color: colorOf(r),
                    selected: r.id == sel?.id,
                    onTap: () => onRoute(r),
                  ),
                ),
            ],
          ),
        ),
        if (sel != null) ...[
          const SizedBox(height: EbSpacing.s),
          Padding(
            padding: const EdgeInsets.only(right: EbSpacing.m),
            child: _Bubble(
              padding: const EdgeInsets.all(EbSpacing.xs),
              child: Wrap(
                spacing: EbSpacing.xs,
                runSpacing: EbSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (sel.directions.length > 1)
                    for (final d in sel.directions)
                      _SentidoOption(
                        label: 'Hacia ${d.destino}',
                        selected: d.sentido == sentido,
                        onTap: () => onSentido(sel, d.sentido),
                      ),
                  // Detalle de la ruta: recorrido, horas de paso y horarios
                  TextButton.icon(
                    onPressed: () => onOpenRoute(sel, sentido ?? sel.directions.first.sentido),
                    icon: const Icon(Icons.timeline_rounded),
                    label: const Text('Ver recorrido y horarios'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: EbSpacing.m, vertical: EbSpacing.s),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: EbColors.white,
    elevation: 2,
    shadowColor: Colors.black26,
    borderRadius: BorderRadius.circular(EbRadius.card),
    child: Padding(padding: padding, child: child),
  );
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.label, required this.color, required this.selected, required this.onTap});

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? EbColors.white : EbColors.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Ruta $label${selected ? ', seleccionada' : ''}',
      excludeSemantics: true,
      child: Material(
        color: selected ? EbColors.navy : EbColors.white,
        elevation: 2,
        shadowColor: Colors.black26,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: EbSizes.minTouch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: EbColors.white, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: EbSpacing.s),
                  Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SentidoOption extends StatelessWidget {
  const _SentidoOption({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? EbColors.riverTint : Colors.transparent,
        borderRadius: BorderRadius.circular(EbRadius.card - EbSpacing.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(EbRadius.card - EbSpacing.xs),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EbSpacing.m, vertical: EbSpacing.s),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: selected ? EbColors.riverInk : EbColors.textMuted,
                  ),
                  const SizedBox(width: EbSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: selected ? EbColors.riverInk : EbColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón redondo "Mi ubicación".
class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.locating, required this.onPressed});

  final bool locating;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: locating ? 'Buscando tu ubicación' : 'Mi ubicación: ver los embarcaderos más cercanos',
      excludeSemantics: true,
      child: Material(
        color: EbColors.white,
        elevation: 3,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: locating ? null : onPressed,
          child: SizedBox.square(
            dimension: 52,
            child: Center(
              child: locating
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: EbColors.userLocation),
                    )
                  : const Icon(Icons.my_location_rounded, color: EbColors.userLocation),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con los embarcaderos más cercanos a la ubicación del pasajero.
class _NearestCard extends StatelessWidget {
  const _NearestCard({
    required this.nearest,
    required this.color,
    required this.icon,
    required this.locating,
    required this.onTap,
    required this.onRefresh,
    required this.onClose,
  });

  final List<Cercano<PierListItem>> nearest;
  final Color color;
  final IconData icon;
  final bool locating;
  final ValueChanged<PierListItem> onTap;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodySmall?.copyWith(color: EbColors.textMuted);
    final far = nearest.first.metros > lejosDelRioM;

    return Material(
      color: EbColors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(EbRadius.card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(EbSpacing.m, EbSpacing.xs, EbSpacing.xs, EbSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text('Embarcaderos más cercanos', style: text.titleMedium),
                  ),
                ),
                IconButton(
                  tooltip: 'Actualizar mi ubicación',
                  onPressed: locating ? null : onRefresh,
                  icon: locating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.my_location_rounded, color: EbColors.userLocation),
                ),
                IconButton(tooltip: 'Cerrar', onPressed: onClose, icon: const Icon(Icons.close_rounded)),
              ],
            ),
            if (far)
              Padding(
                padding: const EdgeInsets.only(right: EbSpacing.s, bottom: EbSpacing.xs),
                child: Text(
                  'Parece que estás lejos del río: el más cercano está a '
                  '${formatoDistancia(nearest.first.metros)}.',
                  style: text.bodySmall?.copyWith(color: EbColors.alertDelayInk),
                ),
              ),
            for (final c in nearest)
              _NearestRow(cercano: c, color: color, icon: icon, onTap: () => onTap(c.item)),
            Padding(
              padding: const EdgeInsets.only(top: EbSpacing.xs, right: EbSpacing.s),
              child: Text('Distancia en línea recta. Tu ubicación no sale del teléfono.', style: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearestRow extends StatelessWidget {
  const _NearestRow({required this.cercano, required this.color, required this.icon, required this.onTap});

  final Cercano<PierListItem> cercano;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final e = cercano.item.embarcadero;
    final distancia = formatoDistancia(cercano.metros);
    return Semantics(
      button: true,
      label: '${e.nombre}, a $distancia${e.estaCerrado ? ', cerrado temporalmente' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EbRadius.card - EbSpacing.xs),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: EbSizes.minTouch),
          child: Padding(
            padding: const EdgeInsets.only(right: EbSpacing.s),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: e.estaCerrado ? EbColors.textMuted : color,
                  child: Icon(icon, size: 15, color: EbColors.white),
                ),
                const SizedBox(width: EbSpacing.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(e.nombre, style: text.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (e.estaCerrado)
                        Text(
                          'Cerrado temporalmente',
                          style: text.bodySmall?.copyWith(color: EbColors.alertSuspended),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: EbSpacing.s),
                Text(distancia, style: text.labelLarge?.copyWith(color: EbColors.riverInk)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior al tocar un embarcadero: nombre, próximo zarpe por sentido y
/// "Ver detalle".
class _PierSheet extends StatelessWidget {
  const _PierSheet({required this.item, required this.onOpenDetail});

  final PierListItem item;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final e = item.embarcadero;
    final text = Theme.of(context).textTheme;
    // La hoja llega hasta el borde inferior: se suma la barra de navegación del
    // sistema (3 botones o gestos) para que "Ver detalle" no quede debajo
    final systemBottom = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(EbSpacing.l, 0, EbSpacing.l, EbSpacing.l + systemBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Portada (o el fondo con el ícono, del mismo tamaño)
          EbPierPhoto(embarcadero: e, aspectRatio: 2 / 1),
          const SizedBox(height: EbSpacing.m),
          Text(e.nombre, style: text.titleLarge),
          if (e.referencia != null) ...[
            const SizedBox(height: EbSpacing.xs),
            Text(e.referencia!, style: text.bodyMedium?.copyWith(color: EbColors.textMuted)),
          ],
          const SizedBox(height: EbSpacing.m),
          if (e.estado == EstadoEmbarcadero.cerradoTemporal)
            Text(
              'Cerrado temporalmente',
              style: text.bodyMedium?.copyWith(color: EbColors.alertSuspended, fontWeight: FontWeight.w600),
            )
          else if (item.services.isEmpty)
            Text(
              'No hay salidas programadas desde aquí.',
              style: text.bodyMedium?.copyWith(color: EbColors.textMuted),
            )
          else ...[
            Text('Próximo zarpe', style: text.titleSmall),
            const SizedBox(height: EbSpacing.xs),
            for (final s in item.services) EbNextDepartureRow(service: s, embarcaderoId: e.id),
            const SizedBox(height: EbSpacing.xs),
            Text('Horario programado', style: text.bodySmall?.copyWith(color: EbColors.textMuted)),
          ],
          const SizedBox(height: EbSpacing.l),
          FilledButton(onPressed: onOpenDetail, child: const Text('Ver detalle')),
        ],
      ),
    );
  }
}
