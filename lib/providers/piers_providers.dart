// Datos de la pantalla Embarcaderos: cada embarcadero con las rutas y sentidos en
// los que sale una embarcación desde él, ordenados a lo largo del río (orden de la
// ruta en el sentido de ida).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/embarcadero.dart';
import '../models/enums.dart';
import '../models/transport_mode.dart';
import '../services/api_exception.dart';
import 'data_providers.dart';
import 'errors.dart';

/// Una ruta, en un sentido, que sale desde el embarcadero.
@immutable
class PierService {
  const PierService({
    required this.rutaId,
    required this.rutaCodigo,
    required this.sentido,
    required this.destino,
    required this.orden,
  });

  final String rutaId;
  final String rutaCodigo;
  final Sentido sentido;
  final String destino;

  /// Posición del embarcadero en ese sentido (1 = origen).
  final int orden;
}

@immutable
class PierListItem {
  const PierListItem({required this.embarcadero, required this.services});

  final Embarcadero embarcadero;

  /// Vacío si ninguna ruta activa sale desde aquí (o si no se pudieron leer las rutas).
  final List<PierService> services;
}

@immutable
class PiersOverview {
  const PiersOverview({required this.items, required this.updatedAt, this.routesError, this.staleError});

  final List<PierListItem> items;

  /// La más antigua de las fechas de actualización de los datos usados.
  final DateTime updatedAt;

  /// Las rutas no se pudieron leer: la lista se muestra sin próximos zarpes.
  final ApiException? routesError;

  /// Se muestran datos guardados en el teléfono porque falló la actualización
  /// (normalmente: sin conexión).
  final ApiException? staleError;

  /// Todos son datos de ejemplo pendientes de validar en campo.
  bool get allSampleData => items.isNotEmpty && items.every((i) => !i.embarcadero.esOficial);
}

final piersOverviewProvider = FutureProvider.family<PiersOverview, TransportMode>((ref, mode) async {
  final embarcaderosFuture = ref.watch(embarcaderosProvider.future);
  final rutasFuture = ref.watch(rutasProvider.future);

  final embarcaderos = await embarcaderosFuture;
  var updatedAt = embarcaderos.updatedAt;
  var staleError = embarcaderos.refreshError;
  final services = <String, List<PierService>>{};
  final riverOrder = <String, int>{};
  ApiException? routesError;

  try {
    final rutas = await rutasFuture;
    if (rutas.updatedAt.isBefore(updatedAt)) updatedAt = rutas.updatedAt;
    staleError ??= rutas.refreshError;
    final activas = rutas.data.where((r) => r.mode == mode && r.estado == EstadoRuta.activa).toList()
      ..sort((a, b) => a.codigo.compareTo(b.codigo));
    final detalles = await Future.wait([
      for (final r in activas) ref.watch(rutaDetalleProvider(r.id).future),
    ]);

    for (final detalle in detalles) {
      if (detalle.updatedAt.isBefore(updatedAt)) updatedAt = detalle.updatedAt;
      staleError ??= detalle.refreshError;
      final ruta = detalle.data;
      // Ida primero: define el orden a lo largo del río
      final sentidos = [...ruta.sentidos]..sort((a, b) => a.sentido.index.compareTo(b.sentido.index));
      for (final rs in sentidos) {
        for (final parada in rs.paradas) {
          final id = parada.embarcadero.id;
          riverOrder.putIfAbsent(id, () => riverOrder.length);
          // Desde el último embarcadero de un sentido no sale nada hacia su destino
          if (parada.orden < rs.paradas.length) {
            services
                .putIfAbsent(id, () => [])
                .add(
                  PierService(
                    rutaId: ruta.ruta.id,
                    rutaCodigo: ruta.ruta.codigo,
                    sentido: rs.sentido,
                    destino: rs.destino,
                    orden: parada.orden,
                  ),
                );
          }
        }
      }
    }
  } on Object catch (e) {
    routesError = toApiException(e);
  }

  final items = [
    for (final e in embarcaderos.data)
      if (e.mode == mode && e.estado != EstadoEmbarcadero.inactivo)
        PierListItem(embarcadero: e, services: List.unmodifiable(services[e.id] ?? const [])),
  ];
  // A lo largo del río; los que no están en ninguna ruta, al final por nombre
  const notInRoute = 1 << 30;
  items.sort((a, b) {
    final byRiver = (riverOrder[a.embarcadero.id] ?? notInRoute).compareTo(
      riverOrder[b.embarcadero.id] ?? notInRoute,
    );
    return byRiver != 0 ? byRiver : a.embarcadero.nombre.compareTo(b.embarcadero.nombre);
  });

  return PiersOverview(
    items: List.unmodifiable(items),
    updatedAt: updatedAt,
    routesError: routesError,
    staleError: staleError,
  );
});
