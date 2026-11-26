// Datos de la pestaña Mapa: embarcaderos en el orden del río (con sus próximos
// zarpes, de piersOverviewProvider) y las rutas activas con el recorrido de cada
// sentido. Todo sale del repository, así que funciona sin conexión con la caché.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/geo.dart';
import '../models/transport_mode.dart';
import 'data_providers.dart';
import 'piers_providers.dart';

/// Un sentido de la ruta dibujado sobre el mapa.
@immutable
class MapRouteDirection {
  const MapRouteDirection({required this.sentido, required this.destino, required this.points});

  final Sentido sentido;
  final String destino;

  /// Trazado por el río; si aún no está dibujado, la línea que une sus embarcaderos
  /// en orden. Siempre del origen al destino.
  final List<GeoPoint> points;
}

@immutable
class MapRoute {
  const MapRoute({required this.id, required this.codigo, required this.colorHex, required this.directions});

  final String id;
  final String codigo;

  /// "#1E88E5" o null (se usa el color del modo).
  final String? colorHex;

  /// Ida primero.
  final List<MapRouteDirection> directions;

  MapRouteDirection? direction(Sentido s) {
    for (final d in directions) {
      if (d.sentido == s) return d;
    }
    return null;
  }
}

@immutable
class MapData {
  const MapData({required this.overview, required this.routes});

  /// Embarcaderos en el orden del río, con sus servicios.
  final PiersOverview overview;
  final List<MapRoute> routes;
}

final mapDataProvider = FutureProvider.family<MapData, TransportMode>((ref, mode) async {
  final overview = await ref.watch(piersOverviewProvider(mode).future);
  final routes = <MapRoute>[];
  // Si las rutas no se pudieron leer, el mapa muestra igual los embarcaderos
  if (overview.routesError == null) {
    final rutas =
        (await ref.watch(rutasProvider.future)).data
            .where((r) => r.mode == mode && r.estado == EstadoRuta.activa)
            .toList()
          ..sort((a, b) => a.codigo.compareTo(b.codigo));
    final detalles = await Future.wait([for (final r in rutas) ref.watch(rutaDetalleProvider(r.id).future)]);
    for (final d in detalles) {
      final sentidos = [...d.data.sentidos]..sort((a, b) => a.sentido.index.compareTo(b.sentido.index));
      final directions = [
        for (final s in sentidos)
          MapRouteDirection(
            sentido: s.sentido,
            destino: s.destino,
            points: List.unmodifiable(
              (s.trazado != null && s.trazado!.length >= 2)
                  ? s.trazado!
                  : [for (final p in s.paradas) p.embarcadero.ubicacion],
            ),
          ),
      ].where((d) => d.points.length >= 2).toList();
      if (directions.isEmpty) continue;
      routes.add(
        MapRoute(
          id: d.data.ruta.id,
          codigo: d.data.ruta.codigo,
          colorHex: d.data.ruta.color,
          directions: List.unmodifiable(directions),
        ),
      );
    }
  }
  return MapData(overview: overview, routes: List.unmodifiable(routes));
});
