// Coordenadas. Se usa una clase propia (sin depender todavía del paquete de mapas):
// las pantallas de mapa la convierten al tipo LatLng del paquete que se elija.

import 'package:flutter/foundation.dart';

import 'json.dart';

@immutable
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// GeoJSON usa el orden [longitud, latitud].
  factory GeoPoint.fromGeoJsonPosition(Object? position) {
    if (position is List && position.length >= 2 && position[0] is num && position[1] is num) {
      return GeoPoint((position[1] as num).toDouble(), (position[0] as num).toDouble());
    }
    throw FormatException('Coordenada GeoJSON inválida', position);
  }

  /// Lee un LineString GeoJSON ({ type: "LineString", coordinates: [[lng, lat], …] }).
  static List<GeoPoint> lineStringFromJson(JsonMap json) {
    if (json['type'] != 'LineString') {
      throw FormatException('Se esperaba un LineString', json['type']);
    }
    final coords = json['coordinates'];
    if (coords is! List) throw FormatException('LineString sin coordenadas', coords);
    return [for (final c in coords) GeoPoint.fromGeoJsonPosition(c)];
  }

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}
