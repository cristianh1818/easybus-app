// Rutas. GET /rutas devuelve la lista sin geometrías; GET /rutas/{id} trae los
// sentidos con su trazado, sus embarcaderos en orden y los avisos vigentes.

import 'package:flutter/foundation.dart';

import 'aviso.dart';
import 'embarcadero.dart';
import 'enums.dart';
import 'geo.dart';
import 'json.dart';
import 'transport_mode.dart';

/// Datos mínimos de una ruta, como vienen dentro de otras respuestas.
@immutable
class RutaResumen {
  const RutaResumen({required this.id, required this.codigo, required this.nombre, this.color, this.mode});

  final String id;

  /// "BS-1".
  final String codigo;
  final String nombre;

  /// "#1E88E5". Solo viene en algunas respuestas.
  final String? color;
  final TransportMode? mode;

  factory RutaResumen.fromJson(JsonMap json) => RutaResumen(
    id: json.str('id'),
    codigo: json.str('codigo'),
    nombre: json.str('nombre'),
    color: json.strOrNull('color'),
    mode: json.containsKey('modo') ? TransportMode.fromApi(json.strOrNull('modo')) : null,
  );
}

/// Elemento de GET /rutas.
@immutable
class Ruta {
  const Ruta({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.color,
    required this.estado,
    required this.mode,
    required this.esOficial,
    required this.sentidos,
    required this.actualizadoEn,
  });

  final String id;
  final String codigo;
  final String nombre;
  final String? descripcion;

  /// Color de la ruta en hexadecimal ("#1E88E5"); en la fase 1 se usa el del modo.
  final String? color;
  final EstadoRuta estado;
  final TransportMode mode;
  final bool esOficial;
  final List<SentidoResumen> sentidos;
  final DateTime actualizadoEn;

  factory Ruta.fromJson(JsonMap json) => Ruta(
    id: json.str('id'),
    codigo: json.str('codigo'),
    nombre: json.str('nombre'),
    descripcion: json.strOrNull('descripcion'),
    color: json.strOrNull('color'),
    estado: json.enumValue('estado', EstadoRuta.values, EstadoRuta.inactiva),
    mode: TransportMode.fromApi(json.strOrNull('modo')),
    esOficial: json.booleanOrNull('esOficial') ?? false,
    sentidos: json.list('sentidos', SentidoResumen.fromJson),
    actualizadoEn: json.date('actualizadoEn'),
  );
}

/// Sentido dentro de GET /rutas: sin trazado ni embarcaderos.
@immutable
class SentidoResumen {
  const SentidoResumen({required this.id, required this.sentido, required this.destino});

  final String id;
  final Sentido sentido;
  final String destino;

  factory SentidoResumen.fromJson(JsonMap json) => SentidoResumen(
    id: json.str('id'),
    sentido: json.enumValue('sentido', Sentido.values, Sentido.ida),
    destino: json.str('destino'),
  );
}

/// GET /rutas/{id}.
@immutable
class RutaDetalle {
  const RutaDetalle({required this.ruta, required this.sentidos, required this.avisos});

  /// Datos generales (los sentidos resumidos también están en [ruta.sentidos]).
  final Ruta ruta;
  final List<RutaSentido> sentidos;

  /// Avisos vigentes de la ruta. La app los muestra antes que cualquier horario.
  final List<Aviso> avisos;

  RutaSentido? sentido(Sentido s) {
    for (final rs in sentidos) {
      if (rs.sentido == s) return rs;
    }
    return null;
  }

  factory RutaDetalle.fromJson(JsonMap json) => RutaDetalle(
    ruta: Ruta.fromJson(json),
    sentidos: json.list('sentidos', RutaSentido.fromJson),
    avisos: json.list('avisos', Aviso.fromJson),
  );
}

/// Un sentido de la ruta con su trazado por el río y sus embarcaderos en orden.
@immutable
class RutaSentido {
  const RutaSentido({
    required this.id,
    required this.sentido,
    required this.destino,
    required this.trazado,
    required this.paradas,
    required this.actualizadoEn,
  });

  final String id;
  final Sentido sentido;
  final String destino;

  /// Recorrido por el cauce del río. null si aún no se ha dibujado.
  final List<GeoPoint>? trazado;

  /// Embarcaderos en orden de paso (campo `embarcaderos` de la API).
  final List<ParadaEnRuta> paradas;
  final DateTime actualizadoEn;

  factory RutaSentido.fromJson(JsonMap json) {
    final trazado = json.objOrNull('trazado');
    final paradas = json.list('embarcaderos', ParadaEnRuta.fromJson)
      ..sort((a, b) => a.orden.compareTo(b.orden));
    return RutaSentido(
      id: json.str('id'),
      sentido: json.enumValue('sentido', Sentido.values, Sentido.ida),
      destino: json.str('destino'),
      trazado: trazado == null ? null : GeoPoint.lineStringFromJson(trazado),
      paradas: List.unmodifiable(paradas),
      actualizadoEn: json.date('actualizadoEn'),
    );
  }
}

/// Embarcadero dentro de un sentido: orden, minutos desde el origen y qué tan
/// cerca queda del trazado.
@immutable
class ParadaEnRuta {
  const ParadaEnRuta({
    required this.orden,
    required this.minutosDesdeOrigen,
    required this.tiempoEstimado,
    required this.distanciaAlTrazadoM,
    required this.lejosDelTrazado,
    required this.embarcadero,
  });

  final int orden;
  final int minutosDesdeOrigen;

  /// true = minutos estimados con el trazado, no medidos.
  final bool tiempoEstimado;

  /// null si el sentido no tiene trazado.
  final int? distanciaAlTrazadoM;

  /// El embarcadero queda lejos del trazado: probablemente hay que corregir uno de los dos.
  final bool lejosDelTrazado;
  final Embarcadero embarcadero;

  bool get esOrigen => orden == 1;

  factory ParadaEnRuta.fromJson(JsonMap json) => ParadaEnRuta(
    orden: json.integer('orden'),
    minutosDesdeOrigen: json.integer('minutosDesdeOrigen'),
    tiempoEstimado: json.boolean('tiempoEstimado'),
    distanciaAlTrazadoM: json.integerOrNull('distanciaAlTrazadoM'),
    lejosDelTrazado: json.booleanOrNull('lejosDelTrazado') ?? false,
    embarcadero: Embarcadero.fromJson(json),
  );
}
