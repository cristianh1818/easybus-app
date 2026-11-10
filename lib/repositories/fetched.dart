import 'package:flutter/foundation.dart';

import '../services/api_exception.dart';

/// De dónde vienen los datos que se muestran.
enum DataOrigin {
  /// Recién descargados de la API.
  network,

  /// Guardados en el teléfono (caché offline, próximo paso).
  cache,
}

/// Datos más su procedencia, para que las pantallas muestren "Actualizado hace X"
/// y el aviso de "sin conexión" sin saber si hay caché o no.
@immutable
class Fetched<T> {
  const Fetched(this.data, {required this.updatedAt, required this.origin, this.refreshError});

  final T data;

  /// Cuándo se descargaron estos datos de la API.
  final DateTime updatedAt;
  final DataOrigin origin;

  /// Se muestran datos de la caché porque falló la actualización (sin conexión…).
  final ApiException? refreshError;

  bool get isStale => refreshError != null;
}
