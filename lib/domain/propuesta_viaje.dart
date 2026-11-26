// "¿A dónde quieres ir hoy?": propuesta de viaje calculada SOLO en el teléfono, con
// las rutas guardadas en la caché (sin Google Places ni servicios externos; la
// ubicación no sale del equipo).
//
// Para cada ruta y sentido se prueban todas las parejas (subir, bajar) con la de
// bajar DESPUÉS de la de subir en el orden del sentido, y se elige la que tarda menos
// en total: caminar hasta el embarcadero de subida + minutos en la embarcación +
// caminar desde el de bajada hasta el destino (caminar pesa [pesoCaminar] veces
// más). Las distancias a pie son en línea recta (no por las calles): es una estimación.

import 'package:flutter/foundation.dart';

import '../models/geo.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';
import 'cercanos.dart';
import 'proxima_salida_local.dart' show sumarMinutos;

/// Paso de una persona caminando: unos 4,8 km/h.
const metrosPorMinutoCaminando = 80.0;

/// Un minuto caminando "pesa" más que uno en la embarcación (sol, calor, calles):
/// sin esto se propondría bajar antes y caminar 2 km en vez de seguir por el río.
const pesoCaminar = 2.5;

/// Origen o destino del viaje: un punto (ubicación o toque en el mapa) o un
/// embarcadero elegido de la lista.
@immutable
class PuntoViaje {
  const PuntoViaje.punto(this.punto, {this.nombre}) : embarcaderoId = null;
  const PuntoViaje.embarcadero(
    String this.embarcaderoId, {
    required GeoPoint ubicacion,
    required String this.nombre,
  }) : punto = ubicacion;

  final GeoPoint punto;

  /// Si se eligió un embarcadero: su id (se sube o se baja justo ahí, sin caminar).
  final String? embarcaderoId;

  /// "Tu ubicación", "Punto en el mapa" o el nombre del embarcadero.
  final String? nombre;
}

@immutable
class PropuestaViaje {
  const PropuestaViaje({
    required this.ruta,
    required this.sentido,
    required this.subida,
    required this.bajada,
    required this.metrosHastaSubida,
    required this.metrosDesdeBajada,
  });

  final RutaDetalle ruta;
  final RutaSentido sentido;
  final ParadaEnRuta subida;
  final ParadaEnRuta bajada;
  final double metrosHastaSubida;
  final double metrosDesdeBajada;

  /// Minutos en la embarcación, de la subida a la bajada.
  int get minutosEnEmbarcacion => bajada.minutosDesdeOrigen - subida.minutosDesdeOrigen;

  int get minutosCaminandoHastaSubida => (metrosHastaSubida / metrosPorMinutoCaminando).ceil();
  int get minutosCaminandoDesdeBajada => (metrosDesdeBajada / metrosPorMinutoCaminando).ceil();

  double get _costo =>
      minutosEnEmbarcacion + pesoCaminar * (metrosHastaSubida + metrosDesdeBajada) / metrosPorMinutoCaminando;
}

/// La mejor propuesta, o null si no hay ninguna (sin rutas, o el origen y el
/// destino quedan en el mismo embarcadero).
PropuestaViaje? calcularPropuesta({
  required List<RutaDetalle> rutas,
  required PuntoViaje origen,
  required PuntoViaje destino,
}) {
  PropuestaViaje? mejor;
  for (final ruta in rutas) {
    for (final rs in ruta.sentidos) {
      final paradas = rs.paradas;
      for (var i = 0; i < paradas.length; i++) {
        final subida = paradas[i];
        if (subida.embarcadero.estaCerrado) continue;
        if (origen.embarcaderoId != null && subida.embarcadero.id != origen.embarcaderoId) continue;
        final aSubida = origen.embarcaderoId != null
            ? 0.0
            : distanciaMetros(origen.punto, subida.embarcadero.ubicacion);
        for (var j = i + 1; j < paradas.length; j++) {
          final bajada = paradas[j];
          if (bajada.embarcadero.estaCerrado) continue;
          if (destino.embarcaderoId != null && bajada.embarcadero.id != destino.embarcaderoId) continue;
          final desdeBajada = destino.embarcaderoId != null
              ? 0.0
              : distanciaMetros(bajada.embarcadero.ubicacion, destino.punto);
          final p = PropuestaViaje(
            ruta: ruta,
            sentido: rs,
            subida: subida,
            bajada: bajada,
            metrosHastaSubida: aSubida,
            metrosDesdeBajada: desdeBajada,
          );
          if (mejor == null || p._costo < mejor._costo) mejor = p;
        }
      }
    }
  }
  return mejor;
}

/// Hora estimada de llegada al embarcadero de bajada con la próxima salida
/// [proxima] (consultada desde el embarcadero de subida). null si hoy no hay más
/// salidas o el servicio está suspendido; [manana] = la de la primera salida de mañana.
({String hora, bool manana})? horaLlegada(ProximaSalida proxima, ParadaEnRuta bajada) {
  if (proxima.status == DepartureStatus.nextDeparture && proxima.originDepartureTime != null) {
    return (hora: sumarMinutos(proxima.originDepartureTime!, bajada.minutosDesdeOrigen), manana: false);
  }
  final next = proxima.nextDayFirstDeparture;
  if (proxima.status == DepartureStatus.noMoreDeparturesToday && next != null) {
    return (hora: sumarMinutos(next.originDepartureTime, bajada.minutosDesdeOrigen), manana: true);
  }
  return null;
}
