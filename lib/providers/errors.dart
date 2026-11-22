import 'package:flutter_riverpod/misc.dart' show ProviderException;

import '../services/api_exception.dart';

/// Convierte el error de un provider en el error único de la app. Riverpod envuelve
/// los errores de los providers de los que depende otro en ProviderException.
ApiException toApiException(Object error) {
  var e = error;
  while (e is ProviderException) {
    e = e.exception;
  }
  if (e is ApiException) return e;
  return const ApiException(
    kind: ApiErrorKind.unknown,
    code: 'ERROR_DESCONOCIDO',
    message: 'Ocurrió un error inesperado. Intenta de nuevo.',
  );
}
