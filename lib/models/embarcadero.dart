// Embarcadero (o parada de bus en la fase 2). Respuesta de GET /embarcaderos y,
// con sus rutas, de GET /embarcaderos/{id}.

import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'geo.dart';
import 'json.dart';
import 'ruta.dart';
import 'transport_mode.dart';

@immutable
class Embarcadero {
  const Embarcadero({
    required this.id,
    required this.nombre,
    required this.referencia,
    required this.ubicacion,
    required this.tipo,
    required this.margen,
    required this.estado,
    required this.tieneRampa,
    required this.tieneTecho,
    required this.tieneIluminacion,
    required this.fotoUrl,
    required this.esOficial,
    required this.actualizadoEn,
  });

  final String id;
  final String nombre;

  /// "Ronda del Sinú, frente al centro…". Puede faltar.
  final String? referencia;

  /// Se lee de `latitud` y `longitud` (la API también envía el punto GeoJSON).
  final GeoPoint ubicacion;
  final TipoParada tipo;

  /// null = sin dato.
  final Margen? margen;
  final EstadoEmbarcadero estado;

  /// Accesibilidad: null = sin información (no es lo mismo que "no tiene").
  final bool? tieneRampa;
  final bool? tieneTecho;
  final bool? tieneIluminacion;

  final String? fotoUrl;

  /// false = dato de ejemplo pendiente de validar en campo.
  final bool esOficial;
  final DateTime actualizadoEn;

  TransportMode get mode => TransportMode.fromTipoParada(tipo);

  bool get estaCerrado => estado != EstadoEmbarcadero.activo;

  factory Embarcadero.fromJson(JsonMap json) => Embarcadero(
    id: json.str('id'),
    nombre: json.str('nombre'),
    referencia: json.strOrNull('referencia'),
    ubicacion: GeoPoint(json.number('latitud'), json.number('longitud')),
    tipo: json.enumValue('tipo', TipoParada.values, TipoParada.embarcadero),
    margen: json.enumOrNull('margen', Margen.values),
    // Un estado desconocido se trata como cerrado: es más seguro no anunciar
    // zarpes desde un embarcadero cuyo estado no se entiende.
    estado: json.enumValue('estado', EstadoEmbarcadero.values, EstadoEmbarcadero.cerradoTemporal),
    tieneRampa: json.booleanOrNull('tieneRampa'),
    tieneTecho: json.booleanOrNull('tieneTecho'),
    tieneIluminacion: json.booleanOrNull('tieneIluminacion'),
    fotoUrl: json.strOrNull('fotoUrl'),
    esOficial: json.booleanOrNull('esOficial') ?? false,
    actualizadoEn: json.date('actualizadoEn'),
  );
}

/// GET /embarcaderos/{id}: el embarcadero y las rutas activas que pasan por él.
@immutable
class EmbarcaderoDetalle {
  const EmbarcaderoDetalle({required this.embarcadero, required this.rutas});

  final Embarcadero embarcadero;
  final List<RutaEnEmbarcadero> rutas;

  factory EmbarcaderoDetalle.fromJson(JsonMap json) => EmbarcaderoDetalle(
    embarcadero: Embarcadero.fromJson(json),
    rutas: json.list('rutas', RutaEnEmbarcadero.fromJson),
  );
}

/// Una ruta (en un sentido) que atiende al embarcadero, con su posición en ella.
@immutable
class RutaEnEmbarcadero {
  const RutaEnEmbarcadero({
    required this.ruta,
    required this.sentido,
    required this.destino,
    required this.orden,
    required this.totalEmbarcaderos,
    required this.esOrigen,
    required this.minutosDesdeOrigen,
    required this.tiempoEstimado,
  });

  final RutaResumen ruta;
  final Sentido sentido;
  final String destino;

  /// Posición del embarcadero en el sentido ("parada 2 de 5").
  final int orden;
  final int? totalEmbarcaderos;
  final bool esOrigen;
  final int minutosDesdeOrigen;

  /// true = los minutos se estimaron con el trazado, no se midieron.
  final bool tiempoEstimado;

  factory RutaEnEmbarcadero.fromJson(JsonMap json) => RutaEnEmbarcadero(
    ruta: RutaResumen.fromJson(json.obj('ruta')),
    sentido: json.enumValue('sentido', Sentido.values, Sentido.ida),
    destino: json.str('destino'),
    orden: json.integer('orden'),
    totalEmbarcaderos: json.integerOrNull('totalEmbarcaderos'),
    esOrigen: json.boolean('esOrigen'),
    minutosDesdeOrigen: json.integer('minutosDesdeOrigen'),
    tiempoEstimado: json.boolean('tiempoEstimado'),
  );
}
