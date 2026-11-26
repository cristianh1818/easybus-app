// "Cerca de mí": embarcaderos más cercanos a la ubicación del pasajero.
//
// Se calcula SOLO en el teléfono, con la lista de embarcaderos que ya está en la
// caché: la ubicación nunca se envía a la API ni se guarda (RNF-07, Ley 1581).
// La distancia es en línea recta (haversine): sirve para elegir el embarcadero,
// no es la distancia caminando por las calles.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/geo.dart';

const _radioTierraM = 6371000.0;

/// Distancia en metros entre dos puntos, en línea recta sobre la Tierra.
double distanciaMetros(GeoPoint a, GeoPoint b) {
  double rad(double g) => g * math.pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _radioTierraM * math.asin(math.min(1, math.sqrt(h)));
}

@immutable
class Cercano<T> {
  const Cercano(this.item, this.metros);

  final T item;
  final double metros;
}

/// Los [cantidad] elementos más cercanos a [desde], del más cercano al más lejano.
/// Con [preferirAbiertos], los cerrados van después de todos los abiertos.
List<Cercano<T>> masCercanos<T>(
  GeoPoint desde,
  Iterable<T> items, {
  required GeoPoint Function(T) ubicacion,
  bool Function(T)? cerrado,
  int cantidad = 3,
}) {
  final lista = [for (final i in items) Cercano(i, distanciaMetros(desde, ubicacion(i)))];
  lista.sort((a, b) {
    if (cerrado != null) {
      final porEstado = (cerrado(a.item) ? 1 : 0).compareTo(cerrado(b.item) ? 1 : 0);
      if (porEstado != 0) return porEstado;
    }
    return a.metros.compareTo(b.metros);
  });
  return lista.take(cantidad).toList();
}

/// "350 m", "1,2 km", "12 km".
String formatoDistancia(double metros) {
  if (metros < 1000) return '${(metros / 10).round() * 10} m';
  final km = metros / 1000;
  final texto = km < 10 ? km.toStringAsFixed(1).replaceAll('.', ',') : km.round().toString();
  return '$texto km';
}

/// Más allá de esta distancia del embarcadero más cercano, se avisa que el
/// pasajero parece estar lejos del río (p. ej. fuera de Montería).
const lejosDelRioM = 5000.0;
