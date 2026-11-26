// Ubicación del pasajero para "cerca de mí" (paquete geolocator).
//
// Privacidad (RNF-07, Ley 1581): la ubicación se pide solo cuando el pasajero toca
// el botón "Mi ubicación", se usa en el teléfono para calcular distancias y NUNCA
// se envía a la API ni se guarda. No hay seguimiento en segundo plano.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo.dart';

/// Resultado de pedir la ubicación.
sealed class ResultadoUbicacion {
  const ResultadoUbicacion();
}

@immutable
class UbicacionObtenida extends ResultadoUbicacion {
  const UbicacionObtenida(this.punto, {required this.precisionM});

  final GeoPoint punto;

  /// Radio de incertidumbre en metros (el círculo claro alrededor del punto).
  final double precisionM;
}

/// El GPS / la ubicación del teléfono está apagada.
class UbicacionApagada extends ResultadoUbicacion {
  const UbicacionApagada();
}

/// El pasajero no dio permiso. [paraSiempre]: hay que activarlo en los ajustes.
class UbicacionSinPermiso extends ResultadoUbicacion {
  const UbicacionSinPermiso({required this.paraSiempre});

  final bool paraSiempre;
}

/// No se pudo obtener a tiempo (sin señal de GPS, bajo techo…).
class UbicacionNoDisponible extends ResultadoUbicacion {
  const UbicacionNoDisponible();
}

class UbicacionService {
  const UbicacionService();

  static const _tiempoMaximo = Duration(seconds: 15);

  Future<ResultadoUbicacion> obtener() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const UbicacionApagada();

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.deniedForever) return const UbicacionSinPermiso(paraSiempre: true);
      if (permiso == LocationPermission.denied) return const UbicacionSinPermiso(paraSiempre: false);

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: _tiempoMaximo),
      );
      return UbicacionObtenida(
        GeoPoint(posicion.latitude, posicion.longitude),
        precisionM: posicion.accuracy,
      );
    } on TimeoutException {
      return const UbicacionNoDisponible();
    } on LocationServiceDisabledException {
      return const UbicacionApagada();
    } on PermissionDeniedException {
      return const UbicacionSinPermiso(paraSiempre: false);
    } catch (_) {
      return const UbicacionNoDisponible();
    }
  }

  Future<void> abrirAjustesDeUbicacion() => Geolocator.openLocationSettings();

  Future<void> abrirAjustesDeLaApp() => Geolocator.openAppSettings();
}

final ubicacionServiceProvider = Provider<UbicacionService>((ref) => const UbicacionService());
