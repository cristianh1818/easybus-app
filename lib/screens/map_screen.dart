// Pestaña Mapa (mockup "Pantalla principal"): el río Sinú con los embarcaderos y las
// rutas, ☰ arriba a la izquierda, chips de rutas arriba y la píldora
// "¿A dónde quieres ir hoy?" sobre la barra inferior.
//
// Los datos salen de la caché del teléfono (mapDataProvider), así que el mapa
// funciona sin conexión; solo el fondo (teselas) necesita internet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/transport_mode.dart';
import '../providers/map_providers.dart';
import '../providers/piers_providers.dart';
import '../theme/eb_tokens.dart';
import '../theme/mode_style.dart';
import '../widgets/eb_bottom_nav.dart';
import '../widgets/eb_menu_button.dart';
import '../widgets/eb_next_departure_row.dart';
import '../widgets/eb_search_pill.dart';
import '../widgets/map/eb_river_map.dart';
import 'pier_detail_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.mode, required this.onOpenPiers});

  final TransportMode mode;

  /// Mientras no haya búsqueda de origen y destino, la píldora lleva a la lista.
  final VoidCallback onOpenPiers;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = EbRiverMapController();
  String? _routeId;
  Sentido _sentido = Sentido.ida;
  String? _pierId;

  /// Alto de la píldora más su margen: lo que el mapa deja libre abajo.
  static const _pillSpace = 56.0 + EbSpacing.m;

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
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.42;
    setState(() => _pierId = item.embarcadero.id);
    _map.focus(item.embarcadero.ubicacion, bottomInset: sheetHeight);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: EbColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(EbRadius.sheet))),
      builder: (sheetContext) => _PierSheet(
        item: item,
        onOpenDetail: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => PierDetailScreen(embarcadero: item.embarcadero)));
        },
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

    return Stack(
      children: [
        Positioned.fill(
          child: EbRiverMap(
            controller: _map,
            fitPadding: _overlayPadding(context),
            attributionPadding: EdgeInsets.only(bottom: bottom + _pillSpace - EbBottomNav.bubbleOverflow + EbSpacing.s),
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
            selectedLine: selectedDir == null
                ? null
                : EbMapLine(
                    id: '${selectedRoute!.id}-${selectedDir.sentido.name}',
                    points: selectedDir.points,
                    color: _routeColor(selectedRoute),
                  ),
            selectedMarkerId: _pierId,
            onMarkerTap: (id) {
              final item = items.where((i) => i.embarcadero.id == id).firstOrNull;
              if (item != null) _openPier(item);
            },
          ),
        ),
        const Positioned(top: 0, left: 0, child: EbMenuButton()),
        Positioned(
          top: media.top + EbSpacing.s,
          left: EbMenuButton.size + EbSpacing.s,
          right: 0,
          child: _TopControls(
            routes: routes,
            selected: selectedRoute,
            sentido: selectedDir?.sentido,
            colorOf: _routeColor,
            onRoute: _selectRoute,
            onSentido: _selectSentido,
            loading: data.isLoading && value == null,
            error: data.hasError && value == null,
            onRetry: () => ref.invalidate(mapDataProvider(widget.mode)),
          ),
        ),
        Positioned(
          left: EbSpacing.l,
          right: EbSpacing.l,
          bottom: bottom + EbSpacing.m - EbBottomNav.bubbleOverflow,
          child: Center(child: EbSearchPill(onTap: widget.onOpenPiers)),
        ),
      ],
    );
  }

  Color _routeColor(MapRoute r) => _parseHex(r.colorHex) ?? widget.mode.style.color;
}

/// "#1E88E5" → Color. null si falta o no es válido.
Color? _parseHex(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
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
        if (sel != null && sel.directions.length > 1) ...[
          const SizedBox(height: EbSpacing.s),
          Padding(
            padding: const EdgeInsets.only(right: EbSpacing.m),
            child: _Bubble(
              padding: const EdgeInsets.all(EbSpacing.xs),
              child: Wrap(
                spacing: EbSpacing.xs,
                runSpacing: EbSpacing.xs,
                children: [
                  for (final d in sel.directions)
                    _SentidoOption(
                      label: 'Hacia ${d.destino}',
                      selected: d.sentido == sentido,
                      onTap: () => onSentido(sel, d.sentido),
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
                  Icon(Icons.arrow_forward_rounded, size: 18, color: selected ? EbColors.riverInk : EbColors.textMuted),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(EbSpacing.l, 0, EbSpacing.l, EbSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
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
            Text('No hay salidas programadas desde aquí.', style: text.bodyMedium?.copyWith(color: EbColors.textMuted))
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
